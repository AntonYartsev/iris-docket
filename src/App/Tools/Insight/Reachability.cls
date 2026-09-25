Class App.Tools.Insight.Reachability Extends App.Tools.Base
{

Parameter ToolName = "insight.reachability";

Parameter Title = "Who reaches the sensitive resources of this instance, and how";

Parameter Category = "insight";

Parameter Mutating = 0;

Parameter Privilege = "%Admin_Secure:U";

Parameter Requires = "GET /v2/web-apps, GET /v2/web-app, GET /v2/security/users, GET /v2/security/user";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "targets": {
      "type": "array",
      "title": "Resources to trace",
      "items": { "type": "string" }
    },
    "assume": {
      "type": "array",
      "title": "Operations to assume have run",
      "items": {
        "type": "object",
        "required": ["tool"],
        "properties": {
          "tool": { "type": "string" },
          "args": { "type": "object" }
        }
      }
    }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return ..Build(..Collect(), args.%Get("targets"), args.%Get("assume"))
}

ClassMethod Targets() As %DynamicArray
{
	return ["%All", "%DB_IRISSYS", "%Admin_Secure"]
}

ClassMethod Collect() As %DynamicObject
{
	set raw = {"webapps": [], "users": [], "roles": {}}
	set raw.portal = ##class(App.Admin.Client).Cred("IRIS_ADMIN_USER", "_SYSTEM")

	set apps = ##class(App.Admin.Client).Call("GET", "/v2/web-apps", {"maxRows": 500}).data
	set it = apps.%GetIterator()
	while it.%GetNext(, .app) {
		continue:'app.%Get("Enabled")
		set detail = ##class(App.Admin.Client).Call("GET", "/v2/web-app", {"name": (app.Name)}).data
		set granted = ##class(App.Tools.Insight.Findings).Granted(detail.%Get("MatchRoles"))
		continue:granted=""

		set one = {"name": (app.Name), "resource": (detail.%Get("Resource")), "roles": []}
		do one.%Set("autheEnabled", +detail.%Get("AutheEnabled"), "number")
		for i = 1:1:$length(granted, ", ") {
			set role = $piece(granted, ", ", i)
			continue:role=""
			do one.roles.%Push(role)
			do ..Role(raw.roles, role)
		}
		do raw.webapps.%Push(one)
	}

	set users = ##class(App.Admin.Client).Call("GET", "/v2/security/users", {"maxRows": 1000}).data
	set it = users.%GetIterator()
	while it.%GetNext(, .u) {
		set one = ##class(App.Tools.Security.Effective).Expand(u.Name)
		do one.%Set("enabled", ''u.%Get("Enabled"), "boolean")
		do raw.users.%Push(one)
	}
	return raw
}

ClassMethod Role(roles As %DynamicObject, name As %String)
{
	quit:roles.%IsDefined(name)
	set one = {"resources": [], "nested": []}
	kill props
	if $system.Status.IsOK(##class(Security.Roles).Get(name, .props)) {
		set list = $get(props("Resources"))
		for i = 1:1:$length(list, ",") {
			set entry = $piece(list, ",", i)
			continue:entry=""
			do one.resources.%Push({"resource": ($piece(entry, ":", 1)), "permissions": ($piece(entry, ":", 2))})
		}
		set one.nested = ##class(App.Tools.Security.Effective).Split($get(props("GrantedRoles")))
	}
	do roles.%Set(name, one)
}

ClassMethod Build(raw As %DynamicObject, targets As %DynamicArray = "", assume As %DynamicArray = "") As %DynamicObject
{
	set:'$isobject(targets)||'targets.%Size() targets = ..Targets()
	set:'$isobject(assume) assume = []
	set warnings = []

	set before = ""
	set:assume.%Size() before = ..Build(raw, targets, []).data

	set live = ..Apply(raw, assume, warnings)
	set nodes = [], links = [], idx = {}, hide = {}
	do ..Anonymous(live, nodes, links, idx, warnings)
	do ..Reached(live, targets, nodes, links, idx, hide)

	set out = {"nodes": (nodes), "links": (links), "assumed": (assume), "removed": (..Removed(before, links))}
	set out.counts = ..Counts(nodes, links)
	set out.hidden = {}
	do out.hidden.%Set("resources", ..Keys(hide), "number")
	return {"data": (out), "warnings": (warnings)}
}

