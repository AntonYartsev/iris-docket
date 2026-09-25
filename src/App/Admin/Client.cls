Class App.Admin.Client [ Abstract ]
{

Parameter DefaultMaxRows = 1000;

ClassMethod Call(method As %String, path As %String, query As %DynamicObject = "", body As %DynamicAbstractObject = "") As %DynamicObject
{
	set:'$isobject(query) query = {}
	// POST need a body, D-14
	set:'$isobject(body)&&((method="POST")||(method="PUT")) body = {}
	// api save fake roles ha! D-12
	do:$isobject(body)&&((method="POST")||(method="PUT")) ..CheckRoles(body)
	do:(method="POST")&&($extract(path, 1, 12)="/v2/process/") ..CheckNotSelf(path, query)

	set req = ##class(%Net.HttpRequest).%New()
	set req.Server = "127.0.0.1"
	set req.Port = $get(^%SYS("WebServer","Port"), 52773)
	set req.Username = ..Cred("IRIS_ADMIN_USER", "_SYSTEM")
	set req.Password = ..Cred("IRIS_ADMIN_PASSWORD", "")
	set req.Timeout = 60
	set req.ContentType = "application/json"
	do:$isobject(body) req.EntityBody.Write(body.%ToJSON())

	set url = "/api/admin"_path_..QueryString(query)
	set sc = req.Send(method, url)
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("internal", "cannot reach /api/admin: "_$system.Status.GetErrorText(sc))

	set rsp = req.HttpResponse
	set code = rsp.StatusCode
	set json = ..Body(rsp)
	set out = {"data": {}, "warnings": []}

	if code = 202 {
		// guid only in header, D-07
		set out.asyncId = $piece(rsp.GetHeader("LOCATION"), "id=", 2)
		return out
	}
	if (code = 200) || (code = 201) {
		set data = ""
		set:$isobject(json) data = json.%Get("result")
		set:'$isobject(data) data = {}
		set out.data = data
		do ..NoteTruncation(data, query, out)
		return out
	}
	do ..Fail(code, json, path)
}

ClassMethod Info(refresh As %Boolean = 0) As %DynamicObject
{
	if refresh || '$data(^App.Admin("info")) {
		set ^App.Admin("info") = ..Call("GET", "/info").data.%ToJSON()
	}
	return ##class(%DynamicAbstractObject).%FromJSON(^App.Admin("info"))
}

/// never kill own proces!!
ClassMethod CheckNotSelf(path As %String, query As %DynamicObject)
{
	quit:+query.%Get("id")'=$job
	do ##class(App.Err).Throw("bad_request", "process "_$job_" is the one serving this request - "_$piece(path, "/", 4)_" on it would kill the portal's own reply before the operation is journalled", {"pid": ($job)})
}

ClassMethod CheckRoles(body As %DynamicAbstractObject)
{
	set wanted = {}
	do ..WantedRoles(body, wanted)
	do ..WantedRoles(body.%Get("User"), wanted)
	quit:wanted.%Size()=0

	set known = {}
	set it = ..Call("GET", "/v2/security/roles", {"maxRows": 5000}).data.%GetIterator()
	while it.%GetNext(.i, .r) {
		do known.%Set(r.Name, "")
	}

	set missing = [], names = "", it = wanted.%GetIterator()
	while it.%GetNext(.name) {
		continue:known.%IsDefined(name)
		do missing.%Push(name)
		set names = names_$select(names = "": "", 1: ", ")_name
	}
	quit:missing.%Size()=0
	do ##class(App.Err).Throw("bad_request", "this instance has no role "_names_" - /api/admin would have accepted it and stored it", {"missingRoles": (missing)})
}

ClassMethod WantedRoles(node As %DynamicAbstractObject, wanted As %DynamicObject)
{
	quit:'$isobject(node)
	for field = "Roles", "EscalationRoles" {
		set list = node.%Get(field)
		continue:'$isobject(list)
		set it = list.%GetIterator()
		while it.%GetNext(.i, .v) {
			do:v'="" wanted.%Set(v, "")
		}
	}
}

