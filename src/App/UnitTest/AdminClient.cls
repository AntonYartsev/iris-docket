Class App.UnitTest.AdminClient Extends App.UnitTest.Base
{

ClassMethod Failure(status As %Integer, body As %String, path As %String = "/v2/unittest") As %String
{
	set json = $select(body="": "", 1: ##class(%DynamicAbstractObject).%FromJSON(body))
	try {
		do ##class(App.Admin.Client).Fail(status, json, path)
	} catch ex {
		return ex.Name_": "_ex.Data
	}
	return "did not throw"
}

Method TestErrorsAreNormalised()
{
	do $$$AssertEquals(..Failure(400, "{""status"":{""errors"":[{""error"":""name is required"",""id"":""MissingParameter""}]}}"), "bad_request: name is required", "the message comes out of the object, not out of str()")
	do $$$AssertTrue(..Failure(500, "{""status"":{""errors"":[{""error"":""user exists"",""id"":""UserAlreadyExists""}]}}")["conflict:", "the id decides, not the 500")
	do $$$AssertTrue(..Failure(404, "{""status"":{""errors"":[{""error"":""no such user"",""id"":""UserDoesNotExist""}]}}")["not_found:", "a missing object is a 404 we pass on")
	do $$$AssertTrue(..Failure(403, "{""status"":{""errors"":[{""error"":""denied""}]}}")["admin_forbidden:", "a privilege refusal keeps its own code")
}

Method TestNestedErrorsAreFlattened()
{
	set out = ..Failure(400, "{""status"":{""errors"":[{""errors"":[{""error"":""Roles is not a list""}]}]}}")
	do $$$AssertEquals(out, "bad_request: Roles is not a list", "the nested error text is found")
}

Method TestEmptyBodiesAreExplained()
{
	do $$$AssertTrue(..Failure(401, "")["IRIS_ADMIN_USER", "a 401 is the portal's own credentials, and the message says where to look")
	do $$$AssertTrue(..Failure(403, "")["lacks the privilege", "a 403 with no body is a privilege denial")

	kill ^App.Drift("/v2/unittest/ghost")
	set out = ..Failure(404, "", "/v2/unittest/ghost")
	do $$$AssertTrue(out["no route", "a 404 with no body is drift, not a missing object")
	do $$$AssertTrue($data(^App.Drift("/v2/unittest/ghost")), "and it is recorded for the Findings screen")
	kill ^App.Drift("/v2/unittest/ghost")
}

Method TestObjectScriptErrorsAreNotPassedOn()
{
	set out = ..Failure(500, "{""status"":{""errors"":[{""error"":""<PROTECT> zTest+4^App.Secret.1 /usr/irissys/mgr/"",""id"":""ObjectScriptError""}]}}")
	do $$$AssertTrue(out'["PROTECT", "the internal error text does not reach the caller")
	do $$$AssertTrue(out["messages.log", "and the caller is told where it went")
}

Method TestTruncationIsNoticed()
{
	set out = {"data": {}, "warnings": []}
	do ##class(App.Admin.Client).NoteTruncation([1, 2, 3], {"maxRows": 3}, out)
	do $$$AssertEquals(''out.%Get("truncated"), 1, "a list exactly at the cap is flagged")
	do $$$AssertEquals(out.warnings.%Size(), 1, "and says what to do about it")

	set out = {"data": {}, "warnings": []}
	do ##class(App.Admin.Client).NoteTruncation([1, 2], {"maxRows": 3}, out)
	do $$$AssertEquals(out.%IsDefined("truncated"), 0, "a shorter list is not flagged")

	set out = {"data": {}, "warnings": []}
	do ##class(App.Admin.Client).NoteTruncation({"Name": "bob"}, {}, out)
	do $$$AssertEquals(out.%IsDefined("truncated"), 0, "and a single object is not a list")
}

Method TestQueryString()
{
	do $$$AssertEquals(##class(App.Admin.Client).QueryString({"on": true, "off": false}), "?on=true&off=false", "booleans keep their spelling")
	do $$$AssertEquals(##class(App.Admin.Client).QueryString({"name": "/csp/user"}), "?name=/csp/user", "a path value goes through as a path")
	do $$$AssertEquals(##class(App.Admin.Client).QueryString({"name": "a b&maxRows=1"}), "?name=a%20b%26maxRows%3D1", "a value cannot forge a second parameter")
	do $$$AssertEquals(##class(App.Admin.Client).QueryString({}), "", "no arguments, no question mark")
}

Method TestThePortalWillNotKillItself()
{
	set code = ""
	try {
		do ##class(App.Admin.Client).CheckNotSelf("/v2/process/terminate", {"id": ($job)})
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "bad_request", "terminating the process behind this request is refused before the call leaves")

	set code = ""
	try {
		do ##class(App.Admin.Client).CheckNotSelf("/v2/process/terminate", {"id": ($job + 1)})
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "", "any other process is the API's business")
}

Method TestUnknownRolesAreRefusedBeforeTheCall()
{
	if '##class(App.Admin.Capabilities).Serves("GET", "/v2/security/roles") {
		do $$$AssertTrue('##class(App.Tools.Registry).Get("security.user.create").%Get("available"), "this build has no role list, and no tool that would need one can run")
		quit
	}

	set code = "", missing = ""
	try {
		do ##class(App.Admin.Client).CheckRoles({"Roles": ["PortalNoSuchRoleUnitTest"]})
	} catch ex {
		set code = ex.Name
		set:$isobject(ex.Detail) missing = ex.Detail.missingRoles.%ToJSON()
	}
	do $$$AssertEquals(code, "bad_request", "a role this instance does not have is refused before the call leaves")
	do $$$AssertTrue(missing["PortalNoSuchRoleUnitTest", "and the reply names it")

	set code = ""
	try {
		do ##class(App.Admin.Client).CheckRoles({"User": {"Name": "bob", "Roles": ["PortalNoSuchRoleUnitTest"]}})
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "bad_request", "creating a user nests the same field one level down, and it is checked there too")

	set code = ""
	try {
		do ##class(App.Admin.Client).CheckRoles({"Roles": ["%All"], "EscalationRoles": ["%Manager"]})
	} catch ex {
		set code = ex.Name_": "_ex.Data
	}
	do $$$AssertEquals(code, "", "roles the instance does have go through")
}

}
