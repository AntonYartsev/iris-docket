Class App.Tools.Rest.Base Extends App.Tools.Base [ Abstract ]
{

Parameter Category = "rest";

Parameter Source = "manual";

Parameter Privilege = "%DB_IRISSYS:R";

ClassMethod Send(method As %String, url As %String, Output code As %Integer, Output contentType As %String, anonymous As %Boolean = 0) As %Stream.Object
{
	set req = ##class(%Net.HttpRequest).%New()
	set req.Server = "127.0.0.1"
	set req.Port = $get(^%SYS("WebServer","Port"), 52773)
	if 'anonymous {
		set req.Username = ##class(App.Admin.Client).Cred("IRIS_ADMIN_USER", "_SYSTEM")
		set req.Password = ##class(App.Admin.Client).Cred("IRIS_ADMIN_PASSWORD", "")
	}
	set req.Timeout = 30
	set sc = req.Send(method, url)
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("internal", "cannot reach "_url_" on this instance: "_$system.Status.GetErrorText(sc))
	set code = req.HttpResponse.StatusCode
	set contentType = req.HttpResponse.ContentType
	return req.HttpResponse.Data
}

ClassMethod Discover() As %DynamicArray
{
	set data = ..Send("GET", "/api/mgmnt/", .code)
	do:code'=200 ##class(App.Err).Throw("tool_error", "/api/mgmnt answered "_code_" - REST discovery is not available on this instance")
	do data.Rewind()
	return ##class(%DynamicAbstractObject).%FromJSON(data)
}

/// never take url from caller
ClassMethod Find(name As %String) As %DynamicObject
{
	set it = ..Discover().%GetIterator()
	while it.%GetNext(.i, .app) {
		return:app.name=name app
	}
	do ##class(App.Err).Throw("not_found", "this instance has no REST application "_name_" - rest.services lists them")
}

ClassMethod SpecKind(app As %DynamicObject) As %String
{
	set url = app.%Get("swaggerSpec")
	return:url="" "none"
	return $select(url [ "/api/mgmnt/v2/": "spec-first", 1: "synthesized")
}

}
