Class App.Tools.Packages.Jobs Extends App.Tools.Base
{

Parameter ToolName = "packages.jobs";

Parameter Title = "Package installs this portal has started, with their logs";

Parameter Category = "packages";

Parameter Mutating = 0;

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (##class(App.Tools.Packages.Change).List()), "warnings": []}
}

}
