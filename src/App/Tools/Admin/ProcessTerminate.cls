/// generated, dont edit by hand
Class App.Tools.Admin.ProcessTerminate Extends App.Tools.AdminBase
{

Parameter ToolName = "process.terminate";

Parameter Title = "Terminate a process";

Parameter Category = "os";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/process/terminate";

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
