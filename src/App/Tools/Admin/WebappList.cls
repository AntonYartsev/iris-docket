/// generated, dont edit by hand
Class App.Tools.Admin.WebappList Extends App.Tools.AdminBase
{

Parameter ToolName = "webapp.list";

Parameter Title = "List web applications";

Parameter Category = "web-app";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/web-apps";

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
