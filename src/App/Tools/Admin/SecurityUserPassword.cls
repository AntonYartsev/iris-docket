/// generated, dont edit by hand
Class App.Tools.Admin.SecurityUserPassword Extends App.Tools.AdminBase
{

Parameter ToolName = "security.user.password";

Parameter Title = "Change a user's password";

Parameter Category = "security";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/security/user/password";

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
      },
      "NewPassword": {
        "description": "Required.",
        "type": "string"
      }
    },
    "required": [
      "name"
    ]
  }
}

}
