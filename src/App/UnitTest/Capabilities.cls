Class App.UnitTest.Capabilities Extends App.UnitTest.Base
{

Parameter Subject = "admin.info";

Parameter SubjectPath = "/info";

Method TestTheProbeReadsWhatTheInstancePublished()
{
	set caps = ##class(App.Admin.Capabilities).Probe(1)
	do $$$AssertEquals(caps.%Get("error"), "", "the probe ran: "_caps.%Get("error"))
	do $$$AssertTrue(caps.paths > 0, "the instance published a path set: "_caps.paths_" paths")
	do $$$AssertTrue(+caps.apiVersion > 0, "and said which API version it serves: "_caps.apiVersion)
	do $$$AssertTrue(##class(App.Admin.Capabilities).Serves("GET", "/info"), "GET /info is served - it is the one path both versions have")
	do $$$AssertTrue('##class(App.Admin.Capabilities).Serves("DELETE", "/info"), "the method is part of the question: DELETE /info is not served")
	do $$$AssertTrue('##class(App.Admin.Capabilities).Serves("GET", "/v2/nothing/like/this"), "a path nobody serves is not served")
}

Method TestAStaleAnswerIsAskedAgainOnItsOwn()
{
	do ##class(App.Admin.Capabilities).Probe(1)
	try {
		set ^App.Admin("caps", "build") = "IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2025.1 (Build 100U)"
		do $$$AssertEquals(##class(App.Admin.Capabilities).Stale(), "the build changed", "an answer another build gave is stale")
		do ##class(App.Tools.Registry).Get(..#Subject)
		do $$$AssertEquals(^App.Admin("caps", "build"), $zversion, "and the next registry lookup asked again, with no button pressed")
		do $$$AssertEquals(##class(App.Admin.Capabilities).Probe().why, "the build changed", "saying why")

		set ^App.Admin("caps", "failed") = 1
		do $$$AssertEquals(##class(App.Admin.Capabilities).Stale(), "", "a failed check is not retried per tool")
		do $$$AssertEquals(##class(App.Admin.Capabilities).Probe().why, "the last check failed", "but the next /info asks again")
		do $$$AssertEquals($get(^App.Admin("caps", "failed")), "", "and once it worked, stops asking")
		do $$$AssertEquals(##class(App.Admin.Capabilities).Probe().why, "the last check failed", "the answer is cached again")
	} catch ex {
		do $$$AssertTrue(0, ex.DisplayString())
	}
	do ##class(App.Admin.Capabilities).Probe(1)
}

Method TestAnUnprobedInstanceKeepsEverything()
{
	try {
		kill ^App.Admin("caps", "path")
		do $$$AssertTrue(##class(App.Admin.Capabilities).Serves("GET", "/v2/nothing/like/this"), "with nothing known, every call gets the benefit of the doubt")
		do $$$AssertTrue(##class(App.Tools.Registry).Get(..#Subject).%Get("available"), "and every tool stays available")
	} catch ex {
		do $$$AssertTrue(0, ex.DisplayString())
	}
	do ##class(App.Admin.Capabilities).Probe(1)
}

Method TestAToolWhoseEndpointIsGoneIsRefusedAndJournalled()
{
	// probe first or gate fails open
	do ##class(App.Admin.Capabilities).Probe(1)

	set mark = ..Mark()
	try {
		kill ^App.Admin("caps", "path", ..#SubjectPath)

		set meta = ##class(App.Tools.Registry).Get(..#Subject)
		do $$$AssertTrue('meta.%Get("available"), "the registry marks it unavailable")
		do $$$AssertTrue(meta.unavailable.reason [ ..#SubjectPath, "and says which call is missing: "_meta.unavailable.reason)

		set code = "", http = "", text = ""
		try {
			do ##class(App.Tools.Invoker).Run(..#Subject, {}, "user:unittest")
		} catch ex {
			set code = ex.Name, http = ex.Code, text = ex.Data
		}
		do $$$AssertEquals(code, "unavailable", "the call is refused as unavailable, not as not_found: "_code)
		do $$$AssertEquals(http, 501, "501, so a caller can tell a missing version from a missing object")
		do $$$AssertTrue(text [ ..#SubjectPath, "with the reason in the message: "_text)

		set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 Tool,Decision,RuleId,Outcome FROM App_Audit.Entry ORDER BY Seq DESC")
		do rs.%Next()
		do $$$AssertEquals(rs.Tool, ..#Subject, "the attempt is in the journal")
		do $$$AssertEquals(rs.RuleId, "unavailable-on-version", "under its own rule id")
		do $$$AssertEquals(rs.Outcome, "denied", "as a refusal")

		do $$$AssertTrue($isobject(##class(App.Tools.Invoker).Run("task.states", {}, "user:unittest")), "a tool that needs nothing from /api/admin still runs")
	} catch ex {
		do $$$AssertTrue(0, ex.DisplayString())
	}
	do ##class(App.Admin.Capabilities).Probe(1)
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "and the chain is where the test found it")
}

Method TestTheAgentIsNotOfferedWhatCannotRun()
{
	set before = ..Offered()
	set it = ##class(App.Tools.Registry).List().%GetIterator()
	while it.%GetNext(, .m) {
		continue:m.%Get("available")
		do $$$AssertTrue('(before [ (","_m.name_",")), m.name_" is unavailable here and is not in the model's tool list")
	}
	try {
		kill ^App.Admin("caps", "path", ..#SubjectPath)
		set after = ..Offered()
		do $$$AssertTrue(before [ (","_..#Subject_","), ..#Subject_" is offered while it is served")
		do $$$AssertTrue('(after [ (","_..#Subject_",")), "and is not offered once it is not")
	} catch ex {
		do $$$AssertTrue(0, ex.DisplayString())
	}
	do ##class(App.Admin.Capabilities).Probe(1)
}

Method TestEveryGeneratedToolDeclaresItsUpstreamCall()
{
	set generated = 0, silent = ""
	set it = ##class(App.Tools.Registry).List().%GetIterator()
	while it.%GetNext(, .m) {
		continue:m.source'="spec"
		set generated = generated + 1
		continue:m.requires'=""
		set silent = silent_$select(silent="": "", 1: ", ")_m.name
	}
	do $$$AssertTrue(generated > 30, "the registry still has its generated half: "_generated)
	do $$$AssertEquals(silent, "", "each of them names the call it makes: "_silent)
}

ClassMethod Offered() As %String
{
	set names = ",", it = ##class(App.Agent.Loop).ToolSchemas().%GetIterator()
	while it.%GetNext(, .t) {
		set names = names_$translate(t.function.name, "_", ".")_","
	}
	return names
}

}
