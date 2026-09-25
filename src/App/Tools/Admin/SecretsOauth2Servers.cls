/// generated, dont edit by hand
Class App.Tools.Admin.SecretsOauth2Servers Extends App.Tools.AdminBase
{

Parameter ToolName = "secrets.oauth2.servers";

Parameter Title = "List OAuth2 authorization servers this instance uses as a client";

Parameter Category = "secrets";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/oauth2/client/server-definitions";

Parameter QueryArgs = "maxRows";

Parameter Privilege = "%Admin_OAuth2_Client:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
