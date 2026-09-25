Class App.Tools.Insight.Findings Extends App.Tools.Base
{

Parameter ToolName = "insight.findings";

Parameter Title = "Health checks: what is wrong with this instance right now";

Parameter Category = "insight";

Parameter Mutating = 0;

Parameter Privilege = "%Admin_Secure:U";

XData Checks [ MimeType = application/json ]
{
[
  { "id": "web-apps",          "method": "WebApps",          "title": "Web applications that accept unauthenticated requests" },
  { "id": "monitor-api",       "method": "MonitorApi",       "title": "The monitoring API, asked without credentials" },
  { "id": "privileged-users",  "method": "PrivilegedUsers",  "title": "Accounts that end up with %All" },
  { "id": "certificates",      "method": "Certificates",     "title": "Certificates that have expired or expire within 30 days" },
  { "id": "shared-keys",       "method": "SharedKeys",       "title": "Private keys that every user of the instance can use" },
  { "id": "failing-tasks",     "method": "FailingTasks",     "title": "Scheduled tasks whose last run failed" },
  { "id": "storage",           "method": "Storage",          "title": "Databases running out of room to grow" },
  { "id": "audit-off",         "method": "AuditOff",         "title": "System auditing switched off" },
  { "id": "portal-privileges", "method": "PortalPrivileges", "title": "Operations the portal's own account cannot perform" },
  { "id": "unknown-tools",     "method": "UnknownTools",     "title": "Calls for operations that do not exist" },
  { "id": "spec-drift",        "method": "SpecDrift",        "title": "Routes the pinned spec declares and this instance does not have" },
  { "id": "interop-stopped",   "method": "InteropStopped",   "title": "Productions that were running and are not" }
]
}

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set findings = [], checks = []
	set it = ..Definitions().%GetIterator()
	while it.%GetNext(.i, .c) {
		set ran = {"id": (c.id), "title": (c.title)}
		set before = findings.%Size(), t0 = $zhorolog
		try {
			do $classmethod($classname(), c.method, findings, c.id)
		} catch ex {
			set ran.error = $select(ex.%IsA("App.Err"): ex.Data, 1: ex.DisplayString())
		}
		do ran.%Set("findings", findings.%Size() - before, "number")
		do ran.%Set("ms", (($zhorolog - t0) * 1000) \ 1, "number")
		do checks.%Push(ran)
	}
	return {"data": {"findings": (findings), "checks": (checks)}}
}

ClassMethod Definitions() As %DynamicArray
{
	set x = ##class(%Dictionary.CompiledXData).%OpenId($classname()_"||Checks")
	do x.Data.Rewind()
	return ##class(%DynamicAbstractObject).%FromJSON(x.Data)
}

