Class App.Tools.Logs.Audit Extends App.Tools.Base
{

Parameter ToolName = "logs.audit";

Parameter Title = "System audit records, newest first";

Parameter Category = "logs";

Parameter Mutating = 0;

Parameter Requires = "GET /v2/security/audit/enabled, POST /v2/security/audit/records";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "maxRows": { "type": "integer", "minimum": 1, "maximum": 2000, "title": "How many records. Default 200." },
    "beginDateTime": { "type": "string", "title": "First record, e.g. 2026-09-16 00:00:00. Empty = from the beginning." },
    "endDateTime": { "type": "string", "title": "Last record. Empty = up to now." },
    "usernames": { "type": "string", "title": "Comma separated user names" },
    "events": { "type": "string", "title": "Comma separated event names, e.g. LoginFailure" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set out = {"data": [], "warnings": []}

	set enabled = ##class(App.Admin.Client).Call("GET", "/v2/security/audit/enabled").data.%Get("Enabled")
	do:'enabled out.warnings.%Push("auditing is disabled on this instance - these records are whatever was collected before it was turned off")

	set rows = +args.%Get("maxRows")
	set:rows'>0 rows = 200
	set:rows>2000 rows = 2000
	set query = {"maxRows": (rows)}
	do query.%Set("ascending", 0, "number")
	for field = "beginDateTime", "endDateTime", "usernames", "events" {
		do:args.%Get(field)'="" query.%Set(field, args.%Get(field))
	}

	set id = ##class(App.Admin.Client).Call("POST", "/v2/security/audit/records", query).%Get("asyncId")
	do:id="" ##class(App.Err).Throw("tool_error", "/v2/security/audit/records accepted the request without an async id")

	// ponytail: fixed 20x200ms polling
	for i = 1:1:20 {
		set res = ##class(App.Admin.Client).Call("GET", "/v2/async-result", {"id": (id)}).data
		quit:res.%Get("State")'="Running"
		hang 0.2
	}
	do:res.%Get("State")'="Finished" ##class(App.Err).Throw("tool_error", "the instance is still reading the audit database after 4 seconds (state "_res.%Get("State")_") - narrow the time window")
	do:res.%Get("FailureReason")'="" ##class(App.Err).Throw("tool_error", res.FailureReason)

	set list = res.%Get("Result")
	return:'$isobject(list) out
	set it = list.%GetIterator()
	while it.%GetNext(.i, .r) {
		do out.data.%Push(..Row(r))
	}
	return out
}

ClassMethod Row(r As %DynamicObject) As %DynamicObject
{
	set row = {}
	set row.ts = r.%Get("TimeStamp")
	set row.source = "audit"
	// ponytail: level guessed from event
	set row.level = $select($zconvert(r.%Get("Event"), "L") [ "failure": "warn", 1: "info")
	set row.process = r.%Get("Pid")
	set row.category = r.%Get("EventSource")_"."_r.%Get("Event")
	set row.text = $select(r.%Get("Description") '= "": r.%Get("Description"), 1: r.%Get("Event"))
	set row.user = r.%Get("Username")
	set row.namespace = r.%Get("Namespace")
	set row.roles = r.%Get("Roles")
	set row.detail = r.%Get("EventData")
	return row
}

}
