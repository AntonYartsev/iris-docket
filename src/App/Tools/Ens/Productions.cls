Class App.Tools.Ens.Productions Extends App.Tools.Ens.Base
{

Parameter ToolName = "ens.productions";

Parameter Title = "Interoperability namespaces, their productions and which one is running";

Parameter Mutating = 0;

Parameter Privilege = "%Ens_ProductionRun:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set out = {"data": [], "warnings": []}
	set namespaces = ..Namespaces()
	do:namespaces.%Size()=0 out.warnings.%Push("no namespace on this instance has interoperability in it")

	set it = namespaces.%GetIterator()
	while it.%GetNext(, .ns) {
		set one = ..Read(ns, .err)
		set:err'="" one.error = ..Explain(err, ns)
		do out.data.%Push(one)
	}
	return out
}

ClassMethod Read(ns As %String, Output err As %String) As %DynamicObject
{
	set err = "", one = {"namespace": (ns), "running": "", "state": "", "productions": []}
	try {
		new $namespace
		set $namespace = ns

		set sc = ##class(Ens.Director).GetProductionStatus(.name, .state)
		if $system.Status.IsError(sc) {
			set err = $system.Status.GetErrorText(sc)
			return one
		}
		set one.running = name
		set one.state = $case(+state, 1: "Running", 2: "Stopped", 3: "Suspended", 4: "Troubled", : "Unknown")

		do ##class(Ens.Director).GetProductionSummary(.info)
		set p = ""
		for {
			set p = $order(info(p))
			quit:p=""
			do one.productions.%Push({
				"name": (p),
				"status": ($listget(info(p), 1)),
				"startedAt": ($listget(info(p), 2)),
				"stoppedAt": ($listget(info(p), 3))
			})
		}
	} catch e {
		set err = e.DisplayString()
	}
	return one
}

}
