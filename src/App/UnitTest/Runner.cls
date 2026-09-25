Class App.UnitTest.Runner [ Abstract ]
{

ClassMethod All() As %Status
{
	// manager wants a dir anyway..
	set ^UnitTestRoot = $system.Util.ManagerDirectory()

	set classes = 0, methods = 0, failed = 0, names = ""
	set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinitionQuery:SubclassOf")
	do rs.Execute("App.UnitTest.Base")
	while rs.Next() {
		set cls = rs.Get("Name")
		continue:'##class(%Dictionary.CompiledClass).%ExistsId(cls)
		set classes = classes + 1
		do ##class(%UnitTest.Manager).DebugRunTestCase(, cls, "/noload/nodelete")
		set idx = $get(^UnitTest.Result), m = ""
		for {
			set m = $order(^UnitTest.Result(idx, "(root)", cls, m))
			quit:m=""
			set methods = methods + 1
			continue:$listget(^UnitTest.Result(idx, "(root)", cls, m), 1)
			set failed = failed + 1
			set names = names_$select(names="": "", 1: ", ")_$piece(cls, ".", 3)_"."_m
		}
	}
	do rs.Close()

	write !, "---", !
	write classes, " test classes, ", methods, " test methods, ", failed, " failed", !
	write:failed "failed: ", names, !
	if 'methods {
		write "UNIT TESTS: FAILED - nothing ran. Are the classes compiled?", !
		return $$$ERROR($$$GeneralError, "no test methods ran")
	}
	write "UNIT TESTS: ", $select(failed: "FAILED", 1: "PASSED"), !
	return $select(failed: $$$ERROR($$$GeneralError, failed_" failed: "_names), 1: $$$OK)
}

}
