Class App.Policy.Engine [ Abstract ]
{

XData Default [ MimeType = application/json ]
{
{
  "version": 1,
  "default": "deny",
  "redact": ["args.Password", "args.NewPassword", "args.User.Password", "args.password", "args.secret"],
  "rules": [
    { "id": "read-all",         "match": { "mutating": false },                                "decision": "allow" },
    { "id": "no-superuser",     "match": { "tool": "security.user.grantRole", "args.role": "%All" }, "decision": "deny" },
    { "id": "no-system-roles",  "match": { "tool": "security.role.save", "args.name": "%*" },    "decision": "deny" },
    { "id": "chat-not-agent",   "match": { "tool": "agent.session.delete", "actor": "agent:*" },"decision": "deny" },
    { "id": "chat-delete-ask",  "match": { "tool": "agent.session.delete" },                   "decision": "confirm" },
    { "id": "no-delete",        "match": { "tool": "*.delete" },                               "decision": "deny" },
    { "id": "no-lockout-ui",    "match": { "tool": "webapp.update", "args.name": "/portal" },   "decision": "deny" },
    { "id": "no-lockout-api",   "match": { "tool": "webapp.update", "args.name": "/portal/api" },"decision": "deny" },
    { "id": "no-self-uninstall","match": { "tool": "packages.uninstall", "args.name": "docket" }, "decision": "deny" },
    { "id": "packages-not-agent","match": { "tool": "packages.*", "actor": "agent:*", "mutating": true }, "decision": "deny" },
    { "id": "packages-change-ask","match": { "tool": "packages.*", "mutating": true },          "decision": "confirm" },
    { "id": "agent-writes-ask", "match": { "actor": "agent:*", "mutating": true },             "decision": "confirm" },
    { "id": "write-ask",        "match": { "mutating": true },                                 "decision": "confirm" }
  ]
}
}

ClassMethod Config() As %DynamicObject
{
	if '$data(^App.Policy("config")) {
		set x = ##class(%Dictionary.CompiledXData).%OpenId($classname()_"||Default")
		do x.Data.Rewind()
		set ^App.Policy("config") = x.Data.Read(32000)
	}
	return ##class(%DynamicAbstractObject).%FromJSON(^App.Policy("config"))
}

ClassMethod Save(config As %DynamicObject, by As %String) As %DynamicObject
{
	do ..Validate(config)
	set cur = ..Seed()
	do config.%Set("version", +cur.version + 1, "number")
	do ..Archive(config, by)
	set ^App.Policy("config") = config.%ToJSON()
	return config
}

ClassMethod Seed() As %DynamicObject
{
	set cfg = ..Config()
	do:'$data(^App.Policy("versions", +cfg.version)) ..Archive(cfg, "default")
	return cfg
}

ClassMethod Archive(config As %DynamicObject, by As %String)
{
	set ^App.Policy("versions", +config.version) = {"version": (+config.version), "savedAt": ($zdatetime($ztimestamp, 3, 1, 3)), "savedBy": (by), "config": (config)}.%ToJSON()
}

ClassMethod Versions() As %DynamicArray
{
	do ..Seed()
	set out = [], v = ""
	for {
		set v = $order(^App.Policy("versions", v), -1)
		quit:v=""
		do out.%Push(##class(%DynamicAbstractObject).%FromJSON(^App.Policy("versions", v)))
	}
	return out
}

ClassMethod Validate(cfg As %DynamicObject)
{
	do:'..IsObject(cfg) ##class(App.Err).Throw("bad_request", "the policy has to be a JSON object")
	set decisions = $listbuild("allow", "confirm", "deny"), bad = []
	do:'$listfind(decisions, cfg.%Get("default")) bad.%Push("default: has to be allow, confirm or deny")

	if '($isobject(cfg.%Get("rules")) && cfg.rules.%IsA("%Library.DynamicArray")) {
		do bad.%Push("rules: has to be an array")
	} else {
		set tools = ##class(App.Tools.Registry).List()
		set it = cfg.rules.%GetIterator()
		while it.%GetNext(.i, .rule) {
			set at = "rules["_i_"]"
			if '..IsObject(rule) {
				do bad.%Push(at_": has to be an object")
				continue
			}
			set id = rule.%Get("id")
			do:id="" bad.%Push(at_": needs an id")
			do:(id'="")&&$data(seen(id)) bad.%Push(at_": duplicate id '"_id_"'")
			set:id'="" seen(id) = ""
			do:'$listfind(decisions, rule.%Get("decision")) bad.%Push(at_" "_id_": decision has to be allow, confirm or deny")
			if '..IsObject(rule.%Get("match")) {
				do bad.%Push(at_" "_id_": needs a match object")
				continue
			}
			set mi = rule.match.%GetIterator()
			while mi.%GetNext(.k, .v) {
				if $listfind($listbuild("tool", "actor", "channel", "mutating", "privilege"), k) {
					do:(k="tool")&&'..Resolves(v, tools) bad.%Push(at_" "_id_": no tool in the registry matches '"_v_"'")
					continue
				}
				do:$extract(k, 1, 5)'="args." bad.%Push(at_" "_id_": unknown matcher '"_k_"' - it would never match, which quietly disables the rule")
			}
		}
	}

	if cfg.%IsDefined("redact") {
		if '($isobject(cfg.redact) && cfg.redact.%IsA("%Library.DynamicArray")) {
			do bad.%Push("redact: has to be an array of argument paths")
		} else {
			set ri = cfg.redact.%GetIterator()
			while ri.%GetNext(.i, .path) {
				do:$extract(path, 1, 5)'="args." bad.%Push("redact["_i_"]: '"_path_"' does not start with args.")
			}
		}
	}

	// dont let policy lock itself
	set self = ##class(App.Tools.Registry).Get("policy.update")
	if bad.%Size() = 0, $isobject(self), ..DecideWith(cfg, self, {}, "user:"_$username, "ui").decision = "deny" {
		do bad.%Push("this policy denies policy.update - nothing would be able to edit it back")
	}

	do:bad.%Size() ##class(App.Err).Throw("bad_request", "this policy has "_bad.%Size()_" problem(s)", {"problems": (bad)})
}

