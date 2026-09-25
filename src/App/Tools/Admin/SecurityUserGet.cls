/// generated, dont edit by hand
Class App.Tools.Admin.SecurityUserGet Extends App.Tools.AdminBase
{

Parameter ToolName = "security.user.get";

Parameter Title = "View a user";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/user";

Parameter QueryArgs = "name";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "title": "Name of a User"
      }
    },
    "required": [
      "name"
    ]
  }
}

}
