/// generated, dont edit by hand
Class App.Tools.Admin.SecretsWalletCollections Extends App.Tools.AdminBase
{

Parameter ToolName = "secrets.wallet.collections";

Parameter Title = "List wallet collections";

Parameter Category = "secrets";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/wallet/collections";

Parameter QueryArgs = "names,maxRows";

Parameter Privilege = "%Admin_Wallet:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "names": {
        "type": "string",
        "title": "Comma separated list of collections to return (the default is \"* \" - all)"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
