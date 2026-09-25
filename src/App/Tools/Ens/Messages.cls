Class App.Tools.Ens.Messages Extends App.Tools.Ens.Base
{

Parameter ToolName = "ens.messages";

Parameter Title = "Interoperability message headers, newest first";

Parameter Mutating = 0;

Parameter Privilege = "%Ens_MessageHeader:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["namespace"],
  "properties": {
    "namespace": { "type": "string", "title": "Interoperability namespace, e.g. USER" },
    "maxRows": { "type": "integer", "minimum": 1, "maximum": 2000, "title": "How many headers. Default 200." },
    "sessionId": { "type": "integer", "minimum": 1, "title": "Only this session, i.e. one inbound message and everything it caused" },
    "errorsOnly": { "type": "boolean", "title": "Only the headers that failed" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set ns = ..Namespace(args)
	set out = ..Read(ns, ..Rows(args, 200, 2000), +args.%Get("sessionId"), ''args.%Get("errorsOnly"), .err)
	do:err'="" ##class(App.Err).Throw("tool_error", ..Explain(err, ns))
	return out
}

ClassMethod Read(ns As %String, rows As %Integer, session As %Integer, errorsOnly As %Boolean, Output err As %String) As %DynamicObject
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
		set:errorsOnly where = where_" AND IsError = 1"
		set sql = "SELECT TOP ? ID, TimeCreated, TimeProcessed, SessionId, SourceConfigName, TargetConfigName, "
			_"MessageBodyClassName, MessageBodyId, Status, IsError, ErrorStatus "
			_"FROM Ens.MessageHeader WHERE 1 = 1"_where_" ORDER BY ID DESC"
		set rs = ##class(%SQL.Statement).%ExecDirect(, sql, p...)
		if rs.%SQLCODE < 0 {
			set err = "cannot read Ens.MessageHeader: "_rs.%Message
			return out
		}
		while rs.%Next() {
			set one = {}
			set one.id = +rs.ID
			set one.ts = rs.TimeCreated
			set one.processedAt = rs.TimeProcessed
			set one.session = +rs.SessionId
			set one.source = rs.SourceConfigName
			set one.target = rs.TargetConfigName
			set one.body = rs.MessageBodyClassName
			set one.bodyId = rs.MessageBodyId
			set one.status = ##class(Ens.DataType.MessageStatus).LogicalToDisplay(rs.Status)
			do one.%Set("error", ''rs.IsError, "boolean")
			set one.errorText = $select(rs.ErrorStatus="": "", 1: $zstrip($replace($system.Status.GetErrorText(rs.ErrorStatus), $char(13, 10), " "), "<>W"))
			do out.data.%Push(one)
		}
		do:out.data.%Size()=rows out.warnings.%Push("stopped at "_rows_" headers - there are older ones")
	} catch e {
		set err = e.DisplayString()
	}
	return out
}

}
