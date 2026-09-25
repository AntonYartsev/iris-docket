Class App.UnitTest.History Extends App.UnitTest.Base
{

Method TestKeepsOneDay()
{
	merge saved = ^App.Metrics
	kill ^App.Metrics
	try {
		set now = ##class(App.Tools.Os.History).Minute()
		do ##class(App.Tools.Os.History).Record(now - 2000, $listbuild(1, 1, 1, 1))
		do ##class(App.Tools.Os.History).Record(now - 1000, $listbuild(2, 2, 2, ""))
		do ##class(App.Tools.Os.History).Record(now, $listbuild(3, 3, 3, 3))
		do $$$AssertTrue('$data(^App.Metrics(now - 2000)), "a sample older than a day is dropped when a new one arrives")
		set h = ##class(App.Tools.Os.History).Series()
		do $$$AssertEquals(h.t.%ToJSON(), "[-1000,0]", "the rest come back as minutes before now")
		do $$$AssertEquals(h.cpu.%ToJSON(), "[2,3]", "with their values")
		do $$$AssertEquals(h.sql.%ToJSON(), "[null,3]", "and a metric the instance did not report is null, not zero")
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	kill ^App.Metrics
	merge ^App.Metrics = saved
}

}
