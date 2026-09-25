Class App.Tools.Os.Sampler Extends %SYS.Task.Definition
{

Parameter TaskName = "Docket metrics";

Method OnTask() As %Status
{
	try {
		for i = 1:1:10 {
			do ##class(App.Tools.Os.History).Sample()
			quit:i=10
			// sleep untill next minute
			hang 60 - ($piece($horolog, ",", 2) # 60)
		}
	} catch ex {
		return ex.AsStatus()
	}
	return $$$OK
}

}
