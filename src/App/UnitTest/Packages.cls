Class App.UnitTest.Packages Extends App.UnitTest.Base
{

Method TestInstalledNamesTheNamespaceItReadFrom()
{
	set mark = ..Mark()
	try {
		set data = ##class(App.Tools.Invoker).Run("packages.installed", {}, "user:unittest").data
		do $$$AssertTrue(data.%IsDefined("ipm"), "the answer says whether this instance has a package manager at all - an empty list alone would not")
		do $$$AssertTrue(data.unreadable.%IsA("%Library.DynamicArray"), "namespaces this account cannot read are named in the answer, not dropped and not raised as a warning")

		if 'data.ipm {
			do $$$AssertEquals(data.modules.%Size(), 0, "no package manager on this instance, so nothing was installed by one")
		} else {
			set it = data.modules.%GetIterator()
			while it.%GetNext(, .m) {
				do $$$AssertNotEquals(m.name, "", "every module has a name")
				do $$$AssertNotEquals(m.version, "", "'"_m.name_"' has a version")
				do $$$AssertTrue(##class(%SYS.Namespace).Exists(m.namespace), "'"_m.name_"' was found in a namespace this instance has, not "_m.namespace)
				do $$$AssertTrue(m.dependencies.%IsA("%Library.DynamicArray"), "'"_m.name_"' lists its dependencies, even when there are none")
			}
		}
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
}

Method TestAvailableExplainsItselfWhenTheRegistryIsOut()
{
	set mark = ..Mark()
	try {
		set code = "", message = ""
		try {
			set rows = ##class(App.Tools.Invoker).Run("packages.available", {}, "user:unittest").data
		} catch ex {
			set code = ex.Name, message = ex.Data
		}

		if code = "" {
			do $$$AssertTrue(rows.%Size() > 0, "the registry published packages")
			set it = rows.%GetIterator()
			while it.%GetNext(, .p) {
				do $$$AssertNotEquals(p.name, "", "every package the registry publishes has a name")
			}
		} else {
			do $$$AssertEquals(code, "unreachable", "an unreachable registry is 503, not a 500 that reads like a bug on this instance")
			do $$$AssertTrue(message [ ##class(App.Tools.Packages.Available).#Registry, "and the message names the registry rather than repeating the HTTP client: "_message)
		}
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
}

Method TestAFlagIsNotAPackageName()
{
	set mark = ..Mark()
	for bad = "-dev x", "math;uninstall zpm", "../../etc", "" {
		set code = "", detail = ""
		try {
			do ##class(App.Tools.Invoker).Run("packages.install", {"name": (bad), "namespace": "%SYS"}, "user:unittest")
		} catch ex {
			set code = ex.Name, detail = $select($isobject(ex.Detail): ex.Detail.%ToJSON(), 1: "")
		}
		do $$$AssertEquals(code, "bad_request", "'"_bad_"' is refused as a package name before anything runs")
		do $$$AssertTrue(detail [ "pattern", "and refused by the schema's pattern rather than by something further down: "_detail)
	}
	do ..Rewind(mark)
}

Method TestAJobRunsInTheBackgroundAsTheCaller()
{
	set mark = ..Mark()
	set args = {"name": "docket-no-such-package"}
	set args.namespace = $namespace
	try {
		if '##class(App.Tools.Packages.Change).HasIpm($namespace) {
			set code = ""
			try {
				do ##class(App.Tools.Invoker).Run("packages.install", args, "user:unittest")
			} catch ex {
				set code = ex.Data
			}
			do $$$AssertTrue(code [ "no package manager", "no IPM in "_$namespace_", so the refusal says so and names the namespace: "_code)
		} else {
			set token = ""
			try {
				do ##class(App.Tools.Invoker).Run("packages.install", args, "user:unittest")
			} catch ex {
				set token = $select($isobject(ex.Detail): ex.Detail.%Get("confirmToken"), 1: "")
			}
			do $$$AssertNotEquals(token, "", "the first call asks for a confirmation instead of installing anything")

			set res = ##class(App.Tools.Invoker).Run("packages.install", args, "user:unittest", "ui", token)
			set id = res.meta.asyncId
			do $$$AssertNotEquals(id, "", "the confirmed call answers at once with the id of a job")
			do $$$AssertEquals(res.data.state, "Queued", "and the job has not run yet")

			set row = ##class(%SQL.Statement).%ExecDirect(, "SELECT AsyncId FROM App_Audit.Entry WHERE Seq = ?", +res.meta.auditId)
			do row.%Next()
			do $$$AssertEquals(row.AsyncId, id, "the journal row carries the same id - the only thing tying a four-minute install to the person who confirmed it")

			for i = 1:1:240 {
				set job = ##class(App.Tools.Packages.Change).Get(id)
				quit:$isobject(job)&&(job.state'="Queued")&&(job.state'="Running")
				hang 0.5
			}
			do $$$AssertTrue($isobject(job), "the job record is there")
			do $$$AssertNotEquals(job.state, "Queued", "a background process picked it up")
			do $$$AssertNotEquals(job.state, "Running", "and it ended within two minutes")
			do $$$AssertEquals(job.runAs, $username, "it ran as the account that called, not as anything more privileged")

			set seen = ..Job(id)
			do $$$AssertTrue($isobject(seen), "and packages.jobs shows it")
			do $$$AssertTrue(seen.log [ "install docket-no-such-package", "with the log of what was run under it: "_$extract(seen.log, 1, 200))
			do ..Forget(id)
		}
	} catch ex {
		do $$$AssertTrue(0, "unexpected error: "_ex.DisplayString())
	}
	do ..Rewind(mark)
}

ClassMethod Job(id As %String) As %DynamicObject
{
	set it = ##class(App.Tools.Invoker).Run("packages.jobs", {}, "user:unittest").data.%GetIterator()
	while it.%GetNext(, .j) {
		return:j.id=id j
	}
	return ""
}

ClassMethod Forget(id As %String)
{
	set job = ##class(App.Tools.Packages.Change).Get(id)
	do:$isobject(job)&&(job.logFile'="") ##class(%File).Delete(job.logFile)
	kill ^App.Pkg("job", id)
}

}
