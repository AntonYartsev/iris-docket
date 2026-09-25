Class App.Tools.Ens.Base Extends App.Tools.Base [ Abstract ]
{

Parameter Category = "interop";

ClassMethod Namespaces() As %DynamicArray
{
	set out = []
	do ##class(%SYS.Namespace).ListAll(.list)
	set ns = ""
	for {
		set ns = $order(list(ns))
		quit:ns=""
		continue:'##class(%Library.EnsembleMgr).IsEnsembleNamespace(ns)
		do out.%Push(ns)
	}
	return out
}

ClassMethod Namespace(args As %DynamicObject) As %String
{
	set ns = $zconvert(args.%Get("namespace"), "U")
	do:ns="" ##class(App.Err).Throw("bad_request", "namespace is required - ens.productions lists the ones this instance has")
	do:'##class(%SYS.Namespace).Exists(ns) ##class(App.Err).Throw("not_found", "no namespace "_ns_" on this instance")
	do:'##class(%Library.EnsembleMgr).IsEnsembleNamespace(ns) ##class(App.Err).Throw("bad_request", ns_" exists but has no interoperability in it")
	return ns
}

ClassMethod Explain(err As %String, ns As %String) As %String
{
	return:err["<PROTECT>" "this account cannot read the database of "_ns_", so its interoperability is out of reach"
	return err
}

ClassMethod Rows(args As %DynamicObject, default As %Integer, max As %Integer) As %Integer
{
	set n = +args.%Get("maxRows")
	set:n'>0 n = default
	return $select(n>max: max, 1: n)
}

}
