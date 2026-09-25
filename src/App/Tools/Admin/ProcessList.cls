/// generated, dont edit by hand
Class App.Tools.Admin.ProcessList Extends App.Tools.AdminBase
{

Parameter ToolName = "process.list";

Parameter Title = "List processes";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/processes";

Parameter QueryArgs = "filter,maxRows";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "filter": {
        "type": "string",
        "title": "Display processes which contain this filter in the line, \"\" means display all. For example, if filter = \"READ\", this wil"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
