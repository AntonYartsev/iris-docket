Class App.UnitTest.Findings Extends App.UnitTest.Base
{

Method TestStorageReportsEachVolumeOnce()
{
	set volumes = {}
	set it = ##class(App.Tools.Os.Metrics).Read("iris_disk_percent_full").%Get(0).samples.%GetIterator()
	while it.%GetNext(.i, .s) {
		do volumes.%Set(s.value, "")
	}

	set findings = []
	do ##class(App.Tools.Insight.Findings).Storage(findings, "storage", 0, 101)
	do $$$AssertTrue(volumes.%Size() > 0, "the instance reports at least one database volume")
	do $$$AssertEquals(findings.%Size(), volumes.%Size(), "one finding per volume, however many databases sit on it")
	do $$$AssertTrue(findings.%Get(0).probe["iris_disk_percent_full", "and it names the metric it read")
}

}
