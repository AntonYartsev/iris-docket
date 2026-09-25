/// generated, dont edit by hand
Class App.Tools.Admin.TaskRun Extends App.Tools.AdminBase
{

Parameter ToolName = "task.run";

Parameter Title = "Run a task now";

Parameter Category = "task";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/task/run";

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
      },
      "RunNow": {
        "description": "If true, the Datetime field will be ignored. Required.",
        "type": "boolean"
      },
      "Datetime": {
        "description": "The date and time on which to run the task, in YYYY-MM-DD HH:MM:SS format",
        "type": "string",
        "example": "2026-12-31 23:59:59"
      }
    },
    "required": [
      "id"
    ]
  }
}

}
