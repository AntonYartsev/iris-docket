Class App.Tools.Rest.Spec Extends App.Tools.Rest.Base
{

Parameter ToolName = "rest.spec";

Parameter Title = "The OpenAPI document of one REST application";

Parameter Mutating = 0;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["name"],
  "properties": {
    "name": { "type": "string", "title": "Application", "example": "/api/monitor" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set app = ..Find(args.name)
	set kind = ..SpecKind(app)
	do:kind="none" ##class(App.Err).Throw("not_found", args.name_" has no specification: it is served by a dispatch class without one")

	set data = ..Send("GET", app.swaggerSpec, .code)
	do:code'=200 ##class(App.Err).Throw("tool_error", "the instance answered "_code_" for the specification of "_args.name)
	do data.Rewind()
	set doc = ##class(%DynamicAbstractObject).%FromJSON(data)

	set info = doc.%Get("info")
	set out = {"name": (app.name), "namespace": (app.%Get("namespace")), "dispatchClass": (app.%Get("dispatchClass")), "specKind": (kind)}
	do out.%Set("enabled", ''app.%Get("enabled"), "boolean")
	set out.dialect = $select(doc.%IsDefined("openapi"): "OpenAPI "_doc.openapi, 1: "Swagger "_doc.%Get("swagger"))
	set out.basePath = doc.%Get("basePath")
	set out.title = $select($isobject(info): info.%Get("title"), 1: "")
	set out.description = $select($isobject(info): info.%Get("description"), 1: "")
	set out.version = $select($isobject(info): info.%Get("version"), 1: "")
	set out.operations = []

	set paths = doc.%Get("paths")
	return:'$isobject(paths) {"data": (out)}
	set pit = paths.%GetIterator()
	while pit.%GetNext(.path, .item) {
		continue:'$isobject(item)
		set oit = item.%GetIterator()
		while oit.%GetNext(.method, .op) {
			continue:'$listfind($listbuild("get","put","post","delete","patch","head","options"), $zconvert(method, "L"))
			continue:'$isobject(op)
			do out.operations.%Push(..Operation(doc, path, method, op))
		}
	}
	return {"data": (out)}
}

ClassMethod Operation(doc As %DynamicObject, path As %String, method As %String, op As %DynamicObject) As %DynamicObject
{
	set one = {"path": (path), "method": ($zconvert(method, "U"))}
	set one.summary = op.%Get("summary")
	set one.description = op.%Get("description")
	set one.operationId = op.%Get("operationId")
	set one.parameters = []
	set one.responses = []

	set params = op.%Get("parameters")
	if $isobject(params) {
		set it = params.%GetIterator()
		while it.%GetNext(.i, .p) {
			set p = ..Deref(doc, p)
			continue:'$isobject(p)
			set schema = p.%Get("schema")
			set one2 = {"name": (p.%Get("name")), "in": (p.%Get("in")), "description": (p.%Get("description"))}
			do one2.%Set("required", ''p.%Get("required"), "boolean")
			set one2.type = $select(p.%IsDefined("type"): p.type, $isobject(schema): schema.%Get("type"), 1: "")
			do one.parameters.%Push(one2)
		}
	}

	set responses = op.%Get("responses")
	if $isobject(responses) {
		set it = responses.%GetIterator()
		while it.%GetNext(.code, .r) {
			do one.responses.%Push({"code": (code), "description": ($select($isobject(r): r.%Get("description"), 1: ""))})
		}
	}
	return one
}

/// local refs only, no fetch
ClassMethod Deref(doc As %DynamicObject, node As %DynamicObject) As %DynamicObject
{
	return:'$isobject(node) node
	set ref = node.%Get("$ref")
	return:ref="" node
	return:$extract(ref, 1, 2)'="#/" {"name": (ref), "in": "", "type": "", "description": "unresolved reference"}
	set target = doc
	for i = 2:1:$length(ref, "/") {
		return:'$isobject(target) node
		set target = target.%Get($piece(ref, "/", i))
	}
	return $select($isobject(target): target, 1: node)
}

}
