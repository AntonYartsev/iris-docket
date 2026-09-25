/// generated, dont edit by hand
Class App.Tools.Admin.AsyncResume Extends App.Tools.AdminBase
{

Parameter ToolName = "async.resume";

Parameter Title = "Resume an async task";

Parameter Category = "async";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/async-result/resume";

Parameter QueryArgs = "id";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "id": {
        "type": "string",
        "title": "GUID of an async task"
      }
    },
    "required": [
      "id"
    ]
  }
}

}
