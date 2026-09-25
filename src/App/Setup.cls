Class App.Setup [ Abstract ]
{

Parameter SSLConfig = "portal-tls";

Parameter PortalRole = "DocketOperator";

Parameter PortalResources = "%Admin_Secure:U,%Admin_Operate:U,%Admin_Manage:U,%Admin_Task:U,%Admin_Wallet:U,%Admin_OAuth2_Client:U,%DB_IRISSYS:RW,%DB_USER:R,%Ens_ProductionRun:U";

ClassMethod Run(uiDir As %String = "/opt/portal/www", demoDir As %String = "/opt/portal/demo", withDemo As %Boolean = 1)
{
	// ens commits zpms transaction..
	set level = $tlevel

	if $namespace '= "%SYS" {
		throw ##class(%Exception.General).%New("docket installs into %SYS, not "_$namespace_": Security.* and SYS.* are visible nowhere else")
	}

	do ..Password()
	do ..Account()

	// embedded python need callin
	set prop("Enabled") = 1
	do ##class(Security.Services).Modify("%Service_CallIn", .prop)

	do ..Python()

	write "tools in the registry: ", ##class(App.Tools.Registry).Build(), !

	do ..Tls()
	do ..Sampler()

	kill ui
	set ui("NameSpace") = "%SYS"
	set ui("Enabled") = 1
	set ui("AutheEnabled") = 64
	set ui("Path") = uiDir
	set ui("ServeFiles") = 1
	set ui("Recurse") = 1
	set ui("CookiePath") = "/portal/"
	set ui("Description") = "Docket - UI"
	do ..WebApp("/portal", .ui)

	do:withDemo ..Demo()

	kill api
	set api("NameSpace") = "%SYS"
	set api("Enabled") = 1
	set api("AutheEnabled") = 32
	set api("DispatchClass") = "App.REST.Router"
	set api("CookiePath") = "/portal/"
	set api("Description") = "Docket - REST"
	do ..WebApp("/portal/api", .api)

	if withDemo {
		try {
			do ..Certificates()
		} catch e {
			write "demo certificates: ", e.DisplayString(), !
		}
		try {
			do ..Interop(demoDir)
			do ..FailingTask()
		} catch e {
			write "App.Demo.Production: ", e.DisplayString(), !
		}
	} else {
		write "demo data: skipped (withDemo=0) - no demo account, roles, certificates, production or failing task", !
	}

	while $tlevel < level { tstart }

	do ..Verify()
}

ClassMethod Verify()
{
	set bad = ""
	for app = "/portal", "/portal/api" {
		set:'##class(Security.Applications).Exists(app) bad = bad_$listbuild("web application "_app_" does not exist")
	}
	set:'$data(^App.Tools("meta")) bad = bad_$listbuild("the tool registry is empty - App.Tools.Registry.Build() found nothing")
	try {
		set rules = ##class(App.Policy.Engine).Config().rules
		set:'$isobject(rules)||(rules.%Size()=0) bad = bad_$listbuild("the policy has no rules")
	} catch e {
		set bad = bad_$listbuild("the policy did not load: "_e.DisplayString())
	}
	quit:bad=""

	throw ##class(%Exception.General).%New("docket setup did not finish: "_$listtostring(bad, "; "))
}

