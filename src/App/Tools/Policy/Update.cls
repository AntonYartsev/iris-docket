Class App.Tools.Policy.Update Extends App.Tools.Base
{

Parameter ToolName = "policy.update";

Parameter Title = "Replace the policy with a new version";

Parameter Category = "policy";

Parameter Mutating = 1;

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "config": {
      "type": "object",
      "title": "The whole policy document: default, rules and redact. Saved as the next version."
    }
  },
  "required": ["config"]
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (##class(App.Policy.Engine).Save(args.config, "user:"_$username))}
}

}
