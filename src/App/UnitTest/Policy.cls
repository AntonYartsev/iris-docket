Class App.UnitTest.Policy Extends App.UnitTest.Base
{

ClassMethod Shipped() As %DynamicObject
{
	set x = ##class(%Dictionary.CompiledXData).%OpenId("App.Policy.Engine||Default")
	do x.Data.Rewind()
	return ##class(%DynamicAbstractObject).%FromJSON(x.Data.Read(32000))
}

ClassMethod Meta(name As %String, mutating As %Boolean) As %DynamicObject
{
	set m = {"privilege": ""}
	set m.name = name
	do m.%Set("mutating", ''mutating, "boolean")
	return m
}

ClassMethod Says(cfg As %DynamicObject, tool As %String, mutating As %Boolean, args As %DynamicObject, actor As %String, channel As %String = "ui") As %String
{
	set v = ##class(App.Policy.Engine).DecideWith(cfg, ..Meta(tool, mutating), args, actor, channel)
	return v.decision_"/"_v.ruleId
}

Method TestShippedMatrix()
{
	set cfg = ..Shipped()
	do $$$AssertEquals(..Says(cfg, "security.user.get", 0, {}, "user:alice"), "allow/read-all", "reading runs")
	do $$$AssertEquals(..Says(cfg, "security.user.get", 0, {}, "agent:chat", "agent"), "allow/read-all", "the agent may read too")
	do $$$AssertEquals(..Says(cfg, "webapp.update", 1, {"name": "/csp/user"}, "user:alice"), "confirm/write-ask", "a write asks a human")
	do $$$AssertEquals(..Says(cfg, "security.user.delete", 1, {}, "user:alice"), "deny/no-delete", "deletion is refused outright")
	do $$$AssertEquals(..Says(cfg, "security.user.grantRole", 1, {"username": "bob", "role": "%All"}, "user:alice"), "deny/no-superuser", "handing out %All is refused")
	do $$$AssertEquals(..Says(cfg, "security.user.grantRole", 1, {"username": "bob", "role": "%Manager"}, "user:alice"), "confirm/write-ask", "any other role is an ordinary confirmed write")
	do $$$AssertEquals(..Says(cfg, "security.user.revokeRole", 1, {"username": "bob", "role": "%All"}, "user:alice"), "confirm/write-ask", "taking %All away is the repair, not the damage")
	do $$$AssertEquals(..Says(cfg, "security.role.save", 1, {"name": "%Manager", "Description": "x"}, "user:alice"), "deny/no-system-roles", "a role that ships with IRIS is not edited from here")
	do $$$AssertEquals(..Says(cfg, "security.role.save", 1, {"name": "PortalDemoReader", "Description": "x"}, "user:alice"), "confirm/write-ask", "a role the instance's own people made is an ordinary confirmed write")
	do $$$AssertEquals(..Says(cfg, "webapp.update", 1, {"name": "/portal"}, "user:alice"), "deny/no-lockout-ui", "the portal cannot switch off its own UI")
	do $$$AssertEquals(..Says(cfg, "webapp.update", 1, {"name": "/portal/api"}, "user:alice"), "deny/no-lockout-api", "nor its own API")
	do $$$AssertEquals(..Says(cfg, "task.run", 1, {"id": 12}, "agent:chat", "agent"), "confirm/agent-writes-ask", "an agent write is parked for a human")

	set pkg = {"name": "objectscript-math", "namespace": "USER"}
	do $$$AssertEquals(..Says(cfg, "packages.install", 1, pkg, "user:alice"), "confirm/packages-change-ask", "installing a package asks a human, by a rule that says packages rather than by the general write rule")
	do $$$AssertEquals(..Says(cfg, "packages.upgrade", 1, pkg, "user:alice"), "confirm/packages-change-ask", "so does upgrading one")
	do $$$AssertEquals(..Says(cfg, "packages.uninstall", 1, pkg, "user:alice"), "confirm/packages-change-ask", "and removing one - reversible, unlike deleting a user, so it is asked rather than refused")
	do $$$AssertEquals(..Says(cfg, "packages.install", 1, pkg, "agent:chat", "agent"), "deny/packages-not-agent", "the agent does not put code on the instance, and is refused before any confirm rule can offer it a token")
	do $$$AssertEquals(..Says(cfg, "packages.uninstall", 1, pkg, "agent:chat", "agent"), "deny/packages-not-agent", "nor take code off it")
	do $$$AssertEquals(..Says(cfg, "packages.uninstall", 1, {"name": "docket", "namespace": "%SYS"}, "user:alice"), "deny/no-self-uninstall", "and the portal will not remove the module it is itself installed as")
	do $$$AssertEquals(..Says(cfg, "packages.jobs", 0, {}, "agent:chat", "agent"), "allow/read-all", "reading what an install did is still reading")
}

Method TestFirstMatchWins()
{
	set cfg = ..Shipped()
	do $$$AssertEquals(..Says(cfg, "agent.session.delete", 1, {"id": "s1"}, "user:alice"), "confirm/chat-delete-ask", "deleting a conversation is an ordinary confirmed write, ahead of no-delete")
	do $$$AssertEquals(..Says(cfg, "agent.session.delete", 1, {"id": "s1"}, "agent:chat", "agent"), "deny/chat-not-agent", "the agent is refused the tool before any confirm rule sees it")
}

Method TestDefaultIsDeny()
{
	set cfg = {"version": 1, "default": "deny", "rules": []}
	do $$$AssertEquals(..Says(cfg, "anything.at.all", 1, {}, "user:alice"), "deny/default", "an unmatched call falls through to the default")
	do $$$AssertEquals(..Shipped().default, "deny", "the shipped default is deny")
}

Method TestTypoCannotWidenARule()
{
	set cfg = {"version": 1, "default": "deny", "rules": [{"id": "oops", "match": {"toool": "security.user.delete"}, "decision": "allow"}]}
	do $$$AssertEquals(..Says(cfg, "security.user.delete", 1, {}, "user:alice"), "deny/default", "a rule with an unknown matcher key never fires")

	set code = "", problems = 0
	try {
		do ##class(App.Policy.Engine).Validate(cfg)
	} catch ex {
		set code = ex.Name
		set:$isobject(ex.Detail) problems = ex.Detail.problems.%Size()
	}
	do $$$AssertEquals(code, "bad_request", "and the validator refuses to save it")
	do $$$AssertEquals(problems, 1, "with exactly the one problem in it")
}

Method TestGlob()
{
	do $$$AssertTrue(##class(App.Policy.Engine).Glob("*.delete", "security.user.delete"), "*.delete catches the family")
	do $$$AssertEquals(##class(App.Policy.Engine).Glob("*.delete", "security.user.deleteAll"), 0, "but not a longer name that starts the same")
	do $$$AssertEquals(##class(App.Policy.Engine).Glob("security.user.get", "securityXuserXget"), 0, "the dots are literal, not any-character")
	do $$$AssertTrue(##class(App.Policy.Engine).Glob("webapp.*", "webapp.update"), "a family prefix matches")
	do $$$AssertTrue(##class(App.Policy.Engine).Glob("*", "whatever"), "* matches everything")
	do $$$AssertTrue(##class(App.Policy.Engine).Glob("agent:*", "agent:chat"), "actors are globbed the same way")
	do $$$AssertEquals(##class(App.Policy.Engine).Glob("agent:*", "user:agentsmith"), 0, "and an actor prefix is anchored")
}

Method TestArgPaths()
{
	set args = {"role": "%All", "User": {"Name": "bob", "Roles": ["%All"]}}
	do $$$AssertEquals(##class(App.Policy.Engine).Arg(args, "args.role"), "%All", "a top level argument")
	do $$$AssertEquals(##class(App.Policy.Engine).Arg(args, "args.User.Name"), "bob", "a nested argument")
	do $$$AssertEquals(##class(App.Policy.Engine).Arg(args, "args.User.Roles"), "", "an array is not a value")
	do $$$AssertEquals(##class(App.Policy.Engine).Arg(args, "args.missing.deeper"), "", "a missing path is empty, not an error")
	do $$$AssertEquals(##class(App.Policy.Engine).Arg(args, "role"), "", "a path outside args. reads nothing")
}

Method TestRedaction()
{
	set out = ##class(App.Policy.Engine).Redact("{""Password"":""s3cret"",""name"":""alice""}")
	do $$$AssertTrue(out'["s3cret", "the policy in force keeps args.Password out of the journal")
	do $$$AssertTrue(out["alice", "and leaves everything else alone")

	set out = ##class(App.Policy.Engine).Redact("{""User"":{""Password"":""s3cret"",""Name"":""bob""}}")
	do $$$AssertTrue(out'["s3cret", "a password nested in a create call is redacted too")
	do $$$AssertTrue(out["bob", "the rest of the nested object survives")
}

Method TestValidateReportsEverythingAtOnce()
{
	set cfg = {"version": 1, "default": "sometimes", "rules": [
		{"id": "ghost", "match": {"tool": "no.such.tool.*"}, "decision": "deny"},
		{"id": "ghost", "match": {"tool": "*"}, "decision": "allowish"}
	]}
	set code = "", problems = []
	try {
		do ##class(App.Policy.Engine).Validate(cfg)
	} catch ex {
		set code = ex.Name
		set:$isobject(ex.Detail) problems = ex.Detail.problems
	}
	do $$$AssertEquals(code, "bad_request", "the config is refused")
	do $$$AssertEquals(problems.%Size(), 4, "all four mistakes come back together, not one per save")
	do $$$AssertTrue(problems.%ToJSON()["no tool in the registry matches", "the dead glob is named")
	do $$$AssertTrue(problems.%ToJSON()["duplicate id", "so is the duplicate id")
}

Method TestValidateRefusesASelfLock()
{
	set cfg = {"version": 1, "default": "deny", "rules": []}
	set code = "", problems = []
	try {
		do ##class(App.Policy.Engine).Validate(cfg)
	} catch ex {
		set code = ex.Name
		set:$isobject(ex.Detail) problems = ex.Detail.problems
	}
	do $$$AssertEquals(code, "bad_request", "a policy that denies everything denies its own repair")
	do $$$AssertTrue(problems.%ToJSON()["policy.update", "and the message says which tool")
}

Method TestShippedPolicyIsValid()
{
	set code = "", text = ""
	try {
		do ##class(App.Policy.Engine).Validate(..Shipped())
	} catch ex {
		set code = ex.Name, text = ex.Data_" "_$select($isobject(ex.Detail): ex.Detail.%ToJSON(), 1: "")
	}
	do $$$AssertEquals(code, "", "the shipped policy validates against the registry: "_text)
}

}
