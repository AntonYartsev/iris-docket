/// generated, dont edit by hand
Class App.Tools.Admin.MonitorDashboard Extends App.Tools.AdminBase
{

Parameter ToolName = "monitor.dashboard";

Parameter Title = "Dashboard stats: uptime, alerts, licence use, write daemon";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/monitor/dashboard/main";

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
