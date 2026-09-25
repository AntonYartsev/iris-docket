Class App.UnitTest.Base Extends %UnitTest.TestCase [ Abstract ]
{

ClassMethod Mark() As %DynamicObject
{
	lock +^App.Audit("chain"):10
	return {"chain": ($get(^App.Audit("chain"))), "seq": (+$get(^App.Audit("seq")))}
}

ClassMethod Rewind(mark As %DynamicObject)
{
	set rs = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM App_Audit.Entry WHERE Seq > ?", +mark.seq)
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("internal", "the test could not unwind the journal: "_rs.%Message)
	set ^App.Audit("chain") = mark.chain
	set ^App.Audit("seq") = +mark.seq
	lock -^App.Audit("chain")
}

}
