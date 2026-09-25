Class App.Demo.Operation Extends Ens.BusinessOperation
{

Parameter ADAPTER;

Parameter INVOCATION = "Queue";

Method Store(request As EnsLib.HL7.Message, Output response As Ens.StringResponse) As %Status
{
	set text = request.OutputToString()
	if $find(text, "MRN-UNKNOWN") {
		set ..Retry = 0
		return $$$ERROR($$$GeneralError, "patient MRN-UNKNOWN is not in the chart - message rejected")
	}
	$$$LOGINFO("filed "_request.Name_" under "_..%ConfigName)
	set response = ##class(Ens.StringResponse).%New("AA")
	return $$$OK
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="EnsLib.HL7.Message">
    <Method>Store</Method>
  </MapItem>
</MapItems>
}

}
