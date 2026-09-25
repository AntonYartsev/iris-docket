/// generated, dont edit by hand
Class App.Tools.Admin.TaskResume Extends App.Tools.AdminBase
{

Parameter ToolName = "task.resume";

Parameter Title = "Resume a task";

Parameter Category = "task";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/task/resume";

Parameter QueryArgs = "id";

Parameter Privilege = "%Admin_Task:U";

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
