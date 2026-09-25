/// generated, dont edit by hand
Class App.Tools.Admin.DatabaseDirMount Extends App.Tools.AdminBase
{

Parameter ToolName = "databaseDir.mount";

Parameter Title = "Mount a local database";

Parameter Category = "os";

Parameter Mutating = 1;

Parameter Source = "spec";

Parameter HttpMethod = "POST";

Parameter HttpPath = "/v2/database-dir/mount";

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
      },
      "ReadOnly": {
        "description": "Defaults to false (not readonly). When True causes the database which would normally be mounted read-write to be mounted read-only. Normally a database is only mounted read-only if is not writeable (due to protection or filesystem issues) or if the internal database read-only property is set.",
        "type": "boolean"
      },
      "Cluster": {
        "description": "Defaults to 0 (private mount). This is ignored on non-cluster members. On a cluster member setting this to 1 causes the database to be mounted for clustered (shared) access. If the system is not a cluster member, this will cause the system to try to join the cluster.",
        "type": "boolean"
      },
      "MirrorCatchup": {
        "description": "Defaults to 1 (start catchup). This parameter is ignored if the system is not a mirror member or if the database being mounted is not a mirrored database. When set to 1 database catchup is started when a mirrored database is successfully mounted",
        "type": "boolean"
      }
    },
    "required": [
      "dir"
    ]
  }
}

}
