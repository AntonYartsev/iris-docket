/// generated, dont edit by hand
Class App.Tools.Admin.TaskGet Extends App.Tools.AdminBase
{

Parameter ToolName = "task.get";

Parameter Title = "View a task";

Parameter Category = "task";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/task";

Parameter QueryArgs = "id";

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "id": {
        "type": "integer",
        "title": "Id of a Task"
      }
    },
    "required": [
      "id"
    ]
  }
}

}
