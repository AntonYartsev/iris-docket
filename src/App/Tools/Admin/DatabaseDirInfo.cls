/// generated, dont edit by hand
Class App.Tools.Admin.DatabaseDirInfo Extends App.Tools.AdminBase
{

Parameter ToolName = "databaseDir.info";

Parameter Title = "Block size, free space and the rest of what is not configurable (async)";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/database-dir/info";

Parameter QueryArgs = "dir";

Parameter Privilege = "%Admin_Operate:U";

XData Schema [ MimeType = application/json ]
{
  {
    "type": "object",
    "properties": {
      "dir": {
        "type": "string",
        "title": "Directory of the database"
      }
    },
    "required": [
      "dir"
    ]
  }
}

}
