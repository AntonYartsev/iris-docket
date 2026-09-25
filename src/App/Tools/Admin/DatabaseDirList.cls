/// generated, dont edit by hand
Class App.Tools.Admin.DatabaseDirList Extends App.Tools.AdminBase
{

Parameter ToolName = "databaseDir.list";

Parameter Title = "List local database directories";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "GET";

Parameter HttpPath = "/v2/database-dirs";

Parameter QueryArgs = "maxRows";

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "maxRows": {
        "type": "number",
        "title": "Max number of rows to return. Default value is 1000"
      }
    }
  }
}

}
