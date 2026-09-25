Class App.Tools.Ens.Power Extends App.Tools.Ens.Base [ Abstract ]
{

Parameter Mutating = 1;

Parameter Privilege = "%Ens_ProductionRun:U";

Parameter Starts As BOOLEAN = 1;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["namespace"],
  "properties": {
    "namespace": { "type": "string", "title": "Interoperability namespace, e.g. USER" },
    "production": { "type": "string", "title": "Production class. Empty = the one that is current in that namespace." },
    "timeout": { "type": "integer", "minimum": 5, "maximum": 300, "title": "Seconds to wait. Default 30." }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set ns = ..Namespace(args)
	set timeout = +args.%Get("timeout")
	set:timeout'>0 timeout = 30
	set out = ..Switch(ns, args.%Get("production"), ..#Starts, timeout, .err)
	do:err'="" ##class(App.Err).Throw("tool_error", ..Explain(err, ns))
	return out
}

ClassMethod Switch(ns As %String, production As %String, starting As %Boolean, timeout As %Integer, Output err As %String) As %DynamicObject
{
	set err = "", out = {"data": {}, "warnings": []}
	try {
		new $namespace
		set $namespace = ns

		do ##class(Ens.Director).GetProductionStatus(.current, .state)
		set:production="" production = current
		set:production="" production = $get(^Ens.Configuration("csp", "LastProduction"))

		if production = "" {
			set err = "no production has ever been started in "_ns_", so there is nothing to "_$select(starting: "start", 1: "stop")_" - name one"
			return out
		}

		if starting, +state = 1, production = current {
			set out.data = {"namespace": (ns), "production": (production), "status": "Running"}
			do out.warnings.%Push(production_" was already running")
			return out
		}
		if 'starting, +state = 2 {
			set out.data = {"namespace": (ns), "production": (production), "status": "Stopped"}
			do out.warnings.%Push("nothing was running in "_ns)
			return out
		}

		set sc = $select(starting: ##class(Ens.Director).StartProduction(production), 1: ##class(Ens.Director).StopProduction(timeout))
		if $system.Status.IsError(sc) {
			set err = $zstrip($replace($system.Status.GetErrorText(sc), $char(13, 10), " "), "<>W")
			return out
		}

		do ##class(Ens.Director).GetProductionStatus(.name, .now)
		set out.data = {"namespace": (ns), "production": (name)}
		set out.data.status = $case(+now, 1: "Running", 2: "Stopped", 3: "Suspended", 4: "Troubled", : "Unknown")
	} catch e {
		set err = e.DisplayString()
	}
	return out
}

}
