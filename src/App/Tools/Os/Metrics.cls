Class App.Tools.Os.Metrics Extends App.Tools.Base
{

Parameter ToolName = "monitor.metrics";

Parameter Title = "Host CPU, memory, disk and licence use, from /api/monitor/metrics";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "names": {
      "type": "string",
      "title": "Comma separated metric names, e.g. iris_cpu_usage,iris_phys_mem_percent_used. Empty returns all of them."
    }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (..Read(args.%Get("names")))}
}

ClassMethod Read(names As %String = "") As %DynamicArray
{
	set wanted = {}
	for i = 1:1:$length(names, ",") {
		set one = $zstrip($piece(names, ",", i), "<>W")
		do:one'="" wanted.%Set(one, "")
	}

	set data = ##class(App.Tools.Rest.Base).Send("GET", "/api/monitor/metrics", .code)
	do:code'=200 ##class(App.Err).Throw("tool_error", "/api/monitor/metrics answered "_code_" - this instance exposes no host metrics")

	set metrics = {}, order = []
	do data.Rewind()
	while 'data.AtEnd {
		set line = $zstrip(data.ReadLine(), "<>WC")
		continue:line=""
		if $extract(line) = "#" {
			set kind = $zconvert($piece(line, " ", 2), "L")
			continue:'$listfind($listbuild("help", "type", "unit"), kind)
			set name = $piece(line, " ", 3)
			continue:(wanted.%Size()>0)&&'wanted.%IsDefined(name)
			do ..Metric(metrics, order, name).%Set(kind, $piece(line, " ", 4, *))
			continue
		}
		set name = $piece($piece(line, "{"), " ")
		continue:(wanted.%Size()>0)&&'wanted.%IsDefined(name)
		set sample = {"labels": (..Labels(line))}
		set raw = $piece(line, " ", *)
		// NaN and +Inf stays strings
		set sample.value = $select($isvalidnum(raw): +raw, 1: raw)
		do ..Metric(metrics, order, name).samples.%Push(sample)
	}

	set out = []
	set it = order.%GetIterator()
	while it.%GetNext(.i, .name) {
		do out.%Push(metrics.%Get(name))
	}
	return out
}

ClassMethod Metric(metrics As %DynamicObject, order As %DynamicArray, name As %String) As %DynamicObject
{
	if 'metrics.%IsDefined(name) {
		do metrics.%Set(name, {"name": (name), "samples": []})
		do order.%Push(name)
	}
	return metrics.%Get(name)
}

/// split on quote-comma, not comma
ClassMethod Labels(line As %String) As %DynamicObject
{
	set labels = {}
	set inner = $piece($piece(line, "{", 2), "}")
	return:inner="" labels
	for i = 1:1:$length(inner, """,") {
		set pair = $piece(inner, """,", i)
		set key = $zstrip($piece(pair, "="), "<>W")
		continue:key=""
		do labels.%Set(key, $zstrip($piece(pair, "=", 2, *), "<>", """"))
	}
	return labels
}

}
