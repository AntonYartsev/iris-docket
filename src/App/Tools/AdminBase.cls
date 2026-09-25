Class App.Tools.AdminBase Extends App.Tools.Base [ Abstract ]
{

Parameter Source = "spec";

Parameter HttpMethod;

Parameter HttpPath;

Parameter QueryArgs;

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	// copy keeps json types
	set body = ##class(%DynamicAbstractObject).%FromJSON(args.%ToJSON())
	set query = {}
	for i = 1:1:$length(..#QueryArgs, ",") {
		set k = $piece(..#QueryArgs, ",", i)
		continue:k=""
		continue:'args.%IsDefined(k)
		do query.%Set(k, args.%Get(k), args.%GetTypeOf(k))
		do body.%Remove(k)
	}
	set:body.%Size()=0 body = ""
	return ##class(App.Admin.Client).Call(..#HttpMethod, ..#HttpPath, query, body)
}

}
