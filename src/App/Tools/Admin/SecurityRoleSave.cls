/// generated, dont edit by hand
Class App.Tools.Admin.SecurityRoleSave Extends App.Tools.AdminBase
{

Parameter ToolName = "security.role.save";

Parameter Title = "Create or edit a role";

Parameter Category = "security";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "PUT";

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
      },
      "Description": {
        "description": "Description of the role.",
        "type": "string"
      },
      "GrantedRoles": {
        "description": "Roles assigned to the Role.",
        "type": "array",
        "items": {
          "type": "string"
        }
      },
      "EscalationOnly": {
        "description": "",
        "type": "boolean"
      },
      "Resources": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "Name": {
              "type": "string"
            },
            "Permissions": {
              "type": "string",
              "example": "RWU"
            }
          }
        }
      }
    },
    "required": [
      "name"
    ]
  }
}

}
