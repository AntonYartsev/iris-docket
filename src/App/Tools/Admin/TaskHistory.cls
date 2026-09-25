/// generated, dont edit by hand
Class App.Tools.Admin.TaskHistory Extends App.Tools.AdminBase
{

Parameter ToolName = "task.history";

Parameter Title = "Task run history";

Parameter Category = "task";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/task/history";

Parameter QueryArgs = "taskId,filter,userOnly,maxRows";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "taskId": {
        "type": "integer",
        "title": "Only view the history for the task with this id"
      },
      "filter": {
        "type": "string",
        "title": "Return rows containing this filter string"
      },
      "userOnly": {
        "type": "integer",
        "title": "If 1, only include history for user-defined tasks"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
