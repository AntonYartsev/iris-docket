/// generated, dont edit by hand
Class App.Tools.Admin.MonitorSystemUsage Extends App.Tools.AdminBase
{

Parameter ToolName = "monitor.systemUsage";

Parameter Title = "System usage counters";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/monitor/system-usage";

Parameter QueryArgs = "";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {}
  }
}

}
