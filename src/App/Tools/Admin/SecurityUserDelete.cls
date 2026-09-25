/// generated, dont edit by hand
Class App.Tools.Admin.SecurityUserDelete Extends App.Tools.AdminBase
{

Parameter ToolName = "security.user.delete";

Parameter Title = "Delete a user";

Parameter Category = "security";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "DELETE";

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
