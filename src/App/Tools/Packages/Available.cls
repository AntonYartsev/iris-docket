Class App.Tools.Packages.Available Extends App.Tools.Base
{

Parameter ToolName = "packages.available";

Parameter Title = "Packages the community registry publishes";

Parameter Category = "packages";

Parameter Mutating = 0;

Parameter Privilege = "";

/// fixed host, no SSRF
Parameter Registry = "pm.community.intersystems.com";

Parameter Path = "/packages/-/all";

Parameter Timeout = 20;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set req = ##class(%Net.HttpRequest).%New()
	set req.Server = ..#Registry
	set req.Port = 443
	set req.Https = 1
	set req.SSLConfiguration = ##class(App.Setup).#SSLConfig
	set req.Timeout = ..#Timeout

	set sc = req.Get(..#Path)
	do:$system.Status.IsError(sc) ..Unreachable("could not be reached", $system.Status.GetErrorText(sc))
	do:req.HttpResponse.StatusCode'=200 ..Unreachable("refused the request", "HTTP "_req.HttpResponse.StatusCode)

	// raw bytes, its utf8
	set body = "", data = req.HttpResponse.Data
	do data.Rewind()
	while 'data.AtEnd {
		set body = body_data.Read(32000)
	}
	try { set body = $zconvert(body, "I", "UTF8") } catch { }

	try {
		set list = ##class(%DynamicAbstractObject).%FromJSON(body)
	} catch parse {
		do ..Unreachable("answered with something that is not the package list it publishes", parse.DisplayString())
	}

	set out = {"data": [], "warnings": []}
	set it = list.%GetIterator()
	while it.%GetNext(, .p) {
		set versions = p.%Get("versions")
		do out.data.%Push({
			"name": (p.%Get("name")),
			"version": ($select($isobject(versions) && versions.%Size(): versions.%Get(versions.%Size() - 1), 1: "")),
			"description": (p.%Get("description")),
			"repository": (p.%Get("repository"))
		})
	}
	return out
}

ClassMethod Unreachable(why As %String, cause As %String)
{
	do ##class(App.Err).Throw("unreachable", "the package registry at "_..#Registry_" "_why_". Nothing on this instance failed: an IRIS with no route out of its network cannot be told what the registry publishes, only what is already installed here.", {"registry": (..#Registry), "cause": (cause)})
}

}