ClassMethod IsObject(v) As %Boolean
{
	return $isobject(v) && v.%IsA("%Library.DynamicObject")
}

ClassMethod Resolves(glob As %String, tools As %DynamicArray) As %Boolean
{
	set it = tools.%GetIterator()
	while it.%GetNext(.i, .t) {
		return:..Glob(glob, t.name) 1
	}
	return 0
}

ClassMethod Decide(meta As %DynamicObject, args As %DynamicObject, actor As %String, channel As %String) As %DynamicObject
{
	return ..DecideWith(..Config(), meta, args, actor, channel)
}

ClassMethod DecideWith(cfg As %DynamicObject, meta As %DynamicObject, args As %DynamicObject, actor As %String, channel As %String) As %DynamicObject
{
	set it = cfg.rules.%GetIterator()
	while it.%GetNext(.i, .rule) {
		continue:'..Matches(rule.%Get("match"), meta, args, actor, channel)
		return {"decision": (rule.decision), "ruleId": (rule.id)}
	}
	return {"decision": (cfg.default), "ruleId": "default"}
}

ClassMethod Matches(m As %DynamicObject, meta As %DynamicObject, args As %DynamicObject, actor As %String, channel As %String) As %Boolean
{
	return:'$isobject(m) 0
	set it = m.%GetIterator()
	while it.%GetNext(.k, .v, .t) {
		set got = $case(k, "tool": meta.name, "actor": actor, "channel": channel, "privilege": meta.privilege, "mutating": ''meta.mutating, :..Arg(args, k))
		if t = "boolean" {
			return:got'=(''v) 0
			continue
		}
		return:'..Glob(v, got) 0
	}
	return 1
}

ClassMethod Arg(args As %DynamicObject, path As %String) As %String
{
	return:$extract(path, 1, 5)'="args." ""
	set node = args
	for i = 2:1:$length(path, ".") {
		quit:'$isobject(node)
		set node = node.%Get($piece(path, ".", i))
	}
	return $select($isobject(node): "", 1: node)
}

ClassMethod Glob(pattern As %String, value As %String) As %Boolean
{
	return:pattern="*" 1
	return:pattern'["*" (pattern = value)
	set re = ""
	for i = 1:1:$length(pattern) {
		set c = $extract(pattern, i)
		set re = re_$select(c = "*": ".*", c?1(1A,1N): c, 1: "\"_c)
	}
	return ##class(%Regex.Matcher).%New("^"_re_"$", value).Locate()
}

ClassMethod Redact(canonicalJson As %String) As %String
{
	set cfg = ..Config()
	return:'$isobject(cfg.%Get("redact")) canonicalJson
	set obj = ##class(%DynamicAbstractObject).%FromJSON(canonicalJson)
	set it = cfg.redact.%GetIterator()
	while it.%GetNext(.i, .path) {
		set n = $length(path, ".")
		continue:n<2
		set node = obj
		for i = 2:1:n-1 {
			set node = node.%Get($piece(path, ".", i))
			quit:'$isobject(node)
		}
		continue:'$isobject(node)
		set key = $piece(path, ".", n)
		do:node.%IsDefined(key) node.%Set(key, "***")
	}
	return obj.%ToJSON()
}

}
