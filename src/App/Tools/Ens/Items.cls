Class App.Tools.Ens.Items Extends App.Tools.Ens.Base
{

Parameter ToolName = "ens.production.items";

Parameter Title = "Services, processes and operations of a production, with their traffic";

Parameter Mutating = 0;

Parameter Privilege = "%Ens_ProductionRun:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["namespace"],
  "properties": {
    "namespace": { "type": "string", "title": "Interoperability namespace, e.g. USER" },
    "production": { "type": "string", "title": "Production class. Empty = the one that is current in that namespace." },
    "sinceHours": { "type": "integer", "minimum": 1, "maximum": 8760, "title": "Window the message counts cover. Default 24." }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set ns = ..Namespace(args)
	set hours = +args.%Get("sinceHours")
	set:hours'>0 hours = 24
	set out = ..Read(ns, args.%Get("production"), hours, .err)
	do:err'="" ##class(App.Err).Throw("tool_error", ..Explain(err, ns))
	return out
}

ClassMethod Read(ns As %String, production As %String, hours As %Integer, Output err As %String) As %DynamicObject
{
	set err = "", out = {"data": [], "warnings": []}
	try {
		new $namespace
		set $namespace = ns

		if production = "" {
			do ##class(Ens.Director).GetProductionStatus(.production)
			set:production="" production = $get(^Ens.Configuration("csp", "LastProduction"))
			return:production="" out
		}
		set cfg = ##class(Ens.Config.Production).%OpenId(production)
		if '$isobject(cfg) {
			set err = "no production "_production_" in "_ns
			return out
		}

		// ztimestamp is days,seconds
		set secs = ($piece($ztimestamp, ",", 2) \ 1) + (86400 * $piece($ztimestamp, ",")) - (hours * 3600)
		set since = $zdatetime((secs \ 86400)_","_(secs # 86400), 3, 1, 3)
		// no App.* after ns switch
		// ponytail: 2 full scans
		// status 8 = error not IsError
		// SQLUPPER, so keys uppercase
		set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT SourceConfigName AS n, COUNT(*) AS c FROM Ens.MessageHeader WHERE TimeCreated >= ? GROUP BY SourceConfigName", since)
		// cant read, dont fake zeros
		set counted = rs.%SQLCODE '< 0, why = rs.%Message
		while rs.%Next() {
			set sent(rs.n) = rs.c
		}
		set in = ##class(%SQL.Statement).%ExecDirect(, "SELECT TargetConfigName AS n, COUNT(*) AS c, SUM(CASE WHEN Status = 8 THEN 1 ELSE 0 END) AS e FROM Ens.MessageHeader WHERE TimeCreated >= ? GROUP BY TargetConfigName", since)
		set:in.%SQLCODE<0 counted = 0, why = in.%Message
		do:'counted out.warnings.%Push("message counts unavailable: "_why)
		while in.%Next() {
			set got(in.n) = in.c, bad(in.n) = in.e
		}

		for i = 1:1:cfg.Items.Count() {
			set item = cfg.Items.GetAt(i), key = $zconvert(item.Name, "U")
			set one = {"name": (item.Name), "class": (item.ClassName), "category": (item.Category), "comment": (item.Comment)}
			do one.%Set("enabled", ''item.Enabled, "boolean")
			set one.type = $case(+item.BusinessType(), 1: "service", 2: "process", 3: "operation", : "host")
			if counted {
				do one.%Set("sent", +$get(sent(key)), "number")
				do one.%Set("received", +$get(got(key)), "number")
				do one.%Set("errors", +$get(bad(key)), "number")
			}
			do out.data.%Push(one)
		}
	} catch e {
		set err = e.DisplayString()
	}
	return out
}



}
