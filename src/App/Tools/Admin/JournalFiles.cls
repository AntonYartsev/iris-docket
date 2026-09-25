/// generated, dont edit by hand
Class App.Tools.Admin.JournalFiles Extends App.Tools.AdminBase
{

Parameter ToolName = "journal.files";

Parameter Title = "List journal files";

Parameter Category = "journal";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/journal/files";

Parameter QueryArgs = "mirror,maxRows";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "mirror": {
        "type": "string",
        "title": "If present, will look for journal files associated with this mirror"
      },
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