ClassMethod Anonymous(raw As %DynamicObject, nodes As %DynamicArray, links As %DynamicArray, idx As %DynamicObject, warnings As %DynamicArray)
{
	set it = raw.webapps.%GetIterator()
	while it.%GetNext(, .app) {
		continue:'..Unauthenticated(app.autheEnabled)
		set reach = [], names = ##class(App.Tools.Security.Effective).Join(app.roles)
		set r = app.roles.%GetIterator()
		while r.%GetNext(, .role) {
			set known = raw.roles.%Get(role)
			continue:'$isobject(known)
			do:known.nested.%Size() warnings.%Push("nested roles of "_role_" not expanded")
			set p = known.resources.%GetIterator()
			while p.%GetNext(, .res) { do reach.%Push(res) }
		}
		continue:'reach.%Size()

		set from = ..Node(nodes, idx, "p:anonymous", 0, "principal", "Anonymous")
		set:'from.%IsDefined("members") from.members = []
		set via = ..Node(nodes, idx, "v:"_app.name, 1, "webapp", app.name, "grants "_names)
		do ..Link(links, idx, "c|"_app.name, from.id, via.id, 1, 1)

		set p = reach.%GetIterator()
		while p.%GetNext(, .res) {
			set to = ..Node(nodes, idx, "r:"_res.resource, 2, "resource", res.resource)
			set to.perm = res.permissions
			set link = ..Link(links, idx, "a|"_app.name_"|"_res.resource, via.id, to.id, 1, 1)
			continue:'$isobject(link)
			set link.keys = [(app.name)]
			set link.severity = "high"
			set link.path = "Anonymous -> "_app.name_" -> "_res.resource
			set link.evidence = "AutheEnabled="_app.autheEnabled_" has bit 6 (Unauthenticated), and a MatchRole of """" hands every request the roles "
				_names_", which carry "_res.resource_":"_res.permissions_". "
				_$select(app.resource = "": "No resource protects the application.", 1: "The resource "_app.resource_" still applies.")
			set link.probe = "GET /api/admin/v2/web-app?name="_app.name_" -> AutheEnabled="_app.autheEnabled
				_", MatchRole """" -> "_names
			set link.fix = {"tool": "webapp.update"}
			set link.fix.args = {"name": (app.name)}
			do link.fix.args.%Set("AutheEnabled", ##class(App.Tools.Insight.Findings).AutheFixed(app.autheEnabled), "number")
		}
	}
}

ClassMethod Reached(raw As %DynamicObject, targets As %DynamicArray, nodes As %DynamicArray, links As %DynamicArray, idx As %DynamicObject, hide As %DynamicObject)
{
	set wanted = ",", it = targets.%GetIterator()
	while it.%GetNext(, .t) { set wanted = wanted_t_"," }

	set groups = {}, order = []
	set it = raw.users.%GetIterator()
	while it.%GetNext(, .user) {
		set paths = ..Paths(user, wanted, hide)
		continue:'paths.%Size()
		set sig = paths.%ToJSON()
		if 'groups.%IsDefined(sig) {
			do groups.%Set(sig, {"members": [], "paths": (paths)})
			do order.%Push(sig)
		}
		do groups.%Get(sig).members.%Push(user.user)
	}

	set it = order.%GetIterator()
	while it.%GetNext(, .sig) {
		set group = groups.%Get(sig), members = group.members
		set weight = members.%Size(), first = members.%Get(0)
		set from = ..Node(nodes, idx, "p:"_first, 0, "principal", ..Label(members))
		set from.members = members
		set fixable = ..FirstOther(members, raw.portal)

		set p = group.paths.%GetIterator()
		while p.%GetNext(, .path) {
			set via = ..Node(nodes, idx, "v:role:"_path.role, 1, "role", "role "_path.role, $select(path.direct: "direct", 1: "inherited"))
			do ..Link(links, idx, "c|"_first_"|"_path.role, from.id, via.id, weight, 0)
			set to = ..Node(nodes, idx, "r:"_path.resource, 2, "resource", path.label)
			set:path.permissions'="" to.perm = path.permissions
			set link = ..Link(links, idx, "u|"_first_"|"_path.role_"|"_path.resource, via.id, to.id, weight, 0)
			continue:'$isobject(link)
			set link.keys = members
			set link.path = from.label_" -> role "_path.role_" -> "_path.label
			set link.evidence = ##class(App.Tools.Security.Effective).Join(members)_" hold "_path.role
				_$select(path.direct: " directly", 1: " through another role")_", and it carries "_path.label_". "
				_$select(weight > 1: "All "_weight_" accounts take the same path.", 1: "")
			set link.probe = "security.user.effective {""username"": """_first_"""} -> "_path.resource_" via "_path.role
			set:path.resource="%All" link.severity = $select(fixable = "": "low", 1: "medium")
			do ..Fix(link, path, fixable)
		}
	}
}

ClassMethod Paths(user As %DynamicObject, wanted As %String, hide As %DynamicObject) As %DynamicArray
{
	set out = []
	if (wanted [ ",%All,") && user.superuser {
		set one = {"role": "%All", "resource": "%All", "label": "everything (%All)", "permissions": ""}
		do one.%Set("direct", ..Direct(user, "%All"), "boolean")
		do out.%Push(one)
	}
	set it = user.privileges.%GetIterator()
	while it.%GetNext(, .p) {
		if '(wanted [ (","_p.resource_",")) {
			do hide.%Set(p.resource, 1)
			continue
		}
		set v = p.via.%GetIterator()
		while v.%GetNext(, .role) {
			set one = {"role": (role), "resource": (p.resource), "label": (p.resource), "permissions": (p.permissions)}
			do one.%Set("direct", ..Direct(user, role), "boolean")
			do out.%Push(one)
		}
	}
	return out
}

ClassMethod Fix(link As %DynamicObject, path As %DynamicObject, fixable As %String)
{
	if fixable = "" {
		set link.noFixReason = "portal's own account: narrowing it is a deployment change, not a button"
	} elseif path.resource '= "%All" {
		set link.noFixReason = "the resource arrives with the role "_path.role_", which the account may hold for other reasons"
	} elseif 'path.direct {
		set link.noFixReason = "%All is inherited through another role, so it comes off that role and not off the account"
	} else {
		set link.fix = {"tool": "security.user.revokeRole", "args": {"username": (fixable), "role": "%All"}}
	}
}

ClassMethod Apply(raw As %DynamicObject, assume As %DynamicArray, warnings As %DynamicArray) As %DynamicObject
{
	return:'assume.%Size() raw
	set raw = ##class(%DynamicAbstractObject).%FromJSON(raw.%ToJSON())
	set it = assume.%GetIterator()
	while it.%GetNext(, .op) {
		set tool = op.%Get("tool"), args = op.%Get("args")
		set:'$isobject(args) args = {}
		if tool = "webapp.update" {
			set app = ..Find(raw.webapps, "name", args.%Get("name"))
			do:$isobject(app)&&args.%IsDefined("AutheEnabled") app.%Set("autheEnabled", +args.AutheEnabled, "number")
		} elseif (tool = "security.user.grantRole") || (tool = "security.user.revokeRole") {
			do ..AssumeRole(raw, args, tool = "security.user.grantRole", warnings)
		} else {
			do warnings.%Push("assume: "_tool_" not modelled")
		}
	}
	return raw
}

ClassMethod AssumeRole(raw As %DynamicObject, args As %DynamicObject, grant As %Boolean, warnings As %DynamicArray)
{
	set user = ..Find(raw.users, "user", args.%Get("username"))
	quit:'$isobject(user)
	set role = args.%Get("role")

	if 'grant {
		set user.roles = ..Without(user.roles, "name", role)
		do:role="%All" user.%Set("superuser", 0, "boolean")
		set kept = [], it = user.privileges.%GetIterator()
		while it.%GetNext(, .p) {
			set p.via = ..Without(p.via, "", role)
			do:p.via.%Size() kept.%Push(p)
		}
		set user.privileges = kept
		quit
	}

	do user.roles.%Push({"name": (role), "direct": true})
	do:role="%All" user.%Set("superuser", 1, "boolean")
	set known = raw.roles.%Get(role)
	if '$isobject(known) {
		do:role'="%All" warnings.%Push("assume: the resources of "_role_" are not known here, only the role itself is added")
		quit
	}
	set it = known.resources.%GetIterator()
	while it.%GetNext(, .res) {
		do user.privileges.%Push({"resource": (res.resource), "permissions": (res.permissions), "via": [(role)]})
	}
}

/// bit 6 is unauthenticated
ClassMethod Unauthenticated(authe As %Integer) As %Boolean
{
	return ''(authe \ 64 # 2)
}

ClassMethod Node(nodes As %DynamicArray, idx As %DynamicObject, id As %String, col As %Integer, kind As %String, label As %String, sub As %String = "") As %DynamicObject
{
	return:idx.%IsDefined(id) idx.%Get(id)
	set n = {"id": (id), "kind": (kind), "label": (label)}
	do n.%Set("col", col, "number")
	set:sub'="" n.sub = sub
	do nodes.%Push(n)
	do idx.%Set(id, n)
	return n
}

ClassMethod Link(links As %DynamicArray, idx As %DynamicObject, id As %String, from As %String, to As %String, weight As %Integer, anonymous As %Boolean) As %DynamicObject
{
	return:idx.%IsDefined("l:"_id) ""
	set l = {"id": (id), "from": (from), "to": (to)}
	do l.%Set("weight", weight, "number")
	do l.%Set("anonymous", ''anonymous, "boolean")
	do links.%Push(l)
	do idx.%Set("l:"_id, l)
	return l
}

ClassMethod Direct(user As %DynamicObject, role As %String) As %Boolean
{
	set it = user.roles.%GetIterator()
	while it.%GetNext(, .r) { return:r.name=role ''r.direct }
	return 0
}

ClassMethod FirstOther(members As %DynamicArray, portal As %String) As %String
{
	set it = members.%GetIterator()
	while it.%GetNext(, .m) { return:m'=portal m }
	return ""
}

ClassMethod Label(members As %DynamicArray) As %String
{
	set label = "", n = 0, it = members.%GetIterator()
	while it.%GetNext(, .m) {
		set n = n + 1
		quit:n>2
		set label = label_$select(label = "": "", 1: ", ")_m
	}
	return label_$select(members.%Size() > 2: " +"_(members.%Size() - 2), 1: "")
}

ClassMethod Find(list As %DynamicArray, key As %String, value As %String) As %DynamicObject
{
	set it = list.%GetIterator()
	while it.%GetNext(, .one) { return:one.%Get(key)=value one }
	return ""
}

ClassMethod Without(list As %DynamicArray, key As %String, value As %String) As %DynamicArray
{
	set out = [], it = list.%GetIterator()
	while it.%GetNext(, .one) {
		set found = $select(key = "": one, 1: one.%Get(key))
		continue:found=value
		do out.%Push(one)
	}
	return out
}

ClassMethod Removed(before As %DynamicObject, links As %DynamicArray) As %DynamicArray
{
	set out = []
	return:'$isobject(before) out
	set now = {}, it = links.%GetIterator()
	while it.%GetNext(, .l) { do now.%Set(l.id, 1) }
	set it = before.links.%GetIterator()
	while it.%GetNext(, .l) { do:'now.%IsDefined(l.id) out.%Push(l.id) }
	return out
}

ClassMethod Counts(nodes As %DynamicArray, links As %DynamicArray) As %DynamicObject
{
	set c = {"anonymousPaths": 0, "principals": 0, "targets": 0}
	set it = nodes.%GetIterator()
	while it.%GetNext(, .n) {
		do:n.col=0 c.%Set("principals", c.principals + 1, "number")
		do:n.col=2 c.%Set("targets", c.targets + 1, "number")
	}
	set it = links.%GetIterator()
	while it.%GetNext(, .l) {
		do:l.anonymous&&l.%IsDefined("path") c.%Set("anonymousPaths", c.anonymousPaths + 1, "number")
	}
	return c
}

ClassMethod Keys(obj As %DynamicObject) As %Integer
{
	set n = 0, it = obj.%GetIterator()
	while it.%GetNext() { set n = n + 1 }
	return n
}

}
