Class App.Tools.Registry [ Abstract ]
{

ClassMethod Build() As %Integer
{
	kill ^App.Tools
	set n = 0
	set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinitionQuery:SubclassOf")
	do rs.Execute("App.Tools.Base")
	while rs.Next() {
		set cls = rs.Get("Name")
		continue:'##class(%Dictionary.CompiledClass).%ExistsId(cls)
		set name = $parameter(cls, "ToolName")
		continue:name=""
		set ^App.Tools("class", name) = cls
		set ^App.Tools("meta", name) = ..Meta(cls, name).%ToJSON()
		set n = n + 1
	}
	do rs.Close()
	set ^App.Tools = n
	return n
}

ClassMethod Meta(cls As %String, name As %String) As %DynamicObject
{
	set m = {}
	set m.name = name
	set m.title = $parameter(cls, "Title")
	set m.category = $parameter(cls, "Category")
	do m.%Set("mutating", ''$parameter(cls, "Mutating"), "boolean")
	set m.source = $parameter(cls, "Source")
	set m.privilege = $parameter(cls, "Privilege")
	set m.method = $parameter(cls, "HttpMethod")
	set m.path = $parameter(cls, "HttpPath")
	set m.requires = $select($parameter(cls, "Requires") '= "": $parameter(cls, "Requires"), m.path '= "": m.method_" "_m.path, 1: "")
	set m.class = cls
	set m.schema = ..Schema(cls)
	return m
}

ClassMethod Schema(cls As %String) As %DynamicObject
{
	set x = ##class(%Dictionary.CompiledXData).%OpenId(cls_"||Schema")
	return:'$isobject(x) {}
	do x.Data.Rewind()
	return ##class(%DynamicAbstractObject).%FromJSON(x.Data)
}

ClassMethod Get(name As %String) As %DynamicObject
{
	do:'$data(^App.Tools) ..Build()
	return:'$data(^App.Tools("meta", name)) ""
	set m = ##class(%DynamicAbstractObject).%FromJSON(^App.Tools("meta", name))
	do ##class(App.Admin.Capabilities).Mark(m)
	return m
}

ClassMethod Class(name As %String) As %String
{
	do:'$data(^App.Tools) ..Build()
	return $get(^App.Tools("class", name))
}

ClassMethod List(category As %String = "") As %DynamicArray
{
	do:'$data(^App.Tools) ..Build()
	set out = [], name = ""
	for {
		set name = $order(^App.Tools("meta", name))
		quit:name=""
		set m = ##class(%DynamicAbstractObject).%FromJSON(^App.Tools("meta", name))
		continue:(category'="")&&(m.category'=category)
		do ##class(App.Admin.Capabilities).Mark(m)
		do out.%Push(m)
	}
	return out
}

}
