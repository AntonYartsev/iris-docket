Class App.Tools.Audit.Verify Extends App.Tools.Base
{

Parameter ToolName = "audit.verifyChain";

Parameter Title = "Check the journal's hash chain against its own records";

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
	return {"data": (##class(App.Audit.Entry).VerifyChain())}
}

}
