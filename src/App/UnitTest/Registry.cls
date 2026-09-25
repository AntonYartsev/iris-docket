Class App.UnitTest.Registry Extends App.UnitTest.Base
{

ClassMethod BadSchema(schema As %String) As %String [ Language = python ]
{
    import json
    from jsonschema import Draft202012Validator
    try:
        Draft202012Validator.check_schema(json.loads(schema))
    except Exception as e:
        return str(e).splitlines()[0]
    return ""
}

Method TestRebuildIsStableAndNamesAreUnique()
{
	set declared = 0
	set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinitionQuery:SubclassOf")
	do rs.Execute("App.Tools.Base")
	while rs.Next() {
		set cls = rs.Get("Name")
		continue:'##class(%Dictionary.CompiledClass).%ExistsId(cls)
		continue:$parameter(cls, "ToolName")=""
		set declared = declared + 1
	}
	do rs.Close()

	set built = ##class(App.Tools.Registry).Build()
	do $$$AssertTrue(built > 0, "the registry has tools in it")
	do $$$AssertEquals(built, declared, "every class that declares a ToolName is in the registry - two classes sharing a name would lose one here")
	do $$$AssertEquals(##class(App.Tools.Registry).List().%Size(), built, "and the list agrees with the count")
}

Method TestEveryToolIsDeclaredProperly()
{
	set tools = ##class(App.Tools.Registry).List()
	set it = tools.%GetIterator()
	while it.%GetNext(.i, .t) {
		set name = t.name
		do $$$AssertTrue(##class(App.Policy.Engine).Glob("*.*", name), "'"_name_"' is a dotted name")
		do $$$AssertTrue(name'[" ", "'"_name_"' has no spaces in it - the agent names tools with underscores and maps them back")
		do $$$AssertNotEquals(t.title, "", "'"_name_"' has a title for the UI and the tool list")
		do $$$AssertNotEquals(t.category, "", "'"_name_"' belongs to a screen")
		do $$$AssertEquals(t.schema.type, "object", "'"_name_"' takes an object of arguments")
		do $$$AssertEquals(..BadSchema(t.schema.%ToJSON()), "", "'"_name_"' has a schema jsonschema can load")
	}
}

Method TestMutatingMatchesTheVerb()
{
	set it = ##class(App.Tools.Registry).List().%GetIterator()
	while it.%GetNext(.i, .t) {
		continue:t.source'="spec"
		if t.method = "GET" {
			do $$$AssertEquals(''t.mutating, 0, "'"_t.name_"' is a GET and does not write")
		} elseif (t.method = "PUT") || (t.method = "DELETE") {
			do $$$AssertEquals(''t.mutating, 1, "'"_t.name_"' is a "_t.method_" and writes")
		}
	}
}

}
