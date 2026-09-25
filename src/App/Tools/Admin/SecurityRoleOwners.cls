/// generated, dont edit by hand
Class App.Tools.Admin.SecurityRoleOwners Extends App.Tools.AdminBase
{

Parameter ToolName = "security.role.owners";

Parameter Title = "Who holds a role, directly or as an escalation role";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/role/owners";

Parameter QueryArgs = "name,maxRows";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "title": "Name of a Role"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    },
    "required": [
      "name"
    ]
  }
}

}
