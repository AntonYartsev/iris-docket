Class App.UnitTest.Invoker Extends App.UnitTest.Base
{

ClassMethod Root() As %String
{
	set root = $system.Util.GetEnviron("PORTAL_SRC")
	return:root'="" root

	try {
		set module = ##class(%IPM.Storage.Module).NameOpen("docket", , .sc)
		return:$isobject(module)&&(module.Root'="") ##class(%File).NormalizeDirectory("src", module.Root)
	} catch {}

	return "/opt/portal/src"
}

ClassMethod Callers(root As %String) As %String [ Language = python ]
{
    import json, os, re
    # split or scan finds itself ha!
    verb = "Exec" + "ute"
    pattern = re.compile(chr(34) + verb + chr(34) + r"|\)\." + verb + r"\(")
    scanned, hits = 0, []
    for folder, _, names in os.walk(root):
        for name in names:
            if not name.endswith(".cls"):
                continue
            path = os.path.join(folder, name)
            if path.endswith(os.path.join("App", "Tools", "Invoker.cls")):
                continue
            scanned += 1
            with open(path, encoding="utf-8", errors="replace") as f:
                for n, line in enumerate(f, 1):
                    if pattern.search(line) and not line.lstrip().startswith("///"):
                        hits.append("%s:%d: %s" % (path, n, line.strip()))
    return json.dumps({"scanned": scanned, "hits": hits})
}

Method TestExecuteHasNoOtherCaller()
{
	set root = ..Root()
	do $$$AssertTrue(##class(%File).DirectoryExists(root), "the sources are where the test expects them ("_root_") - set PORTAL_SRC otherwise")
	set out = ##class(%DynamicAbstractObject).%FromJSON(..Callers(root))
	do $$$AssertTrue(out.scanned > 30, "the scan actually read the sources: "_out.scanned_" classes")
	do $$$AssertEquals(out.hits.%Size(), 0, "nothing calls a tool's Execute() except App.Tools.Invoker: "_out.hits.%ToJSON())
}

ClassMethod Routes(root As %String) As %String [ Language = python ]
{
    import json, os, re
    text = open(os.path.join(root, "App", "REST", "Router.cls"), encoding="utf-8", errors="replace").read()
    called = set(re.findall(r'Call="(\w+)"', text))
    parts = re.split(r"\nClassMethod\s+(\w+)", text)
    bodies = dict(zip(parts[1::2], parts[2::2]))
    return json.dumps({
        "routes": sorted(called),
        "missing": sorted(called - set(bodies)),
        "invoker": sorted(c for c in called if "App.Tools.Invoker" in bodies.get(c, "")),
    })
}

Method TestEveryRouteEitherInvokesOrIsExcused()
{
	set root = ..Root()
	do $$$AssertTrue(##class(%File).DirectoryExists(root), "the sources are where the test expects them ("_root_") - set PORTAL_SRC otherwise")
	set out = ##class(%DynamicAbstractObject).%FromJSON(..Routes(root))
	do $$$AssertTrue(out.routes.%Size() > 5, "the route table was actually read: "_out.routes.%Size()_" handlers")
	do $$$AssertEquals(out.missing.%Size(), 0, "every route names a handler that exists: "_out.missing.%ToJSON())

	set excused = {
		"Info":          "the instance's own facts and the shell's header - nothing is executed",
		"Logout":        "ends the CSP session; there is no instance-side operation behind it",
		"Tools":         "the registry listing itself",
		"OpenApi":       "the registry listing itself, as an OpenAPI document",
		"Policy":        "reads the policy in force - changing it is the policy.update tool",
		"Audit":         "pages the journal for the screen; journalling every debounced filter would fill it with reads of itself",
		"AgentSessions": "the list of conversations, which are the portal's own working copies",
		"AgentSession":  "one conversation's transcript",
		"AgentTurn":     "App.Agent.Loop runs the turn and calls the invoker for every tool call in it"
	}

	set invoker = ",", it = out.invoker.%GetIterator()
	while it.%GetNext(.i, .v) { set invoker = invoker_v_"," }
	set routes = ",", it = out.routes.%GetIterator()
	while it.%GetNext(.i, .v) { set routes = routes_v_"," }

	set bad = "", it = out.routes.%GetIterator()
	while it.%GetNext(.i, .v) {
		continue:invoker[(","_v_",")
		continue:excused.%IsDefined(v)
		set bad = bad_$select(bad="": "", 1: ", ")_v
	}
	do $$$AssertEquals(bad, "", "every route goes through App.Tools.Invoker or is excused by name here: "_bad)

	set stale = "", it = excused.%GetIterator()
	while it.%GetNext(.k, .v) {
		set:'(routes[(","_k_",")) stale = stale_$select(stale="": "", 1: ", ")_k
	}
	do $$$AssertEquals(stale, "", "no excuse is left over from a route that is gone: "_stale)
}

Method TestSchemaViolationsComeBackTogether()
{
	set mark = ..Mark()
	try {
		set code = "", detail = ""
		try {
			do ##class(App.Tools.Invoker).Run("ens.messages", {"maxRows": "soon"}, "user:unittest")
		} catch ex {
			set code = ex.Name, detail = ex.Detail
		}
		do $$$AssertEquals(code, "bad_request", "a missing required argument is refused")
		do $$$AssertTrue($isobject(detail) && (detail.schema.%Size() > 1), "both violations come back together - the missing namespace and the string where a number goes: "_$select($isobject(detail): detail.schema.%ToJSON(), 1: ""))
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
}

Method TestUnknownToolIsRefusedAndWrittenDown()
{
	set mark = ..Mark()
	try {
		set code = "", detail = ""
		try {
			do ##class(App.Tools.Invoker).Run("unittest.system.shell.exec", {"cmd": "id"}, "agent:unittest", "agent")
		} catch ex {
			set code = ex.Name, detail = ex.Detail
		}
		do $$$AssertEquals(code, "not_found", "an invented tool is refused")

		set seq = +detail.auditId
		do $$$AssertTrue(seq > mark.seq, "the refusal got its own journal entry")
		set e = ##class(App.Audit.Entry).SeqIdxOpen(seq)
		do $$$AssertEquals(e.Decision_"/"_e.RuleId, "deny/unknown-tool", "recorded as a denial with its own rule id")
		do $$$AssertEquals(e.Actor, "agent:unittest", "and against whoever asked")
		do $$$AssertEquals(e.Tool, "unittest.system.shell.exec", "with the name that was asked for")
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
	do $$$AssertTrue(##class(App.Audit.Entry).VerifyChain().ok, "the test left the journal as it found it")
}

Method TestSimulateAgainstTheLivePolicy()
{
	do $$$AssertEquals(..Verdict("logs.messages", {}, "user:alice", "ui"), "allow/read-all", "reading runs")
	do $$$AssertEquals(..Verdict("security.user.delete", {"name": "bob"}, "user:alice", "ui"), "deny/no-delete", "deletion is refused")
	do $$$AssertEquals(..Verdict("webapp.update", {"name": "/portal"}, "user:alice", "ui"), "deny/no-lockout-ui", "the portal will not switch itself off")
	do $$$AssertEquals(..Verdict("security.user.grantRole", {"username": "bob", "role": "%All"}, "user:alice", "ui"), "deny/no-superuser", "%All is not handed out")
	do $$$AssertEquals(..Verdict("agent.session.delete", {"id": "s1"}, "agent:unittest", "agent"), "deny/chat-not-agent", "the agent does not get the tool that deletes conversations")
	do $$$AssertEquals(..Verdict("task.run", {"id": 1}, "agent:unittest", "agent"), "confirm/agent-writes-ask", "and every other agent write waits for a human")
}

ClassMethod Verdict(tool As %String, args As %DynamicObject, actor As %String, channel As %String) As %String
{
	set v = ##class(App.Tools.Invoker).Simulate(tool, args, actor, channel)
	return v.decision_"/"_v.ruleId
}

}