ClassMethod Python()
{
	set mod = ""
	try { set mod = ##class(%SYS.Python).Import("jsonschema") } catch {}
	quit:$isobject(mod)

	set python = ##class(%File).NormalizeFilename("bin/irispython", $system.Util.InstallDirectory())
	set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
	set rc = $zf(-100, "", python, "-m", "pip", "install", "--no-cache-dir", "--target", target, "jsonschema==4.26.0")
	write "jsonschema: ", $select(rc: "pip exited "_rc_" - without it no tool can be called at all", 1: "installed"), !
}

ClassMethod Tls()
{
	quit:##class(Security.SSLConfigs).Exists(..#SSLConfig)
	set p("CAFile") = "/etc/ssl/certs/ca-certificates.crt"
	set p("VerifyPeer") = 1
	set p("Type") = 0
	set p("Enabled") = 1
	set sc = ##class(Security.SSLConfigs).Create(..#SSLConfig, .p)
	write ..#SSLConfig, ": ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "ok"), !
}

ClassMethod Interop(demoDir As %String = "/opt/portal/demo")
{
	new $namespace
	set $namespace = "USER"

	do $system.OBJ.LoadDir(demoDir, "ck", , 1)

	do ##class(Ens.Director).GetProductionStatus(.name, .state)
	if (name '= "App.Demo.Production") || (+state '= 1) {
		set sc = ##class(Ens.Director).StartProduction("App.Demo.Production")
		write "App.Demo.Production: ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "started"), !
		quit:$system.Status.IsError(sc)
	}

	// else its suspended after restart
	do ##class(Ens.Director).SetAutoStart("App.Demo.Production")

	quit:$data(^App.Demo.Seeded)
	set cr = $char(13)
	set m(1) = "MSH|^~\&|REG|DEMO|PORTAL|DEMO|20260917080100||ADT^A01|D0001|P|2.5"_cr_"EVN|A01|20260917080100"_cr_"PID|1||MRN-100234^^^DEMO^MR||DOE^JANE||19800114|F"_cr_"PV1|1|I|WARD-3^^^DEMO"
	set m(2) = "MSH|^~\&|REG|DEMO|PORTAL|DEMO|20260917081200||ADT^A01|D0002|P|2.5"_cr_"EVN|A01|20260917081200"_cr_"PID|1||MRN-100571^^^DEMO^MR||OKONKWO^ADAEZE||19670902|F"_cr_"PV1|1|I|WARD-1^^^DEMO"
	set m(3) = "MSH|^~\&|LAB|DEMO|PORTAL|DEMO|20260917083000||ORU^R01|L0001|P|2.5"_cr_"PID|1||MRN-100234^^^DEMO^MR||DOE^JANE||19800114|F"_cr_"OBR|1||L-77812|CBC^Complete blood count"_cr_"OBX|1|NM|HGB^Haemoglobin||13.4|g/dL|12.0-16.0|N|||F"
	set m(4) = "MSH|^~\&|REG|DEMO|PORTAL|DEMO|20260917090400||ADT^A08|D0003|P|2.5"_cr_"EVN|A08|20260917090400"_cr_"PID|1||MRN-UNKNOWN^^^DEMO^MR||PATIENT^UNKNOWN||19700101|U"_cr_"PV1|1|O|CLINIC^^^DEMO"
	set m(5) = "MSH|^~\&|LAB|DEMO|PORTAL|DEMO|20260917091500||ORU^R01|L0002|P|2.5"_cr_"PID|1||MRN-100571^^^DEMO^MR||OKONKWO^ADAEZE||19670902|F"_cr_"OBR|1||L-77901|BMP^Basic metabolic panel"_cr_"OBX|1|NM|NA^Sodium||139|mmol/L|135-145|N|||F"
	for i = 1:1:5 {
		set msg = ##class(EnsLib.HL7.Message).ImportFromString(m(i), .sc)
		set:'$system.Status.IsError(sc) sc = ##class(EnsLib.Testing.Service).SendTestRequest("Admissions Router", msg, , .sid, 0)
		write:$system.Status.IsError(sc) "  demo message ", i, ": ", $system.Status.GetErrorText(sc), !
	}

	// wait, else half proccesed feed
	for i = 1:1:60 {
		set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS c FROM Ens.MessageHeader WHERE Status IN (1, 2, 3, 6)")
		do rs.%Next()
		quit:+rs.c=0
		hang 0.5
	}
	set ^App.Demo.Seeded = $zdatetime($ztimestamp, 3, 1, 3)
	write "demo messages: 5 sent through Admissions Router, queues drained", !
}

ClassMethod FailingTask()
{
	set name = "Docket demo: nightly export"
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE Name = ?", name)
	if rs.%Next() {
		set id = rs.ID
	} else {
		set t = ##class(%SYS.Task).%New()
		set t.Name = name, t.NameSpace = "USER", t.TaskClass = "App.Demo.NightlyExport"
		set t.Description = "Demo data for the failing-tasks health check: an export to a mount that is not there."
		set t.TimePeriod = 0, t.TimePeriodEvery = 1, t.DailyFrequency = 0
		set t.DailyStartTime = 7200, t.StartDate = +$horolog + 1
		set sc = t.%Save()
		if $system.Status.IsError(sc) {
			write "demo task: ", $system.Status.GetErrorText(sc), !
			quit
		}
		set id = t.%Id()
		// release lock or deadlock!!
		set t = ""
	}

	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS c FROM %SYS_Task.History WHERE Task = ? AND Status <> 1", id)
	do rs.%Next()
	quit:+rs.c>0

	set sc = ##class(%SYS.Task).RunNow(id)
	if $system.Status.IsError(sc) {
		write "demo task: ", $system.Status.GetErrorText(sc), !
		quit
	}
	write "demo task: asked the task manager to run it, waiting for the history row...", !
	for i = 1:1:90 {
		set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS c FROM %SYS_Task.History WHERE Task = ? AND Status <> 1", id)
		do rs.%Next()
		quit:+rs.c>0
		hang 1
	}
	write "demo task: ", $select(+rs.c>0: "ran and failed, as designed", 1: "queued, but the task manager had not run it within 90s - the failing-tasks check will find nothing until it does"), !
}

ClassMethod Sampler()
{
	set name = ##class(App.Tools.Os.Sampler).#TaskName
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE Name = ?", name)
	quit:rs.%Next()
	set t = ##class(%SYS.Task).%New()
	set t.Name = name, t.NameSpace = "%SYS", t.TaskClass = "App.Tools.Os.Sampler"
	set t.Description = "Docket: a host metrics sample a minute, for the dashboard's 24-hour charts (^App.Metrics)."
	set t.TimePeriod = 0, t.TimePeriodEvery = 1, t.DailyFrequency = 1, t.DailyFrequencyTime = 0
	set t.DailyIncrement = 10, t.DailyStartTime = 0, t.StartDate = +$horolog
	set sc = t.%Save()
	write "metrics task: ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "created"), !
}

ClassMethod Certificates()
{
	for demo = "docket-demo-service:730:1", "docket-demo-partner:20:0" {
		set alias = $piece(demo, ":", 1), days = $piece(demo, ":", 2), withKey = $piece(demo, ":", 3)
		continue:$isobject(##class(%SYS.X509Credentials).GetByAlias(alias))

		set base = ##class(%File).TempFilename(), cert = base_".crt", key = base_".key"
		set rc = $zf(-100, "/STDERR=""/dev/null""", "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
			"-keyout", key, "-out", cert, "-days", days, "-subj", "/O=Docket demo/CN="_alias_".docket.local")
		if rc '= 0 {
			write alias, ": openssl exited ", rc, " - no certificate, and the certificate check will have nothing to read", !
			continue
		}
		set x = ##class(%SYS.X509Credentials).%New()
		set x.Alias = alias
		set sc = x.LoadCertificate(cert)
		set:$system.Status.IsOK(sc)&&withKey sc = x.LoadPrivateKey(key)
		set:$system.Status.IsOK(sc) sc = x.%Save()
		do ##class(%File).Delete(cert), ##class(%File).Delete(key)
		write alias, ": ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "expires in "_days_" days"), !
	}
}

ClassMethod Demo()
{
	do ..Role("PortalDemoReader", "Portal demo: read-only operator", "%Admin_Operate:U", "")
	do ..Role("PortalDemoOperator", "Portal demo: operator, inherits PortalDemoReader", "%Admin_Task:U", "PortalDemoReader")

	quit:##class(Security.Users).Exists("portaldemo")
	set sc = ##class(Security.Users).Create("portaldemo", "PortalDemoOperator", $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(18)), "Portal demo operator")
	write "portaldemo: ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "ok"), !
	quit:$system.Status.IsError(sc)
	quit:'##class(Security.Users).Exists("portaldemo", .u)
	set u.Enabled = 0
	do u.%Save()
}

ClassMethod Account()
{
	do ..Role(..#PortalRole, "Docket portal: read the six areas, change what the policy allows", ..#PortalResources, "")
	do ..Grants()

	set user = $system.Util.GetEnviron("IRIS_ADMIN_USER")
	quit:(user="")||(user="_SYSTEM")
	if ##class(Security.Users).Exists(user) {
		write user, ": exists already, left as it is - grant it ", ..#PortalRole, " to run the portal as it", !
		quit
	}
	set pw = $system.Util.GetEnviron("IRIS_ADMIN_PASSWORD")
	if pw = "" {
		write user, ": IRIS_ADMIN_PASSWORD is empty, so no account was created", !
		quit
	}
	set sc = ##class(Security.Users).Create(user, ..#PortalRole, pw, "Docket portal")
	write user, ": ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "created, holding "_..#PortalRole), !
}

ClassMethod Grants()
{
	do ..Grant("%SYS.Task"), ..Grant("App_Audit.Entry")

	new $namespace
	set $namespace = "USER"
	do ..Grant("Ens.MessageHeader"), ..Grant("Ens_Util.Log")
}

ClassMethod Grant(table As %String)
{
	set rs = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON "_table_" TO "_..#PortalRole)
	write "grant select on ", table, ": ", $select(rs.%SQLCODE: "SQLCODE "_rs.%SQLCODE_" "_rs.%Message, 1: "ok"), !
}

ClassMethod Role(name As %String, description As %String, resources As %String, granted As %String)
{
	if ##class(Security.Roles).Exists(name) {
		set props("Description") = description, props("Resources") = resources, props("GrantedRoles") = granted
		set sc = ##class(Security.Roles).Modify(name, .props)
	} else {
		set sc = ##class(Security.Roles).Create(name, description, resources, granted)
	}
	write name, ": ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "ok"), !
}

/// recreate, Modify leaves junk
ClassMethod WebApp(name As %String, ByRef props)
{
	do:##class(Security.Applications).Exists(name) ##class(Security.Applications).Delete(name)
	set sc = ##class(Security.Applications).Create(name, .props)
	write name, ": ", $select($system.Status.IsError(sc): $system.Status.GetErrorText(sc), 1: "ok"), !
}

/// stock hook broken on 2026
ClassMethod Password()
{
	set pw = $system.Util.GetEnviron("IRIS_PASSWORD")
	quit:pw=""
	quit:'##class(Security.Users).Exists("_SYSTEM", .u)
	quit:'$isobject(u)
	set u.PasswordExternal = pw, u.ChangePassword = 0, u.Enabled = 1
	do u.%Save()
}

}
