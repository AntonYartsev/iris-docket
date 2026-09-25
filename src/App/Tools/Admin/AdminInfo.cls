/// generated, dont edit by hand
Class App.Tools.Admin.AdminInfo Extends App.Tools.AdminBase
{

Parameter ToolName = "admin.info";

Parameter Title = "Instance info and effective privileges of the current user";

Parameter Category = "general";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/info";

Parameter QueryArgs = "";

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {}
  }
}

}
