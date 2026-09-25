Class App.Tools.Packages.Uninstall Extends App.Tools.Packages.Change
{

Parameter ToolName = "packages.uninstall";

Parameter Title = "Uninstall a package from a namespace";

Parameter Verb = "uninstall";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["name", "namespace"],
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 64,
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]*$",
      "title": "Package name as it is installed here"
    },
    "namespace": {
      "type": "string",
      "maxLength": 64,
      "pattern": "^[A-Za-z%][A-Za-z0-9%]*$",
      "title": "Namespace to remove it from"
    }
  }
}
}

}
