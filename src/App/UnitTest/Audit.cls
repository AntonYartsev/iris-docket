Class App.UnitTest.Audit Extends App.UnitTest.Base
{

ClassMethod Append(tool As %String, decision As %String = "allow", outcome As %String = "ok") As %Integer
{
	set e = ##class(App.Audit.Entry).%New()
	set e.Actor = "user:unittest", e.Channel = "script", e.Tool = tool
	set e.Args = "{}", e.Decision = decision, e.RuleId = "read-all", e.Outcome = outcome
	return ##class(App.Audit.Entry).Write(e)
}

ClassMethod Page(changes As %Boolean) As %String
{
	new %request, %response
	set %request = ##class(%CSP.Request).%New(), %response = ##class(%CSP.Response).%New()
	set %request.Data("limit", 1) = 3
	set:changes %request.Data("changes", 1) = 1
	set file = ##class(%File).TempFilename("json"), io = $io
	open file:"WNS" use file
	do ##class(App.REST.Router).Audit()
	close file
	use io
	set stream = ##class(%Stream.FileCharacter).%New()
	do stream.LinkToFile(file)
	set it = ##class(%DynamicAbstractObject).%FromJSON(stream).data.%GetIterator(), seqs = ","
	while it.%GetNext(, .e) {
		set seqs = seqs_e.seq_","
	}
	do ##class(%File).Delete(file)
	return seqs
}

ClassMethod Sql(statement As %String, arg)
{
	set rs = ##class(%SQL.Statement).%ExecDirect(, statement, arg)
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("internal", rs.%Message)
}

Method TestChangesLeaveOutReadsThatWentThrough()
{
	set mark = ..Mark()
	try {
		set read = ..Append("process.list")
		set refused = ..Append("process.list", "deny")
		set write = ..Append("process.terminate")
		do $$$AssertTrue(..Page(0)[(","_read_","), "without the flag the read is on the page")
		set page = ..Page(1)
		do $$$AssertTrue(page[(","_write_","), "a write that went through is a change")
		do $$$AssertTrue(page[(","_refused_","), "a refused read is a refusal")
		do $$$AssertTrue('(page[(","_read_",")), "a read that went through is left out: "_page)
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the test left the journal as it found it")
}

Method TestStatsCountEachKindOnce()
{
	set mark = ..Mark()
	try {
		set before = ##class(App.Tools.Audit.Stats).Count().total
		do ..Append("process.list")
		do ..Append("process.terminate")
		do ..Append("process.terminate", "confirm", "pending")
		do ..Append("process.terminate", "deny", "denied")
		do ..Append("process.list", "allow", "error")
		set after = ##class(App.Tools.Audit.Stats).Count().total
		do $$$AssertEquals(after.calls - before.calls, 5, "every row is a call")
		do $$$AssertEquals(after.changes - before.changes, 1, "a write that went through is a change, a read is not")
		do $$$AssertEquals(after.asked - before.asked, 1, "a pending row is a person being asked")
		do $$$AssertEquals(after.refused - before.refused, 1, "a deny is a refusal")
		do $$$AssertEquals(after.failed - before.failed, 1, "an error is a failure")
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the test left the journal as it found it")
}

Method TestEditedRecordIsCaught()
{
	set mark = ..Mark()
	try {
		do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the journal is intact before the test")

		do ..Append("unittest.audit.a")
		set middle = ..Append("unittest.audit.b")
		do ..Append("unittest.audit.c")
		set v = ##class(App.Audit.Entry).VerifyChain()
		do $$$AssertTrue(v.ok, "three entries append cleanly")
		do $$$AssertTrue(v.entries'<3, "and are counted")

		do ..Sql("UPDATE App_Audit.Entry SET Args = '{""tampered"":true}' WHERE Seq = ?", middle)
		set v = ##class(App.Audit.Entry).VerifyChain()
		do $$$AssertEquals(''v.ok, 0, "an edited record breaks the chain")
		do $$$AssertEquals(v.brokenAt, middle, "at the entry that was edited, not the one after it")
		do $$$AssertTrue(v.reason["altered", "and says what happened")

		do ..Sql("UPDATE App_Audit.Entry SET Args = '{}' WHERE Seq = ?", middle)
		do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "putting the value back makes it verify again - the hash is over the content, not over a flag")
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the test left the journal as it found it")
}

Method TestRemovedRecordIsCaught()
{
	set mark = ..Mark()
	try {
		do ..Append("unittest.audit.a")
		set middle = ..Append("unittest.audit.b")
		set last = ..Append("unittest.audit.c")
		do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "three entries append cleanly")

		do ..Sql("DELETE FROM App_Audit.Entry WHERE Seq = ?", middle)
		set v = ##class(App.Audit.Entry).VerifyChain()
		do $$$AssertEquals(''v.ok, 0, "a removed record breaks the chain")
		do $$$AssertEquals(v.brokenAt, last, "at the entry that no longer follows the one before it")
		do $$$AssertTrue(v.reason["inserted or removed", "and says what happened")
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the test left the journal as it found it")
}

Method TestExportCanBeCheckedFromOutside()
{
	set mark = ..Mark()
	try {
		do ..Append("unittest.audit.export")

		set e = ##class(App.Audit.Entry).%New()
		set e.Actor = "user:unittest", e.Channel = "script", e.Tool = "unittest.audit.wide"
		// codepoints, not file bytes
		set e.Args = ##class(App.Json).Canonical("{""note"":"""_$char(1090,1077,1089,1090)_"""}")
		set e.Decision = "allow", e.RuleId = "read-all", e.Outcome = "ok"
		do ##class(App.Audit.Entry).Write(e)

		set entries = ##class(App.Audit.Entry).Export().entries
		set n = entries.%Size()
		do $$$AssertTrue(n > 1, "the export carries the journal")

		for i = n - 2:1:n - 1 {
			set row = entries.%Get(i)
			do $$$AssertEquals(..Recompute(row.%ToJSON()), row.hash, "entry "_row.seq_": the digest re-computed from the export alone is the one the export carries")
		}
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the test left the journal as it found it")
}

ClassMethod Recompute(entry As %String) As %String [ Language = python ]
{
    import json, hashlib, base64
    e = json.loads(entry)
    prev = e.pop("prevHash", "")
    e.pop("hash", None)
    canonical = json.dumps(e, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return base64.b64encode(hashlib.sha256((prev + canonical).encode("utf-8")).digest()).decode()
}

Method TestTimestampSurvivesSaving()
{
	set mark = ..Mark()
	try {
		set seq = ..Append("unittest.audit.ts")
		set e = ##class(App.Audit.Entry).SeqIdxOpen(seq)
		do $$$AssertEquals(e.Hash, ##class(App.Audit.Entry).HashOf(e), "the hash of the record as read back is the hash that was stored")
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
}

}
