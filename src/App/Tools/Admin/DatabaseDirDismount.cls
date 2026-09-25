/// generated, dont edit by hand
Class App.Tools.Admin.DatabaseDirDismount Extends App.Tools.AdminBase
{

Parameter ToolName = "databaseDir.dismount";

Parameter Title = "Dismount a local database";

Parameter Category = "os";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/database-dir/dismount";

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
