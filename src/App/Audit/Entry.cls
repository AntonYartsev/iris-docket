Class App.Audit.Entry Extends %Persistent
{

Property Seq As %Integer;

Property Ts As %TimeStamp;

Property Actor As %String(MAXLEN = 128);

Property Channel As %String(MAXLEN = 16);

Property CorrelationId As %String(MAXLEN = 64);

Property Tool As %String(MAXLEN = 128);

Property Args As %String(MAXLEN = "");

Property Decision As %String(MAXLEN = 16);

Property RuleId As %String(MAXLEN = 64);

Property Outcome As %String(MAXLEN = 16);

Property ErrorText As %String(MAXLEN = 1000);

Property DurationMs As %Integer;

Property AsyncId As %String(MAXLEN = 64);

Property PrevHash As %String(MAXLEN = 64);

Property Hash As %String(MAXLEN = 64);

Index SeqIdx On Seq [ Unique ];

Index TsIdx On Ts;

Index ToolIdx On Tool;

Index ActorIdx On Actor;

Index CorrIdx On CorrelationId;

ClassMethod Write(e As App.Audit.Entry) As %Integer
{
	lock +^App.Audit("chain"):10
	try {
		set e.Seq = $increment(^App.Audit("seq"))
		// normalize before hash, %Save trims
		set e.Ts = ##class(%TimeStamp).Normalize($zdatetime($ztimestamp, 3, 1, 3))
		set e.PrevHash = $get(^App.Audit("chain"))
		set e.Hash = ..HashOf(e)
		set sc = e.%Save()
		do:$system.Status.IsError(sc) ##class(App.Err).Throw("internal", "cannot write the audit entry: "_$system.Status.GetErrorText(sc))
		set ^App.Audit("chain") = e.Hash
	} catch ex {
		lock -^App.Audit("chain")
		throw ex
	}
	lock -^App.Audit("chain")
	return e.Seq
}

/// hash utf8 bytes not internal
ClassMethod HashOf(e As App.Audit.Entry) As %String
{
	return $system.Encryption.Base64Encode($system.Encryption.SHAHash(256, $zconvert(e.PrevHash_##class(App.Json).Canonical(..Record(e).%ToJSON()), "O", "UTF8")), 1)
}

ClassMethod Record(e As App.Audit.Entry) As %DynamicObject
{
	set r = {}
	set r.seq = e.Seq, r.ts = e.Ts, r.actor = e.Actor, r.channel = e.Channel
	set r.correlationId = e.CorrelationId, r.tool = e.Tool, r.args = e.Args
	set r.decision = e.Decision, r.ruleId = e.RuleId, r.outcome = e.Outcome
	set r.errorText = e.ErrorText, r.durationMs = e.DurationMs, r.asyncId = e.AsyncId
	return r
}

/// ponytail: whole journal at once
ClassMethod Export() As %DynamicObject
{
	set entries = []
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM App_Audit.Entry ORDER BY Seq")
	// no SELECT looks like empty
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("internal", "the journal could not be read: "_rs.%Message)
	while rs.%Next() {
		set e = ..%OpenId(rs.%Get("ID"))
		continue:'$isobject(e)
		set r = ..Record(e)
		set r.prevHash = e.PrevHash, r.hash = e.Hash
		do entries.%Push(r)
	}
	return {
		"instance": ($system.INetInfo.LocalHostName()_":"_##class(%SYS.System).GetInstanceName()),
		"exportedAt": ($zdatetime($ztimestamp, 3, 1, 3)),
		"algorithm": "hash = base64(sha256(utf8(prevHash + canonical(entry without prevHash and hash)))), canonical = JSON with keys sorted and no whitespace",
		"entries": (entries)
	}
}

ClassMethod VerifyChain() As %DynamicObject
{
	set prev = "", n = 0
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM App_Audit.Entry ORDER BY Seq")
	// no SELECT looks like empty
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("internal", "the journal could not be read: "_rs.%Message)
	while rs.%Next() {
		set e = ..%OpenId(rs.%Get("ID"))
		continue:'$isobject(e)
		set n = n + 1
		if e.PrevHash '= prev {
			return {"ok": false, "brokenAt": (e.Seq), "reason": "this entry does not follow the one before it - a record was inserted or removed", "entries": (n)}
		}
		if e.Hash '= ..HashOf(e) {
			return {"ok": false, "brokenAt": (e.Seq), "reason": "this entry was altered after it was written", "entries": (n)}
		}
		set prev = e.Hash
	}
	return {"ok": true, "entries": (n)}
}

}
