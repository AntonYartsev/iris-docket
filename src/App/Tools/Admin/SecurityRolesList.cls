/// generated, dont edit by hand
Class App.Tools.Admin.SecurityRolesList Extends App.Tools.AdminBase
{

Parameter ToolName = "security.roles.list";

Parameter Title = "List roles";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/roles";

Parameter QueryArgs = "filter,maxRows";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "filter": {
        "type": "string",
        "title": "Return rows containing this filter string"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
