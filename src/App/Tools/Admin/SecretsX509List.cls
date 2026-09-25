/// generated, dont edit by hand
Class App.Tools.Admin.SecretsX509List Extends App.Tools.AdminBase
{

Parameter ToolName = "secrets.x509.list";

Parameter Title = "List X.509 credentials";

Parameter Category = "secrets";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/x509-credentials";

Parameter QueryArgs = "maxRows";

Parameter Privilege = "%Admin_Secure:U";

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
