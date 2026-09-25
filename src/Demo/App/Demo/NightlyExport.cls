Include %occStatus

Class App.Demo.NightlyExport Extends %SYS.Task.Definition
{

Property Destination As %String(MAXLEN = 256) [ InitialExpression = "/mnt/exports/docket" ];

Method OnTask() As %Status
{
	return:##class(%File).DirectoryExists(..Destination) $$$OK
	return $$$ERROR($$$GeneralError, "nightly export: "_..Destination_" is not mounted, nothing was written")
}

}
