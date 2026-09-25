Class App.Tools.Rest.Services Extends App.Tools.Rest.Base
{

Parameter ToolName = "rest.services";

Parameter Title = "REST services on this instance, with links to their specifications";

Parameter Mutating = 0;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "namespace": { "type": "string", "title": "Only this namespace" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set only = args.%Get("namespace")
	set out = []
	set it = ..Discover().%GetIterator()
	while it.%GetNext(.i, .app) {
		continue:(only'="")&&(app.%Get("namespace")'=only)
		set app.specKind = ..SpecKind(app)
		do out.%Push(app)
	}
	return {"data": (out)}
}

}
