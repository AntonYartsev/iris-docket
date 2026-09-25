Class App.Err Extends %Exception.AbstractException
{

Property Detail As %DynamicAbstractObject;

ClassMethod Http(code As %String) As %Integer
{
	return $case(code, "bad_request":400, "tool_error":400, "policy_denied":403, "admin_forbidden":403, "not_found":404, "conflict":409, "confirm_required":409, "confirm_invalid":409, "unavailable":501, "unreachable":503, :500)
}

ClassMethod Throw(code As %String, message As %String, detail As %DynamicAbstractObject = "")
{
	set e = ..%New(code, ..Http(code), , message)
	set e.Detail = detail
	throw e
}

ClassMethod Json(e As %Exception.AbstractException) As %DynamicObject
{
	set err = {}
	if e.%IsA("App.Err") {
		set err.code = e.Name
		set err.message = e.Data
		set:$isobject(e.Detail) err.detail = e.Detail
	} else {
		set err.code = "internal"
		set err.message = e.DisplayString()
	}
	return {"error": (err)}
}

}