ClassMethod WebApps(findings As %DynamicArray, check As %String)
{
	set apps = ##class(App.Admin.Client).Call("GET", "/v2/web-apps", {"maxRows": 500}).data
	set quiet = "", quietN = 0
	set it = apps.%GetIterator()
	while it.%GetNext(.i, .app) {
		continue:'app.%Get("Enabled")
		set methods = ","_..Csv(app.%Get("AuthenticationMethods"))_","
		continue:'(methods[",Unauthenticated,")

		set detail = ##class(App.Admin.Client).Call("GET", "/v2/web-app", {"name": (app.Name)}).data
		set roles = ..Granted(detail.%Get("MatchRoles"))
		if roles = "" {
			set quiet = quiet_$select(quiet = "": "", 1: ", ")_app.Name, quietN = quietN + 1
			continue
		}

		set authe = +detail.%Get("AutheEnabled"), resource = detail.%Get("Resource")
		set fixed = ..AutheFixed(authe)

		set title = "Anyone can reach "_app.Name_" and gets "_roles
		set evidence = "AutheEnabled="_authe_" (bit 6 = Unauthenticated), and a MatchRole of """" gives every request, authenticated or not, the roles "_roles_". "
			_$select(resource = "": "No resource protects the application.", 1: "The resource "_resource_" still applies, which is what keeps this short of critical.")
		set probe = "GET /api/admin/v2/web-app?name="_app.Name_" -> AutheEnabled="_authe
			_", MatchRole """" -> "_roles_", Resource="""_resource_""""
		do ..Add(findings, check, $select(resource = "": "high", 1: "medium"), title, evidence, probe, "webapp.update", {"name": (app.Name), "AutheEnabled": (fixed)})
	}

	quit:quietN=0
	set evidence = "They grant no roles, so a request that does not authenticate gets only what is public - normal for static CSP applications, and listed here so the number is not hidden: "_quiet
	set probe = "GET /api/admin/v2/web-apps?maxRows=500 -> "_apps.%Size()_" applications; "_quietN
		_" of them enabled, offering Unauthenticated, and granting no roles through a MatchRole """""
	do ..Add(findings, check, "low", quietN_" more applications accept unauthenticated requests", evidence, probe)
}

ClassMethod MonitorApi(findings As %DynamicArray, check As %String)
{
	set proof = ""
	for url = "/api/monitor/metrics", "/api/monitor/alerts" {
		set data = ##class(App.Tools.Rest.Base).Send("GET", url, .code, , 1)
		continue:code'=200
		set proof = proof_$select(proof = "": "", 1: "; ")_"GET "_url_" with no Authorization header and no session -> 200, "_data.Size_" bytes"
	}
	quit:proof=""
	set evidence = "Everything this instance reports about itself - memory, licence, database sizes, journal state - is readable by anyone who can reach the port. "
		_"Both endpoints belong to the /api/monitor application, so one change closes them."
	do ..Add(findings, check, "high", "The monitoring API answers with no credentials at all", evidence, proof, "webapp.update", {"name": "/api/monitor", "AutheEnabled": 32})
}

ClassMethod PrivilegedUsers(findings As %DynamicArray, check As %String)
{
	set portal = ##class(App.Admin.Client).Cred("IRIS_ADMIN_USER", "_SYSTEM")
	set users = ##class(App.Admin.Client).Call("GET", "/v2/security/users", {"maxRows": 1000}).data
	set it = users.%GetIterator()
	while it.%GetNext(.i, .u) {
		set sc = $system.Security.GetUserRecursedRoleSet(u.Name, .recursed)
		continue:$system.Status.IsError(sc)
		set effective = ","_recursed_","
		continue:'(effective[",%All,")

		set user = ##class(App.Admin.Client).Call("GET", "/v2/security/user", {"name": (u.Name)}).data
		set direct = ","_..Csv(user.%Get("Roles"))_","
		set held = direct[",%All,"
		set enabled = ''u.%Get("Enabled")

		set evidence = "Effective roles: "_recursed_". "
			_$select(held: "%All is held directly by the account.", 1: "%All is not held directly - it arrives through one of the roles above, so it comes off the role, not off the user.")
			_$select(enabled: "", 1: " The account is disabled.")

		set probe = "$SYSTEM.Security.GetUserRecursedRoleSet("""_u.Name_""") -> "_recursed

		if u.Name = portal {
			// never revoke portals own account
			set evidence = evidence_" IRIS_ADMIN_USER points at this account: narrowing it is the least-privilege step described in the README, not a button on a screen."
			do ..Add(findings, check, "low", u.Name_" holds %All and is the account the portal itself uses", evidence, probe)
			continue
		}
		do ..Add(findings, check, $select(enabled: "medium", 1: "low"), u.Name_" holds %All", evidence, probe, $select(held: "security.user.revokeRole", 1: ""), {"username": (u.Name), "role": "%All"})
	}
}

ClassMethod Certificates(findings As %DynamicArray, check As %String)
{
	set list = ##class(App.Admin.Client).Call("GET", "/v2/security/x509-credentials", {"maxRows": 1000}).data
	set it = list.%GetIterator()
	while it.%GetNext(.i, .c) {
		set cert = ##class(App.Admin.Client).Call("GET", "/v2/security/x509-credential/certificate", {"alias": (c.Alias)}).data
		set until = cert.%Get("ValidityNotAfter")
		set days = $zdateh($piece(until, " "), 3, , , , , , , "") - $piece($ztimestamp, ",")
		continue:(until="")||(days>30)

		set title = "Certificate "_c.Alias_$select(days < 0: " expired on "_$piece(until, " "), days = 0: " expires today", 1: " expires in "_days_" "_$select(days = 1: "day", 1: "days"))
		set evidence = "Subject "_cert.%Get("SubjectDN")_", issued by "_cert.%Get("IssuerDN")_$select(cert.%Get("IssuerDN") = cert.%Get("SubjectDN"): " (self-signed)", 1: "")
			_", "_$select(cert.%Get("HasPrivateKey"): "with its private key", 1: "certificate only")_". "
			_"Whatever presents or verifies it - a TLS configuration, WS-Security - fails once it lapses. "
			_"Renewal is a new certificate from its issuer; the portal reads secrets and writes none."
		set probe = "GET /api/admin/v2/security/x509-credential/certificate?alias="_c.Alias_" -> ValidityNotAfter "_until
		do ..Add(findings, check, $select(days < 0: "high", 1: "medium"), title, evidence, probe)
	}
}

ClassMethod SharedKeys(findings As %DynamicArray, check As %String)
{
	set list = ##class(App.Admin.Client).Call("GET", "/v2/security/x509-credentials", {"maxRows": 1000}).data
	set it = list.%GetIterator()
	while it.%GetNext(.i, .c) {
		continue:'c.%Get("HasPrivateKey")
		set owners = c.%Get("OwnerList")
		continue:$isobject(owners)&&owners.%Size()
		set evidence = "The credential holds a private key and has no owner list, which makes it - key included - available to every user of the instance, "
			_"not only to the service it belongs to. Whoever can use it can sign and present as that service. "
			_"The fix is an OwnerList naming the accounts that need it; the portal reads secrets and writes none."
		set probe = "GET /api/admin/v2/security/x509-credentials?maxRows=1000 -> "_c.Alias_": HasPrivateKey true, OwnerList "_$select($isobject(owners): owners.%ToJSON(), 1: "absent")
		do ..Add(findings, check, "medium", "Any user of the instance can use the private key of "_c.Alias, evidence, probe)
	}
}

ClassMethod Storage(findings As %DynamicArray, check As %String, diskAt As %Integer = 90, sizeAt As %Integer = 90)
{
	set it = ##class(App.Tools.Os.Metrics).Read("iris_disk_percent_full").%Get(0).samples.%GetIterator()
	while it.%GetNext(.i, .s) {
		continue:s.value<diskAt
		set full(s.value) = $get(full(s.value))_$select($data(full(s.value)): ", ", 1: "")_s.labels.id
	}
	set pct = ""
	for {
		set pct = $order(full(pct))
		quit:pct=""
		set evidence = "The volume under "_full(pct)_" is "_pct_"% full. Those databases expand into it as they grow, and a write that needs a new block when there is none fails with <FILEFULL>."
		set probe = "GET /api/monitor/metrics -> iris_disk_percent_full = "_pct_" for "_full(pct)
		do ..Add(findings, check, $select(pct >= 97: "high", 1: "medium"), "A database volume is "_pct_"% full", evidence, probe)
	}

	set it = ##class(App.Admin.Client).Call("GET", "/v2/database-dirs", {"maxRows": 1000}).data.%GetIterator()
	while it.%GetNext(.i, .db) {
		set max = db.%Get("MaxSize"), size = +db.%Get("Size")
		continue:'$isvalidnum(max)||(+max<=0)
		set used = (size * 100) \ max
		continue:used<sizeAt
		set evidence = "Size "_size_" MB of a MaxSize of "_max_" MB. At the ceiling the database takes no more writes, whatever room the volume has."
		set probe = "GET /api/admin/v2/database-dirs -> "_db.Directory_": Size "_size_", MaxSize "_max
		do ..Add(findings, check, $select(used >= 98: "high", 1: "medium"), db.Directory_" is at "_used_"% of its MaxSize", evidence, probe)
	}
}

ClassMethod FailingTasks(findings As %DynamicArray, check As %String)
{
	set rows = ##class(App.Admin.Client).Call("GET", "/v2/task/history", {"maxRows": 500}).data
	set it = rows.%GetIterator()
	while it.%GetNext(.i, .r) {
		continue:(+r.%Get("Status")=1)&&(+r.%Get("ErrNumber")=0)
		set id = +r.%Get("TaskId")
		continue:$data(seen(id))
		set seen(id) = ""
		// reason in Status not Result
		set why = $select(r.%Get("Result") '= "": r.%Get("Result"), 1: r.%Get("Status"))
		set evidence = why_" Namespace "_r.%Get("Namespace")_", routine "_r.%Get("Routine")_", run as "_r.%Get("Username")_". "
			_"The scheduler still lists the task as scheduled: nothing about its state says the last run failed."
		set probe = "GET /api/admin/v2/task/history?maxRows=500 -> TaskId "_id_", LastStart "_r.%Get("LastStart")_", Status "_why
		do ..Add(findings, check, "medium", "Task """_r.%Get("Name")_""" failed at "_r.%Get("LastStart"), evidence, probe, "task.run", {"id": (id)})
	}
}

ClassMethod AuditOff(findings As %DynamicArray, check As %String)
{
	set answer = ##class(App.Admin.Client).Call("GET","/v2/security/audit/enabled").data
	set on = answer.%Get("Enabled")
	quit:''on
	set probe = "GET /api/admin/v2/security/audit/enabled -> "_answer.%ToJSON()
	set evidence = "Nothing the instance does is being recorded, "
		_"the audit feed on the Logs screen can only show what was collected before it was switched off, and the portal's own journal becomes the only record of anything. "
		_"Turning it back on is PUT /v2/security/audit/enabled, deliberately not in the curated tool set: the portal reads the audit configuration and does not rewrite it."
	do ..Add(findings, check, "high", "System auditing is switched off", evidence, probe)
}

ClassMethod PortalPrivileges(findings As %DynamicArray, check As %String)
{
	set privileges = ##class(App.Admin.Client).Info(1).%Get("privileges")
	quit:'$isobject(privileges)

	set it = ##class(App.Tools.Registry).List().%GetIterator()
	while it.%GetNext(.i, .tool) {
		set resource = $piece(tool.%Get("privilege"), ":", 1)
		continue:$extract(resource,1,7)'="%Admin_"
		// strip %Admin_ prefix
		set key = $extract(resource, 8, *)
		set have = privileges.%Get(key)
		continue:$isobject(have)&&''have.%Get("use")
		set blocked(resource) = $get(blocked(resource))_$select($data(blocked(resource)): ", ", 1: "")_tool.name
		set probe(resource) = "GET /api/admin/v2/info -> privileges."_key_" = "
			_$select($isobject(have): have.%ToJSON(), 1: "absent, so the account has no use permission on it")
	}

	set resource = ""
	for {
		set resource = $order(blocked(resource))
		quit:resource=""
		set evidence = "These tools are in the registry and the instance will refuse them: "_blocked(resource)_". "
			_"Either grant the resource to IRIS_ADMIN_USER, or know that this part of the menu is decoration."
		do ..Add(findings, check, "medium", "The portal's account is missing "_resource, evidence, probe(resource))
	}
}

ClassMethod UnknownTools(findings As %DynamicArray, check As %String)
{
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM App_Audit.Entry WHERE RuleId = 'unknown-tool'")
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("internal", "the journal query failed: "_rs.%Message)
	quit:'rs.%Next()
	set n = +rs.N
	quit:n=0

	set recent = ""
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 5 Seq,Actor,Tool FROM App_Audit.Entry WHERE RuleId = 'unknown-tool' ORDER BY Seq DESC")
	while rs.%Next() {
		set recent = recent_$select(recent = "": "", 1: "; ")_rs.Actor_" asked for "_rs.Tool_" (audit #"_rs.Seq_")"
	}

	set evidence = "Refused before anything ran, and written down: "_recent_". "
		_"The set of operations is the boundary, so a name that is not in the registry is not a missing feature - it is somebody, or something, trying a door that was never fitted."
	set probe = "SELECT COUNT(*) FROM App_Audit.Entry WHERE RuleId = 'unknown-tool' -> "_n
	do ..Add(findings, check, "medium", n_" "_$select(n = 1: "call", 1: "calls")_" asked for an operation that does not exist", evidence, probe, , , "q=unknown-tool")
}

ClassMethod SpecDrift(findings As %DynamicArray, check As %String)
{
	set path = ""
	for {
		set path = $order(^App.Drift(path))
		quit:path=""
		set evidence = "First seen "_^App.Drift(path)_". The pinned spec (spec/mainspec_v2.json) declares this route and the instance answers 404 with an empty body, "
			_"which is drift rather than a missing object. Confirmed differences belong in spec/overlay.json."
		do ..Add(findings, check, "low", "This instance has no route "_path, evidence, ..Ask("/api/admin"_path))
	}
}

ClassMethod InteropStopped(findings As %DynamicArray, check As %String)
{
	set spaces = ##class(App.Tools.Ens.Base).Namespaces(), it = spaces.%GetIterator()
	while it.%GetNext(, .ns) {
		set one = ##class(App.Tools.Ens.Productions).Read(ns, .err)
		continue:err'=""
		continue:one.state="Running"
		set p = one.productions.%GetIterator()
		while p.%GetNext(, .prod) {
			continue:prod.startedAt=""
			set evidence = prod.name_" in "_ns_" last started "_prod.startedAt_" and stopped "
				_$select(prod.stoppedAt="": "at an unrecorded time", 1: prod.stoppedAt)
				_". Nothing it services is being processed."
			set probe = "Ens.Director.GetProductionStatus() in "_ns_" -> "_prod.name_", "_one.state
			do ..Add(findings, check, "medium", "Production "_prod.name_" is stopped in "_ns, evidence, probe, "ens.production.start", {"namespace": (ns), "production": (prod.name)})
		}
	}
}

ClassMethod Add(findings As %DynamicArray, check As %String, severity As %String, title As %String, evidence As %String, probe As %String = "", fixTool As %String = "", fixArgs As %DynamicObject = "", audit As %String = "")
{
	set f = {"check": (check), "severity": (severity), "title": (title), "evidence": (evidence), "probe": (probe)}
	set:fixTool'="" f.fixTool = fixTool, f.fixArgs = fixArgs
	set:audit'="" f.audit = audit
	do findings.%Push(f)
}

ClassMethod Ask(url As %String, anonymous As %Boolean = 0) As %String
{
	try {
		set data = ##class(App.Tools.Rest.Base).Send("GET", url, .code, , anonymous)
		return "GET "_url_$select(anonymous: " with no Authorization header and no session", 1: " as the portal's own account")_" -> "_code_", "_data.Size_" bytes"
	} catch ex {
		return "GET "_url_" could not be made: "_$select(ex.%IsA("App.Err"): ex.Data, 1: ex.DisplayString())
	}
}

/// drop unauth bit, fallback password
ClassMethod AutheFixed(authe As %Integer) As %Integer
{
	set fixed = authe - 64
	return $select(fixed = 0: 32, 1: fixed)
}

ClassMethod Csv(array As %DynamicArray) As %String
{
	return ##class(App.Tools.Security.Effective).Join(array)
}

ClassMethod Granted(matchRoles As %DynamicArray) As %String
{
	return:'$isobject(matchRoles) ""
	set roles = "", it = matchRoles.%GetIterator()
	while it.%GetNext(.i, .m) {
		continue:m.%Get("MatchRole")'=""
		set one = ..Csv(m.%Get("TargetRoles"))
		for j = 1:1:$length(one, ",") {
			set r = $piece(one, ",", j)
			continue:r=""
			continue:(","_roles_",")[(","_r_",")
			set roles = roles_$select(roles = "": "", 1: ", ")_r
		}
	}
	return roles
}

}
