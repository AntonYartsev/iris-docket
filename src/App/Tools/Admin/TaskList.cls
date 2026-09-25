/// generated, dont edit by hand
Class App.Tools.Admin.TaskList Extends App.Tools.AdminBase
{

Parameter ToolName = "task.list";

Parameter Title = "List tasks";

Parameter Category = "task";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/tasks";

Parameter QueryArgs = "filter,onDemand,maxRows";

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "filter": {
        "type": "string",
        "title": "Return rows containing this filter string"
      },
      "onDemand": {
        "type": "integer",
        "title": "If 1, only show tasks which can be ran on demand"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
