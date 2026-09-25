/// generated, dont edit by hand
Class App.Tools.Admin.AsyncGet Extends App.Tools.AdminBase
{

Parameter ToolName = "async.get";

Parameter Title = "View an async task";

Parameter Category = "async";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/async-result";

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
