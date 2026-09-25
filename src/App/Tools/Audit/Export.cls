Class App.Tools.Audit.Export Extends App.Tools.Base
{

Parameter ToolName = "audit.export";

Parameter Title = "The whole journal with its digests, for checking elsewhere";

Parameter Category = "audit";

Parameter Mutating = 0;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (##class(App.Audit.Entry).Export())}
}

}
