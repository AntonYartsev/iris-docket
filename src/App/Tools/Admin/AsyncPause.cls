/// generated, dont edit by hand
Class App.Tools.Admin.AsyncPause Extends App.Tools.AdminBase
{

Parameter ToolName = "async.pause";

Parameter Title = "Pause an async task";

Parameter Category = "async";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/async-result/pause";

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
