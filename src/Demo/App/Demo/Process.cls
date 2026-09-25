Class App.Demo.Process Extends Ens.BusinessProcess
{

Method OnRequest(request As EnsLib.HL7.Message, Output response As Ens.StringResponse) As %Status
{
	set target = $select($extract(request.Name, 1, 3) = "ORU": "Lab Archive", 1: "Chart")
	return ..SendRequestSync(target, request, .response)
}

}
