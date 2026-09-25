Class App.Tools.Base [ Abstract ]
{

Parameter ToolName;

Parameter Title;

Parameter Category;

Parameter Mutating = 0;

Parameter Source = "manual";

Parameter Privilege = "";

Parameter Requires = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject [ Abstract ]
{
}

}
