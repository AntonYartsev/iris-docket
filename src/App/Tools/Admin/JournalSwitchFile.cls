/// generated, dont edit by hand
Class App.Tools.Admin.JournalSwitchFile Extends App.Tools.AdminBase
{

Parameter ToolName = "journal.switchFile";

Parameter Title = "Switch the journal file";

Parameter Category = "journal";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/journal/switch-file";

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
