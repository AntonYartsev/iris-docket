/// generated, dont edit by hand
Class App.Tools.Admin.JournalSettings Extends App.Tools.AdminBase
{

Parameter ToolName = "journal.settings";

Parameter Title = "Journal settings";

Parameter Category = "journal";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/journal/settings";

Parameter QueryArgs = "";

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {}
  }
}

}
