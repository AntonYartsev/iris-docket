Class App.Tools.Rest.Probe Extends App.Tools.Rest.Base
{

Parameter ToolName = "rest.probe";

Parameter Title = "Call an endpoint of a REST application and show the response";

Parameter Mutating = 0;

Parameter MaxBody = 4000;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["name", "path"],
  "properties": {
    "name": { "type": "string", "title": "Application", "example": "/api/monitor" },
    "path": { "type": "string", "title": "Path inside the application", "example": "/alerts" },
    "method": { "type": "string", "title": "Method", "enum": ["GET", "HEAD", "OPTIONS"] }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set app = ..Find(args.name)
	set path = args.path
	set:$extract(path)'="/" path = "/"_path
	do:path[".." ##class(App.Err).Throw("bad_request", "the path may not walk out of the application with ..")
	set method = $select(args.%Get("method") = "": "GET", 1: args.method)

	set t0 = $zhorolog
	set data = ..Send(method, app.name_path, .code, .contentType)
	set ms = (($zhorolog - t0) * 1000) \ 1

	set body = ""
	if $isobject(data) {
		do data.Rewind()
		set body = data.Read(..#MaxBody)
	}
	set out = {"url": (app.name_path), "method": (method), "status": (+code), "durationMs": (ms), "contentType": (contentType), "body": (body)}
	do out.%Set("truncated", $isobject(data) && (data.Size > ..#MaxBody), "boolean")
	return {"data": (out)}
}

}
