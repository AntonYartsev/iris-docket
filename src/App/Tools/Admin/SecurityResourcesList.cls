/// generated, dont edit by hand
Class App.Tools.Admin.SecurityResourcesList Extends App.Tools.AdminBase
{

Parameter ToolName = "security.resources.list";

Parameter Title = "List resources";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/security/resources";

Parameter QueryArgs = "names,maxRows";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "names": {
        "type": "string",
        "title": "Comma separated list of resource names.<br>\"* \" - All records match.<br>\"String,String1\" - Any records matching one of t"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
