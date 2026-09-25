/// generated, dont edit by hand
Class App.Tools.Admin.AsyncList Extends App.Tools.AdminBase
{

Parameter ToolName = "async.list";

Parameter Title = "List my async tasks";

Parameter Category = "async";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/async-results";

Parameter QueryArgs = "start,end,maxRows";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "start": {
        "type": "string",
        "title": "Only include tasks queued after this date"
      },
      "end": {
        "type": "string",
        "title": "Only include tasks queued before this date"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
