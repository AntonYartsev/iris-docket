Class App.Tools.Invoker [ Abstract ]
{

ClassMethod Run(name As %String, args As %DynamicObject = "", actor As %String = "", channel As %String = "ui", confirmToken As %String = "", correlationId As %String = "") As %DynamicObject
{
	set:'$isobject(args) args = {}
	set:actor="" actor = "user:"_$username
	set meta = ##class(App.Tools.Registry).Get(name)
	do:'$isobject(meta) ..Unknown(name, args, actor, channel, correlationId)
	do:'meta.%Get("available") ..Refuse(name, args, actor, channel, correlationId, "unavailable-on-version", "unavailable", name_" is not available on this instance: "_meta.unavailable.reason, meta.unavailable)

	// 1 check args
	set errs = ##class(%DynamicAbstractObject).%FromJSON(##class(App.Json).SchemaErrors(meta.schema.%ToJSON(), args.%ToJSON()))
	do:errs.%Size() ##class(App.Err).Throw("bad_request", "the arguments do not match the tool's schema", {"schema": (errs)})

	// 2 canonical json
	set canon = ##class(App.Json).Canonical(args.%ToJSON())
	set hash = $system.Encryption.Base64Encode($system.Encryption.SHAHash(256, canon), 1)

	// 3 ask policy
	set verdict = ##class(App.Policy.Engine).Decide(meta, args, actor, channel)
	set entry = ##class(App.Audit.Entry).%New()
	set entry.Actor = actor, entry.Channel = channel, entry.Tool = name
	set entry.CorrelationId = correlationId
	set entry.Args = ##class(App.Policy.Engine).Redact(canon)
	set entry.Decision = verdict.decision, entry.RuleId = verdict.ruleId

	if verdict.decision = "deny" {
		set entry.Outcome = "denied"
		set entry.ErrorText = "refused by policy rule '"_verdict.ruleId_"'"
		do ##class(App.Audit.Entry).Write(entry)
		do ##class(App.Err).Throw("policy_denied", entry.ErrorText, {"ruleId": (verdict.ruleId), "auditId": (entry.Seq)})
	}
	if verdict.decision = "confirm" {
		if confirmToken = "" {
			// token only to browser!!
			set token = ##class(App.Policy.Confirmation).Issue(name, hash, actor)
			set entry.Outcome = "pending"
			set entry.ErrorText = "waiting for a human confirmation"
			do ##class(App.Audit.Entry).Write(entry)
			do ##class(App.Err).Throw("confirm_required", "this operation needs a human confirmation", {"confirmToken": (token), "ruleId": (verdict.ruleId), "tool": (name), "args": (##class(%DynamicAbstractObject).%FromJSON(canon)), "auditId": (entry.Seq), "expiresInSeconds": (##class(App.Policy.Confirmation).#TTLSECONDS)})
		}
		do ##class(App.Policy.Confirmation).Redeem(confirmToken, name, hash, actor)
	}

	// 4 finaly run
	set t0 = $zhorolog
	try {
		set out = $classmethod(##class(App.Tools.Registry).Class(name), "Execute", args)
		set entry.Outcome = "ok"
	} catch ex {
		set entry.Outcome = "error"
		set entry.DurationMs = ..Elapsed(t0)
		set entry.ErrorText = $extract($select(ex.%IsA("App.Err"): ex.Data, 1: ex.DisplayString()), 1, 1000)
		do ##class(App.Audit.Entry).Write(entry)
		throw ex
	}
	set entry.DurationMs = ..Elapsed(t0)
	set:$isobject(out)&&out.%IsDefined("asyncId") entry.AsyncId = out.asyncId
	do ##class(App.Audit.Entry).Write(entry)

	set res = {}
	set res.data = out.%Get("data")
	set res.meta = {"durationMs": (entry.DurationMs), "auditId": (entry.Seq), "decision": (verdict.decision), "ruleId": (verdict.ruleId)}
	set:out.%IsDefined("warnings")&&out.warnings.%Size() res.meta.warnings = out.warnings
	set:out.%IsDefined("truncated") res.meta.truncated = out.truncated
	set:out.%IsDefined("asyncId") res.meta.asyncId = out.asyncId
	return res
}

ClassMethod Unknown(name As %String, args As %DynamicObject, actor As %String, channel As %String, correlationId As %String)
{
	do ..Refuse(name, args, actor, channel, correlationId, "unknown-tool", "not_found", "no such tool: "_name)
}

ClassMethod Refuse(name As %String, args As %DynamicObject, actor As %String, channel As %String, correlationId As %String, ruleId As %String, code As %String, message As %String, detail As %DynamicObject = "")
{
	set entry = ##class(App.Audit.Entry).%New()
	set entry.Actor = actor, entry.Channel = channel, entry.Tool = name
	set entry.CorrelationId = correlationId
	set entry.Args = ##class(App.Policy.Engine).Redact(##class(App.Json).Canonical(args.%ToJSON()))
	set entry.Decision = "deny", entry.RuleId = ruleId
	set entry.Outcome = "denied"
	set entry.ErrorText = message
	do ##class(App.Audit.Entry).Write(entry)
	set:'$isobject(detail) detail = {}
	do detail.%Set("auditId", entry.Seq, "number")
	do ##class(App.Err).Throw(code, message, detail)
}

ClassMethod Simulate(name As %String, args As %DynamicObject = "", actor As %String = "user", channel As %String = "ui") As %DynamicObject
{
	set meta = ##class(App.Tools.Registry).Get(name)
	do:'$isobject(meta) ##class(App.Err).Throw("not_found", "no such tool: "_name)
	set:'$isobject(args) args = {}
	set verdict = ##class(App.Policy.Engine).Decide(meta, args, actor, channel)
	set verdict.tool = name
	set verdict.actor = actor
	do verdict.%Set("mutating", ''meta.mutating, "boolean")
	return verdict
}

ClassMethod Elapsed(t0 As %Numeric) As %Integer
{
	return (($zhorolog - t0) * 1000) \ 1
}

}
