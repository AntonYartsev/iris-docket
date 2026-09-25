Class App.Tools.Os.History Extends App.Tools.Base
{

Parameter ToolName = "monitor.history";

Parameter Title = "Host CPU, memory, global references and SQL queries over the last 24 hours, a sample a minute";

Parameter Category = "os";

Parameter Mutating = 0;

Parameter Keep = 1440;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (..Series())}
}

ClassMethod Series() As %DynamicObject
{
	set now = ..Minute()
	do:now-$order(^App.Metrics(""), -1)>1 ..Sample()

	set out = {"now": ($zdatetime($horolog, 3)), "t": [], "cpu": [], "memory": [], "globalRefs": [], "sql": []}
	set m = ""
	for {
		set m = $order(^App.Metrics(m), 1, v)
		quit:m=""
		do out.t.%Push(m - now)
		do ..Push(out.cpu, $listget(v, 1)), ..Push(out.memory, $listget(v, 2))
		do ..Push(out.globalRefs, $listget(v, 3)), ..Push(out.sql, $listget(v, 4))
	}
	return out
}

ClassMethod Push(series As %DynamicArray, v As %String)
{
	do series.%Push($select(v = "": "", 1: +v), $select(v = "": "null", 1: "number"))
}

ClassMethod Minute(h As %String = {$horolog}) As %Integer [ CodeMode = expression ]
{
$piece(h, ",") * 1440 + ($piece(h, ",", 2) \ 60)
}

ClassMethod Sample()
{
	set names = "iris_cpu_usage,iris_phys_mem_percent_used,iris_glo_ref_per_sec,iris_sql_queries_per_second"
	set it = ##class(App.Tools.Os.Metrics).Read(names).%GetIterator()
	while it.%GetNext(, .metric) {
		set s = metric.samples.%GetIterator()
		while s.%GetNext(, .one) {
			continue:(metric.name["sql")&&(one.labels.%Get("id")'="all")
			set value(metric.name) = one.value
		}
	}
	do ..Record(..Minute(), $listbuild($get(value("iris_cpu_usage")), $get(value("iris_phys_mem_percent_used")), $get(value("iris_glo_ref_per_sec")), $get(value("iris_sql_queries_per_second"))))
}

ClassMethod Record(minute As %Integer, values As %List)
{
	set ^App.Metrics(minute) = values
	for {
		set k = $order(^App.Metrics(""))
		quit:(k="")||(k>(minute - ..#Keep))
		kill ^App.Metrics(k)
	}
}

}
