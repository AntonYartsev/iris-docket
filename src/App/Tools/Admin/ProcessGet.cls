/// generated, dont edit by hand
Class App.Tools.Admin.ProcessGet Extends App.Tools.AdminBase
{

Parameter ToolName = "process.get";

Parameter Title = "View a process";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/process";

Parameter QueryArgs = "id";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "id": {
        "type": "integer",
        "title": "Process ID"
      }
    },
    "required": [
      "id"
    ]
  }
}

}
