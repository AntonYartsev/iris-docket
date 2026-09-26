Class App.Tools.Packages.Installed Extends App.Tools.Base
{

Parameter ToolName = "packages.installed";

Parameter Title = "Packages IPM has installed, in every namespace that has any";

Parameter Category = "packages";

Parameter Mutating = 0;

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set modules = [], warnings = [], unreadable = [], blocked = {}, ipm = 0
	do ##class(%SYS.Namespace).ListAll(.list)
	set ns = ""
	for {
		set ns = $order(list(ns))
		quit:ns=""
		set:..Read(ns, modules, .err) ipm = 1
		if ##class(App.Tools.Packages.Change).HasIpm(ns) {
			set why = ##class(App.Tools.Packages.Change).Unwritable(ns)
			do:why'="" blocked.%Set(ns, why)
		}
		if err = "<PROTECT>" {
			do unreadable.%Push(ns)
		} elseif err '= "" {
			do warnings.%Push(ns_": "_err)
		}
	}
	do:'ipm warnings.%Push("no namespace on this instance has %IPM.Storage.Module in it - nothing here was installed by a package manager")

	set out = {"data": {"modules": (modules), "unreadable": (unreadable), "blocked": (blocked)}, "warnings": (warnings)}
	do out.data.%Set("ipm", ''ipm, "boolean")
	return out
}

/// only % classes past switch
ClassMethod Read(ns As %String, modules As %DynamicArray, Output err As %String) As %Boolean
{
	set err = "", found = 0
	try {
		new $namespace
		set $namespace = ns
		if ##class(%Dictionary.CompiledClass).%ExistsId("%IPM.Storage.Module") {
			set found = 1
			set rs = ##class(%ResultSet).%New("%IPM.Storage.Module:Extent")
			set sc = rs.Execute()
			if $system.Status.IsError(sc) {
				set err = $system.Status.GetErrorText(sc)
			} else {
				while rs.Next() {
					set m = ##class(%IPM.Storage.Module).%OpenId(rs.Get("ID"))
					continue:'$isobject(m)
					set one = {
						"name": (m.Name),
						"namespace": (ns),
						"version": (m.VersionString),
						"description": (m.Description),
						"repository": (m.Repository),
						"root": (m.Root),
						"installedAt": (m.LastModifiedTimestamp),
						"dependencies": []
					}
					for i = 1:1:m.Dependencies.Count() {
						set dep = m.Dependencies.GetAt(i)
						do one.dependencies.%Push({"name": (dep.Name), "version": (dep.VersionString)})
					}
					do modules.%Push(one)
				}
				do rs.Close()
			}
		}
	} catch e {
		set err = $select(e.Name = "<PROTECT>": "<PROTECT>", 1: e.DisplayString())
	}
	return found
}

}
