Class App.Tools.Policy.Validate Extends App.Tools.Base
{

Parameter ToolName = "policy.validate";

Parameter Title = "Check a policy document without installing it";

Parameter Category = "policy";

Parameter Mutating = 0;

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "config": {
      "type": "object",
      "title": "The policy document to check: default, rules and redact."
    }
  },
  "required": ["config"]
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set out = {"ok": true, "problems": []}
	try {
		do ##class(App.Policy.Engine).Validate(args.config)
	} catch ex {
		set detail = $select(ex.%IsA("App.Err") && $isobject(ex.Detail): ex.Detail, 1: {})
		do out.%Set("ok", 0, "boolean")
		set out.problems = $select($isobject(detail.%Get("problems")): detail.problems, 1: [(ex.Data)])
	}
	return {"data": (out)}
}

}
