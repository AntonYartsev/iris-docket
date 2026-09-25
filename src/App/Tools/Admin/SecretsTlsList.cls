/// generated, dont edit by hand
Class App.Tools.Admin.SecretsTlsList Extends App.Tools.AdminBase
{

Parameter ToolName = "secrets.tls.list";

Parameter Title = "List TLS/SSL configurations";

Parameter Category = "secrets";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/ssl-configurations";

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
