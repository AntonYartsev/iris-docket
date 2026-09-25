/// generated, dont edit by hand
Class App.Tools.Admin.SecurityRoleGet Extends App.Tools.AdminBase
{

Parameter ToolName = "security.role.get";

Parameter Title = "View a role";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/role";

Parameter QueryArgs = "name";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "title": "Name of a Role"
      }
    },
    "required": [
      "name"
    ]
  }
}

}