ClassMethod Fail(code As %Integer, json As %DynamicObject, path As %String)
{
	set errors = "", status = "", texts = []
	set:$isobject(json) status = json.%Get("status")
	set:$isobject(status) errors = status.%Get("errors")
	do:$isobject(errors) ..Flatten(errors, texts)

	set id = "", irisCode = ""
	if $isobject(errors), errors.%Size() > 0 {
		set first = errors.%Get(0)
		set id = first.%Get("id")
		set irisCode = first.%Get("code")
	}

	set ours = $case(code, 400:"bad_request", 422:"bad_request", 403:"admin_forbidden", 404:"not_found", 409:"conflict", 401:"internal", :"tool_error")
	set ours = $case(id, "UserAlreadyExists":"conflict", "AlreadyMounted":"conflict", "UserDoesNotExist":"not_found", "LoadObjectNotFound":"not_found", :ours)
	// D-20, 500 means broken ref
	set:(code=500)&&((id="RoleDoesNotExist")||(id="ResourceDoesNotExist")) ours = "bad_request"

	set message = $select(texts.%Size() > 0: texts.%Get(0), 1: "")
	if code = 401 {
		set message = "the portal's own credentials were rejected by /api/admin - check IRIS_ADMIN_USER / IRIS_ADMIN_PASSWORD"
	} elseif (code = 404) && (texts.%Size() = 0) {
		// empty body = no route
		set ours = "internal"
		set message = "this instance has no route "_path_" - the pinned spec and the instance disagree"
		set ^App.Drift(path) = $zdatetime($ztimestamp, 3, 1)
	} elseif (code = 403) && (texts.%Size() = 0) {
		set message = "the portal's account lacks the privilege for this operation"
	} elseif id = "ObjectScriptError" {
		// dont leak routine names
		set message = "the instance refused the operation internally (see messages.log)"
		set texts = []
	}
	set:message="" message = "/api/admin answered "_code

	do ##class(App.Err).Throw(ours, message, {"httpStatus": (code), "irisId": (id), "irisCode": (irisCode), "iris": (texts)})
}

ClassMethod Flatten(errors As %DynamicArray, texts As %DynamicArray)
{
	set it = errors.%GetIterator()
	while it.%GetNext(.i, .e) {
		continue:'$isobject(e)
		do:e.%IsDefined("error") texts.%Push(e.error)
		do:e.%IsDefined("errors") ..Flatten(e.errors, texts)
	}
}

ClassMethod NoteTruncation(data As %DynamicAbstractObject, query As %DynamicObject, out As %DynamicObject)
{
	quit:'data.%IsA("%Library.DynamicArray")
	set cap = +$select(query.%IsDefined("maxRows"): query.maxRows, 1: ..#DefaultMaxRows)
	quit:cap'>0
	quit:data.%Size()'=cap
	set out.truncated = 1
	do out.warnings.%Push("exactly "_cap_" rows came back and the API gives no truncation flag - raise maxRows to see whether there are more")
}

ClassMethod QueryString(query As %DynamicObject) As %String
{
	set qs = "", it = query.%GetIterator()
	while it.%GetNext(.k, .v, .t) {
		if t = "boolean" {
			set v = $select(v: "true", 1: "false")
		} else {
			continue:v=""
		}
		set qs = qs_$select(qs = "": "?", 1: "&")_$zconvert(k, "O", "URL")_"="_$zconvert(v, "O", "URL")
	}
	return qs
}

ClassMethod Body(rsp As %Net.HttpResponse) As %DynamicAbstractObject
{
	return:'$isobject(rsp.Data) ""
	return:rsp.Data.Size=0 ""
	try {
		do rsp.Data.Rewind()
		set json = ##class(%DynamicAbstractObject).%FromJSON(rsp.Data)
	} catch {
		set json = ""
	}
	return json
}

ClassMethod Cred(env As %String, default As %String) As %String
{
	set v = $system.Util.GetEnviron(env)
	return:v'="" v
	do:default="" ##class(App.Err).Throw("internal", env_" is not set - the portal has no credentials for /api/admin")
	return default
}

}
