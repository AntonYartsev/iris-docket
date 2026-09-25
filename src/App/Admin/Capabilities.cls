Class App.Admin.Capabilities [ Abstract ]
{

Parameter SpecUrl = "/api/mgmnt/v1/%25SYS/spec/api/admin";

ClassMethod Probe(refresh As %Boolean = 0) As %DynamicObject
{
	set why = $select(refresh: "on request", 1: ..Stale())
	set:((why = "") && $get(^App.Admin("caps", "failed"))) why = "the last check failed"
	if why '= "" {
		kill ^App.Admin("caps")
		set out = {"ts": ($zdatetime($ztimestamp, 3, 1)), "source": (..#SpecUrl), "why": (why)}
		do out.%Set("paths", 0, "number"), out.%Set("v1", 0, "number"), out.%Set("v2", 0, "number")
		try {
			set info = ##class(App.Admin.Client).Info(1)
			set out.serverVersion = info.%Get("serverVersion")
			set out.version = ..Version(out.serverVersion)
			set out.product = info.%Get("product")
			do out.%Set("apiVersion", +info.%Get("apiVersion"), "number")
			do ..Paths(out)
		} catch ex {
			kill ^App.Admin("caps", "path")
			set out.error = $select(ex.%IsA("App.Err"): ex.Data, 1: ex.DisplayString())
			set ^App.Admin("caps", "failed") = 1
		}
		set ^App.Admin("caps") = out.%ToJSON(), ^App.Admin("caps", "build") = $zversion
	}
	return ##class(%DynamicAbstractObject).%FromJSON(^App.Admin("caps"))
}

ClassMethod Stale() As %String
{
	return:'$data(^App.Admin("caps", "build")) "first use"
	return:(^App.Admin("caps", "build") '= $zversion) "the build changed"
	return ""
}

ClassMethod Paths(out As %DynamicObject)
{
	set data = ##class(App.Tools.Rest.Base).Send("GET", ..#SpecUrl, .code)
	do:code'=200 ##class(App.Err).Throw("tool_error", ..#SpecUrl_" answered "_code_" - this instance will not say which operations it serves")
	do data.Rewind()
	set spec = ##class(%DynamicAbstractObject).%FromJSON(data)
	do:'$isobject(spec.%Get("paths")) ##class(App.Err).Throw("tool_error", "the specification this instance published has no paths in it")
	set it = spec.paths.%GetIterator()
	while it.%GetNext(.path, .ops) {
		set methods = ""
		if $isobject(ops) {
			set jt = ops.%GetIterator()
			while jt.%GetNext(.method) {
				set methods = methods_","_$zconvert(method, "U")
			}
		}
		set ^App.Admin("caps", "path", path) = methods_","
		do out.%Set("paths", out.paths + 1, "number")
		set family = $piece(path, "/", 2)
		do:family="v1" out.%Set("v1", out.v1 + 1, "number")
		do:family="v2" out.%Set("v2", out.v2 + 1, "number")
	}
}

ClassMethod Serves(method As %String, path As %String) As %Boolean
{
	return:'$data(^App.Admin("caps", "path")) 1
	return $get(^App.Admin("caps", "path", path)) [ (","_$zconvert(method, "U")_",")
}

ClassMethod Missing(meta As %DynamicObject) As %DynamicArray
{
	set out = [], requires = meta.%Get("requires")
	return:requires="" out
	do:..Stale()'="" ..Probe()
	for i = 1:1:$length(requires, ",") {
		set one = $zstrip($piece(requires, ",", i), "<>W")
		continue:one=""
		continue:..Serves($piece(one, " ", 1), $piece(one, " ", 2))
		do out.%Push(one)
	}
	return out
}

ClassMethod Available(meta As %DynamicObject) As %Boolean
{
	return ..Missing(meta).%Size() = 0
}

ClassMethod Mark(meta As %DynamicObject)
{
	set missing = ..Missing(meta)
	do meta.%Set("available", missing.%Size() = 0, "boolean")
	quit:missing.%Size()=0
	set here = ##class(%DynamicAbstractObject).%FromJSON(^App.Admin("caps"))
	set names = "", it = missing.%GetIterator()
	while it.%GetNext(, .one) {
		set names = names_$select(names = "": "", 1: ", ")_one
	}
	set meta.unavailable = {"version": (here.%Get("version")), "missing": (missing)}
	set meta.unavailable.reason = "this instance is "_here.%Get("version")_" and its /api/admin does not serve "_names
}

ClassMethod Version(serverVersion As %String) As %String
{
	set v = $piece($piece(serverVersion, ") ", 2), " ", 1)
	return $select($length(v, ".") = 2: v, 1: serverVersion)
}

}
