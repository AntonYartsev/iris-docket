/// generated, dont edit by hand
Class App.Tools.Admin.SecretsOauth2List Extends App.Tools.AdminBase
{

Parameter ToolName = "secrets.oauth2.list";

Parameter Title = "List OAuth2 client configurations";

Parameter Category = "secrets";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/oauth2/client/client-configurations";

Parameter QueryArgs = "serverId,maxRows";

Parameter Privilege = "%Admin_OAuth2_Client:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "serverId": {
        "type": "string"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    },
    "required": [
      "serverId"
    ]
  }
}

}
