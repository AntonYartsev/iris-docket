/// generated, dont edit by hand
Class App.Tools.Admin.SecurityUsersList Extends App.Tools.AdminBase
{

Parameter ToolName = "security.users.list";

Parameter Title = "List users";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/users";

Parameter QueryArgs = "names,maxRows";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "names": {
        "type": "string",
        "title": "Comma separated list of user names, \"* \" = All"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
