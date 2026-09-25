/// generated, dont edit by hand
Class App.Tools.Admin.AsyncCancel Extends App.Tools.AdminBase
{

Parameter ToolName = "async.cancel";

Parameter Title = "Cancel an async task";

Parameter Category = "async";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/async-result/cancel";

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
