/// generated, dont edit by hand
Class App.Tools.Admin.WebappGet Extends App.Tools.AdminBase
{

Parameter ToolName = "webapp.get";

Parameter Title = "View a web application";

Parameter Category = "web-app";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/web-app";

Parameter QueryArgs = "name";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "title": "Web app name"
      }
    },
    "required": [
      "name"
    ]
  }
}

}
