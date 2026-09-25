Class App.Tools.Audit.Stats Extends App.Tools.Base
{

Parameter ToolName = "audit.stats";

Parameter Title = "The journal of the last 24 hours in numbers: by hour, decision, outcome and actor";

Parameter Category = "audit";

Parameter Mutating = 0;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (..Count())}
}

ClassMethod Count() As %DynamicObject
{
	set utc = ..Secs($ztimestamp), shift = ..Secs($horolog) - utc
	set start = (utc \ 3600 - 23) * 3600
	set from = $zdatetime(..H(start), 3)

	set it = ##class(App.Tools.Registry).List().%GetIterator()
	while it.%GetNext(, .m) {
		set writes(m.name) = m.mutating
	}

	set total = {"calls": 0, "changes": 0, "asked": 0, "refused": 0, "failed": 0}
	set who = {}
	for i = 0:1:23 {
		set key = $extract($zdatetime(..H(start + (i * 3600)), 3), 1, 13)
		set hour(key) = {"hour": (+$extract($zdatetime(..H(start + (i * 3600) + shift), 3), 12, 13)), "calls": 0, "changes": 0, "asked": 0, "refused": 0, "failed": 0}
	}

	// group by uppercases everything..
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(SUBSTRING(Ts,1,13)) AS h, %EXACT(Tool) AS tool, %EXACT(Decision) AS d, %EXACT(Outcome) AS o, %EXACT($PIECE(Actor,':',1)) AS actor, COUNT(*) AS n FROM App_Audit.Entry WHERE Ts >= ? GROUP BY %EXACT(SUBSTRING(Ts,1,13)), %EXACT(Tool), %EXACT(Decision), %EXACT(Outcome), %EXACT($PIECE(Actor,':',1))", from)
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("tool_error", "cannot read the journal: "_rs.%Message)
	while rs.%Next() {
		set n = +rs.n, b = $get(hour(rs.h))
		continue:'$isobject(b)
		set kind = $case(1, rs.d="deny": "refused", rs.o="error": "failed", rs.o="pending": "asked", (rs.o="ok")&&$get(writes(rs.tool)): "changes", : "")
		for o = total, b {
			do o.%Set("calls", o.calls + n)
			do:kind'="" o.%Set(kind, o.%Get(kind) + n)
		}
		do who.%Set(rs.actor, who.%Get(rs.actor) + n)
		set:rs.o="error" failing(rs.tool) = $get(failing(rs.tool)) + n
	}

	set hours = []
	set key = ""
	for {
		set key = $order(hour(key))
		quit:key=""
		do hours.%Push(hour(key))
	}

	return {"from": (from), "total": (total), "hours": (hours), "who": (who), "failing": (..Failing(.failing, from)), "latency": (..Latency(from))}
}

ClassMethod Failing(ByRef failing, from As %String) As %DynamicArray
{
	set tool = ""
	for {
		set tool = $order(failing(tool), 1, n)
		quit:tool=""
		set rank(-n, tool) = ""
	}
	set out = [], n = ""
	for {
		set n = $order(rank(n))
		quit:n=""
		set tool = ""
		for {
			set tool = $order(rank(n, tool))
			quit:(tool="")||(out.%Size()=3)
			set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ErrorText FROM App_Audit.Entry WHERE Tool = ? AND Outcome = 'error' AND Ts >= ? ORDER BY Seq DESC", tool, from)
			do rs.%Next()
			do out.%Push({"tool": (tool), "n": (-n), "error": (rs.ErrorText)})
		}
		quit:out.%Size()=3
	}
	return out
}

ClassMethod Latency(from As %String) As %DynamicObject
{
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DurationMs AS ms, COUNT(*) AS n FROM App_Audit.Entry WHERE Ts >= ? AND DurationMs > 0 GROUP BY DurationMs ORDER BY DurationMs", from)
	set all = 0
	while rs.%Next() {
		set all = all + rs.n, hist($increment(hist)) = $listbuild(+rs.ms, all)
	}
	set out = {"p50": "", "p95": ""}
	quit:'all out
	for i = 1:1:hist {
		set $listbuild(ms, upto) = hist(i)
		do:(out.p50="")&&(upto>=(all*0.5)) out.%Set("p50", ms)
		if upto >= (all * 0.95) {
			do out.%Set("p95", ms)
			quit
		}
	}
	return out
}

ClassMethod Secs(h As %String) As %Integer [ CodeMode = expression ]
{
$piece(h, ",") * 86400 + ($piece(h, ",", 2) \ 1)
}

ClassMethod H(secs As %Integer) As %String [ CodeMode = expression ]
{
(secs \ 86400)_","_(secs # 86400)
}

}
