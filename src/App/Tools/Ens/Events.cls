Class App.Tools.Ens.Events Extends App.Tools.Ens.Base
{

Parameter ToolName = "ens.events";

Parameter Title = "Production event log, newest first";

Parameter Mutating = 0;

Parameter Privilege = "%Ens_EventLog:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["namespace"],
  "properties": {
    "namespace": { "type": "string", "title": "Interoperability namespace, e.g. USER" },
    "maxRows": { "type": "integer", "minimum": 1, "maximum": 2000, "title": "How many entries. Default 200." },
    "sessionId": { "type": "integer", "minimum": 1, "title": "Only this session" },
    "problemsOnly": { "type": "boolean", "title": "Only asserts, errors, warnings and alerts - not the info and trace around them" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set ns = ..Namespace(args)
	set out = ..Read(ns, ..Rows(args, 200, 2000), +args.%Get("sessionId"), ''args.%Get("problemsOnly"), .err)
	do:err'="" ##class(App.Err).Throw("tool_error", ..Explain(err, ns))
	return out
}

ClassMethod Read(ns As %String, rows As %Integer, session As %Integer, problemsOnly As %Boolean, Output err As %String) As %DynamicObject
{
	set err = "", out = {"data": [], "warnings": []}
	try {
		new $namespace
		set $namespace = ns

		// count at root or error
		set where = "", p = 1, p(1) = rows
		if session > 0 {
			set where = where_" AND SessionId = ?", p = p + 1, p(p) = session
		}
		set:problemsOnly where = where_" AND Type IN (1, 2, 3, 6)"
		set sql = "SELECT TOP ? ID, TimeLogged, Type, ConfigName, SessionId, MessageId, SourceClass, SourceMethod, Text "
			_"FROM Ens_Util.Log WHERE 1 = 1"_where_" ORDER BY ID DESC"
		set rs = ##class(%SQL.Statement).%ExecDirect(, sql, p...)
		if rs.%SQLCODE < 0 {
			set err = "cannot read Ens.Util.Log: "_rs.%Message
			return out
		}
		while rs.%Next() {
			set one = {}
			set one.id = +rs.ID
			set one.ts = rs.TimeLogged
			set one.level = ##class(Ens.DataType.LogType).LogicalToDisplay(rs.Type)
			set one.item = rs.ConfigName
			set one.session = +rs.SessionId
			set one.messageId = +rs.MessageId
			set one.source = rs.SourceClass_$select(rs.SourceMethod="": "", 1: "."_rs.SourceMethod)
			set one.text = rs.Text
			do out.data.%Push(one)
		}
		do:out.data.%Size()=rows out.warnings.%Push("stopped at "_rows_" entries - there are older ones")
	} catch e {
		set err = e.DisplayString()
	}
	return out
}

}
