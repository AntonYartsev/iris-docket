Class App.Tools.Packages.Change Extends App.Tools.Base [ Abstract ]
{

Parameter Category = "packages";

Parameter Mutating = 1;

Parameter Privilege = "%All";

Parameter Verb;

Parameter Keep = 20;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["name", "namespace"],
  "properties": {
    "name": {
      "type": "string",
      "maxLength": 64,
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]*$",
      "title": "Package name as the registry publishes it"
    },
    "version": {
      "type": "string",
      "maxLength": 32,
      "pattern": "^[0-9*][0-9A-Za-z.*+-]*$",
      "title": "Version or version expression, e.g. 1.0.3 or 1.x. Empty means the latest the registry has."
    },
    "namespace": {
      "type": "string",
      "maxLength": 64,
      "pattern": "^[A-Za-z%][A-Za-z0-9%]*$",
      "title": "Namespace to work in. A package is installed into one namespace, not into the instance."
    }
  }
}
}

/// patterns block shell injection
ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set name = args.%Get("name"), version = args.%Get("version")
	set ns = $zconvert(args.%Get("namespace"), "U")
	set command = ..#Verb_" "_name_$select(version="": "", 1: " "_version)

	do:'##class(%SYS.Namespace).Exists(ns) ##class(App.Err).Throw("not_found", "no namespace "_ns_" on this instance")
	do:'..HasIpm(ns) ##class(App.Err).Throw("bad_request", ns_" has no package manager in it: %IPM.Main is not there, so there is nothing to "_..#Verb_" with")

	set id = $system.Util.CreateGUID()
	set job = {}
	set job.id = id, job.tool = ..#ToolName, job.package = name, job.version = version
	set job.namespace = ns, job.state = "Queued", job.queued = ..Now()
	set job.command = command
	set job.logFile = ##class(%File).NormalizeFilename("docket-pkg-"_$translate(id, "{}", "")_".log", ..Spool())
	set job.pid = "", job.started = "", job.finished = "", job.error = "", job.durationMs = ""
	set job.runAs = "", job.roles = ""
	do job.%Set("seq", $increment(^App.Pkg("seq")), "number")
	do ..Put(job)
	do ..Trim()

	job ##class(App.Tools.Packages.Change).Run(id)::5
	if '$test {
		set job.state = "Failed", job.finished = ..Now()
		set job.error = "the instance would not start a background process for this - check the licence's process limit"
		do ..Put(job)
		do ##class(App.Err).Throw("tool_error", job.error, {"asyncId": (id)})
	}

	set out = {"data": {"asyncId": (id), "state": "Queued", "command": (job.command), "namespace": (ns)}, "warnings": []}
	set out.asyncId = id
	return out
}

ClassMethod Run(id As %String)
{
	set job = ..Get(id)
	quit:'$isobject(job)
	set job.state = "Running", job.started = ..Now(), job.pid = $job
	set job.runAs = $username, job.roles = $roles
	do ..Put(job)

	set t0 = $zhorolog
	set err = ..Shell(job.namespace, job.command, job.logFile)
	set job = ..Get(id)
	do job.%Set("durationMs", (($zhorolog - t0) * 1000) \ 1, "number")
	set job.finished = ..Now()
	set job.state = $select(err = "": "Finished", 1: "Failed")
	set job.error = err
	do ..Put(job)
}

/// terminateOnError=0 or job dies
ClassMethod Shell(ns As %String, command As %String, logFile As %String) As %String
{
	try {
		new $namespace
		set $namespace = ns
		set sc = ##class(%IPM.Main).ShellScript(command, logFile, 0, 0)
		return $select($system.Status.IsOK(sc): "", 1: $zstrip($replace($system.Status.GetErrorText(sc), $char(13, 10), " "), "<>W"))
	} catch e {
		return e.DisplayString()
	}
}

ClassMethod List() As %DynamicArray
{
	set out = [], id = ""
	for {
		set id = $order(^App.Pkg("job", id))
		quit:id=""
		set job = ##class(%DynamicAbstractObject).%FromJSON(^App.Pkg("job", id))
		set by(+job.seq) = job
	}
	set seq = ""
	for {
		set seq = $order(by(seq), -1)
		quit:seq=""
		set job = by(seq)
		if (job.state = "Running") && (job.pid '= "") && '$data(^$job(job.pid)) {
			set job.state = "Lost"
			set job.error = "the process running this (pid "_job.pid_") is gone - packages.installed says what actually ended up on the instance"
		}
		set job.log = ..Log(job.logFile)
		do out.%Push(job)
	}
	return out
}

/// strip ansi colors
ClassMethod Log(path As %String, lines As %Integer = 300) As %String
{
	return:(path="")||'##class(%File).Exists(path) ""
	set f = ##class(%File).%New(path)
	return:'f.Open("R") ""
	set ansi = ##class(%Regex.Matcher).%New($char(27)_"\[[0-9;]*m")
	set n = 0
	while 'f.AtEnd {
		set ansi.Text = $zstrip(f.ReadLine(4096), ">", $char(13))
		set n = n + 1, ring(n # lines) = ansi.ReplaceAll("")
	}
	do f.Close()
	set out = ""
	for i = $select(n > lines: n - lines + 1, 1: 1):1:n {
		set out = out_ring(i # lines)_$char(10)
	}
	return out
}

ClassMethod Put(job As %DynamicObject)
{
	set ^App.Pkg("job", job.id) = job.%ToJSON()
}

ClassMethod Get(id As %String) As %DynamicObject
{
	return:'$data(^App.Pkg("job", id)) ""
	return ##class(%DynamicAbstractObject).%FromJSON(^App.Pkg("job", id))
}

ClassMethod Trim()
{
	set id = "", n = 0
	for {
		set id = $order(^App.Pkg("job", id))
		quit:id=""
		set job = ##class(%DynamicAbstractObject).%FromJSON(^App.Pkg("job", id))
		set n = n + 1, by(+job.seq) = job
	}
	quit:n'>..#Keep
	set seq = ""
	for i = 1:1:(n - ..#Keep) {
		set seq = $order(by(seq))
		quit:seq=""
		do:by(seq).logFile'="" ##class(%File).Delete(by(seq).logFile)
		kill ^App.Pkg("job", by(seq).id)
	}
}

ClassMethod Spool() As %String
{
	set dir = ##class(%File).NormalizeDirectory("Temp", ##class(%File).ManagerDirectory())
	do:'##class(%File).DirectoryExists(dir) ##class(%File).CreateDirectoryChain(dir)
	return dir
}

ClassMethod Now() As %String
{
	return $zdatetime($ztimestamp, 3, 1)
}

ClassMethod HasIpm(ns As %String) As %Boolean
{
	try {
		new $namespace
		set $namespace = ns
		return ##class(%Dictionary.CompiledClass).%ExistsId("%IPM.Main")
	} catch {
		return 0
	}
}

}
