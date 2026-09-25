/// generated, dont edit by hand
Class App.Tools.Admin.TaskSuspend Extends App.Tools.AdminBase
{

Parameter ToolName = "task.suspend";

Parameter Title = "Suspend a task";

Parameter Category = "task";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/task/suspend";

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
      "LeaveInQueue": {
        "description": "True by default. If true, this will suspend the task but leave it in the task queue. If false, this will suspend the task, remove it from the queue, and reschedule it for next time.",
        "type": "boolean"
      }
    },
    "required": [
      "id"
    ]
  }
}

}
