/// generated, dont edit by hand
Class App.Tools.Admin.SecretsX509Certificate Extends App.Tools.AdminBase
{

Parameter ToolName = "secrets.x509.certificate";

Parameter Title = "View the certificate of an X.509 credential: subject, issuer, validity";

Parameter Category = "secrets";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/x509-credential/certificate";

Parameter QueryArgs = "alias";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "alias": {
        "type": "string",
        "title": "Alias of an X509 Credential"
      }
    },
    "required": [
      "alias"
    ]
  }
}

}
