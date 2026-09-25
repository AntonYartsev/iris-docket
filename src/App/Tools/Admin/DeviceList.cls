/// generated, dont edit by hand
Class App.Tools.Admin.DeviceList Extends App.Tools.AdminBase
{

Parameter ToolName = "device.list";

Parameter Title = "List devices";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/devices";

Parameter QueryArgs = "names,maxRows";

Parameter Privilege = "%Admin_Manage:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "names": {
        "type": "string",
        "title": "Comma separated list of Device names<br>\"* \" - All records match<br>\"String,String1\" - Any records matching one of these"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
