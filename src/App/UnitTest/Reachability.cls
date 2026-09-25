Class App.UnitTest.Reachability Extends App.UnitTest.Base
{

ClassMethod Raw() As %DynamicObject
{
	return {
		"portal": "docket",
		"webapps": [ {"name": "/api/monitor", "autheEnabled": 64, "resource": "", "roles": ["MonitorRole"]} ],
		"roles": { "MonitorRole": {"resources": [{"resource": "%DB_X", "permissions": "RW"}], "nested": []} },
		"users": []
	}
}

ClassMethod User(name As %String, direct As %Boolean) As %DynamicObject
{
	set u = {"user": (name), "roles": [], "privileges": [], "enabled": true}
	do u.%Set("superuser", 1, "boolean")
	set r = {"name": "%All"}
	do r.%Set("direct", ''direct, "boolean")
	do u.roles.%Push(r)
	return u
}

ClassMethod Link(out As %DynamicObject, id As %String) As %DynamicObject
{
	set it = out.data.links.%GetIterator()
	while it.%GetNext(, .l) { return:l.id=id l }
	return ""
}

ClassMethod Node(out As %DynamicObject, id As %String) As %DynamicObject
{
	set it = out.data.nodes.%GetIterator()
	while it.%GetNext(, .n) { return:n.id=id n }
	return ""
}

ClassMethod Has(list As %DynamicArray, value As %String) As %Boolean
{
	set it = list.%GetIterator()
	while it.%GetNext(, .v) { return:v=value 1 }
	return 0
}

Method TestAnonymousWebAppReachesAResource()
{
	set out = ..Build(..Raw(), ["%DB_X"], [])
	set link = ..Link(out, "a|/api/monitor|%DB_X")
	do $$$AssertTrue($isobject(link), "the anonymous path is in the map")
	quit:'$isobject(link)
	do $$$AssertTrue(link.anonymous, "and it is marked anonymous")
	do $$$AssertEquals(link.severity, "high", "at the severity the Findings screen gives it")
	do $$$AssertEquals(link.fix.tool, "webapp.update", "the fix is the operation that already exists")
	do $$$AssertEquals(+link.fix.args.AutheEnabled, 32, "with the Unauthenticated bit taken out")
	do $$$AssertEquals(+out.data.counts.anonymousPaths, 1, "one anonymous path is counted")
	do $$$AssertTrue($isobject(..Node(out, "r:%DB_X")), "the resource is a node in the third column")
}

Method TestAssumeWebAppUpdateClosesThePath()
{
	set assume = [ {"tool": "webapp.update", "args": {"name": "/api/monitor", "AutheEnabled": 32}} ]
	set out = ..Build(..Raw(), ["%DB_X"], assume)
	do $$$AssertTrue('$isobject(..Link(out, "a|/api/monitor|%DB_X")), "the path is gone")
	do $$$AssertTrue(..Has(out.data.removed, "a|/api/monitor|%DB_X"), "and is listed as removed")
	do $$$AssertEquals(+out.data.counts.anonymousPaths, 0, "nothing reaches the instance anonymously any more")
}

Method TestAssumeRevokeRoleClosesAUserPath()
{
	set raw = ..Raw()
	do raw.users.%Push(..User("bob", 1))
	set id = "u|bob|%All|%All"
	do $$$AssertTrue($isobject(..Link(..Build(raw, ["%All"], []), id)), "bob reaches everything to start with")

	set assume = [ {"tool": "security.user.revokeRole", "args": {"username": "bob", "role": "%All"}} ]
	set out = ..Build(raw, ["%All"], assume)
	do $$$AssertTrue('$isobject(..Link(out, id)), "and not after the revoke")
	do $$$AssertTrue(..Has(out.data.removed, id), "which is what removed says")
}

Method TestThePortalsOwnAccountGetsNoFix()
{
	set raw = ..Raw()
	do raw.users.%Push(..User("docket", 1))
	set link = ..Link(..Build(raw, ["%All"], []), "u|docket|%All|%All")
	do $$$AssertTrue($isobject(link), "the account is still on the map")
	quit:'$isobject(link)
	do $$$AssertTrue('link.%IsDefined("fix"), "with no fix offered")
	do $$$AssertTrue(link.noFixReason [ "portal", "and the reason says why: "_link.noFixReason)
	do $$$AssertEquals(link.severity, "low", "the account the portal runs as is the mild case")

	set raw = ..Raw()
	do raw.users.%Push(..User("carol", 0))
	set link = ..Link(..Build(raw, ["%All"], []), "u|carol|%All|%All")
	do $$$AssertTrue($isobject(link) && 'link.%IsDefined("fix"), "%All through another role has no fix")
	do $$$AssertTrue($isobject(link) && (link.noFixReason [ "inherited"), "because it comes off the role")
	do $$$AssertEquals(link.severity, "medium", "but any other account holding %All is not mild")
}

Method TestIdenticalAccountsCollapse()
{
	set raw = ..Raw()
	do raw.users.%Push(..User("alice", 1))
	do raw.users.%Push(..User("bob", 1))
	set out = ..Build(raw, ["%All"], [])
	do $$$AssertEquals(+out.data.counts.principals, 2, "both accounts are one principal, next to Anonymous")
	do $$$AssertTrue('$isobject(..Node(out, "p:bob")), "the second account has no node of its own")
	set node = ..Node(out, "p:alice")
	do $$$AssertTrue($isobject(node), "named after the first of them")
	quit:'$isobject(node)
	do $$$AssertEquals(node.members.%Size(), 2, "and holding the full list")
	do $$$AssertEquals(+..Link(out, "u|alice|%All|%All").weight, 2, "the link is as thick as the group")
}

ClassMethod Build(raw As %DynamicObject, targets As %DynamicArray, assume As %DynamicArray) As %DynamicObject
{
	return ##class(App.Tools.Insight.Reachability).Build(raw, targets, assume)
}

}
