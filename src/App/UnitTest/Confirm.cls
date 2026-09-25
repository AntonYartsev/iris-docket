Class App.UnitTest.Confirm Extends App.UnitTest.Base
{

Parameter TOOL = "unittest.confirm";

ClassMethod Hash(json As %String) As %String
{
	return $system.Encryption.Base64Encode($system.Encryption.SHAHash(256, ##class(App.Json).Canonical(json)), 1)
}

Method OnAfterAllTests() As %Status
{
	do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM App_Policy.Confirmation WHERE Tool %STARTSWITH 'unittest.'")
	return $$$OK
}

Method TestRoundTrip()
{
	set h = ..Hash("{""username"":""bob"",""role"":""%Manager""}")
	set token = ##class(App.Policy.Confirmation).Issue(..#TOOL, h, "user:alice")
	do $$$AssertNotEquals(token, "", "a token comes back")
	do $$$AssertTrue(token'[$char(10), "and it is one line - a line break would end up in an HTTP header")

	set code = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem(token, ..#TOOL, h, "user:alice")
	} catch ex {
		set code = ex.Name_": "_ex.Data
	}
	do $$$AssertEquals(code, "", "the same call with the same arguments goes through")
}

Method TestReplayIsRefused()
{
	set h = ..Hash("{""username"":""bob""}")
	set token = ##class(App.Policy.Confirmation).Issue(..#TOOL, h, "user:alice")
	do ##class(App.Policy.Confirmation).Redeem(token, ..#TOOL, h, "user:alice")

	set code = "", message = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem(token, ..#TOOL, h, "user:alice")
	} catch ex {
		set code = ex.Name, message = ex.Data
	}
	do $$$AssertEquals(code, "confirm_invalid", "a token is spent when it is used")
	do $$$AssertTrue(message["already been used", "and says so")
}

Method TestSwappedArgumentsAreRefused()
{
	set shown = ..Hash("{""username"":""bob"",""role"":""%Manager""}")
	set other = ..Hash("{""username"":""bob"",""role"":""%All""}")
	set token = ##class(App.Policy.Confirmation).Issue(..#TOOL, shown, "user:alice")

	set code = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem(token, ..#TOOL, other, "user:alice")
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "confirm_invalid", "confirming %Manager cannot be replayed as %All")
}

Method TestOtherActorOrToolIsRefused()
{
	set h = ..Hash("{""username"":""bob""}")
	set token = ##class(App.Policy.Confirmation).Issue(..#TOOL, h, "user:alice")

	set code = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem(token, ..#TOOL, h, "agent:chat")
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "confirm_invalid", "somebody else's confirmation is not yours to spend")

	set code = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem(token, "unittest.other", h, "user:alice")
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "confirm_invalid", "nor is a confirmation for a different tool")
}

Method TestUnknownTokenIsRefused()
{
	set code = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem("not-a-token", ..#TOOL, ..Hash("{}"), "user:alice")
	} catch ex {
		set code = ex.Name
	}
	do $$$AssertEquals(code, "confirm_invalid", "an invented token is refused")
}

Method TestExpiredIsRefused()
{
	set h = ..Hash("{""username"":""bob""}")
	set token = ##class(App.Policy.Confirmation).Issue(..#TOOL, h, "user:alice")
	set c = ##class(App.Policy.Confirmation).TokenIdxOpen(token)
	set c.ExpiresAt = "2000-01-01 00:00:00"
	do $$$AssertStatusOK(c.%Save(), "the row backdates")

	set code = "", message = ""
	try {
		do ##class(App.Policy.Confirmation).Redeem(token, ..#TOOL, h, "user:alice")
	} catch ex {
		set code = ex.Name, message = ex.Data
	}
	do $$$AssertEquals(code, "confirm_invalid", "an expired confirmation is refused")
	do $$$AssertTrue(message["expired", "and says which of the three refusals it is")
}

Method TestKeyOrderDoesNotChangeTheCall()
{
	set a = ..Hash("{""b"":1,""a"":2}")
	set b = ..Hash("{""a"":2,""b"":1}")
	do $$$AssertEquals(a, b, "key order is not part of the call")
	do $$$AssertNotEquals(a, ..Hash("{""a"":2,""b"":3}"), "a different value is a different call")
}

}
