Class App.Tools.Security.Effective Extends App.Tools.Base
{

Parameter ToolName = "security.user.effective";

Parameter Title = "Effective roles and privileges of a user";

Parameter Category = "security";

Parameter Mutating = 0;

Parameter Requires = "GET /v2/security/user";

Parameter Privilege = "%Admin_Secure:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["username"],
  "properties": {
    "username": { "type": "string", "title": "User" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	return {"data": (..Expand(args.username))}
}

ClassMethod Expand(username As %String) As %DynamicObject
{

	set user = ##class(App.Admin.Client).Call("GET", "/v2/security/user", {"name": (username)}).data
	set direct = ","_..Join(user.%Get("Roles"))_","

	set sc = $system.Security.GetUserRecursedRoleSet(username, .recursed)
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("tool_error", "cannot expand the roles of "_username_": "_$system.Status.GetErrorText(sc))

	set out = {"user": (username), "roles": [], "privileges": []}
	do out.%Set("superuser", ","_recursed_"," [ ",%All,", "boolean")
	set out.escalationRoles = user.%Get("EscalationRoles")

	for i = 1:1:$length(recursed, ",") {
		set name = $piece(recursed, ",", i)
		continue:name=""
		kill props
		set found = $system.Status.IsOK(##class(Security.Roles).Get(name, .props))

		set role = {"name": (name)}
		do role.%Set("direct", ''(direct [ (","_name_",")), "boolean")
		set role.description = $get(props("Description"))
		set role.grants = ..Split($get(props("GrantedRoles")))
		do out.roles.%Push(role)

		continue:'found
		set list = $get(props("Resources"))
		for j = 1:1:$length(list, ",") {
			set one = $piece(list, ",", j)
			continue:one=""
			set resource = $piece(one, ":", 1)
			set perms = $get(acc(resource))
			for k = 1:1:$length($piece(one, ":", 2)) {
				set c = $extract($piece(one, ":", 2), k)
				set:perms'[c perms = perms_c
			}
			set acc(resource) = perms
			set via(resource, name) = ""
		}
	}

	set resource = ""
	for {
		set resource = $order(acc(resource))
		quit:resource=""
		set p = {"resource": (resource), "permissions": (acc(resource)), "via": []}
		set name = ""
		for {
			set name = $order(via(resource, name))
			quit:name=""
			do p.via.%Push(name)
		}
		do out.privileges.%Push(p)
	}

	return out
}

ClassMethod Join(array As %DynamicArray) As %String
{
	return:'$isobject(array) ""
	set s = "", it = array.%GetIterator()
	while it.%GetNext(.i, .v) {
		set s = s_$select(s = "": "", 1: ",")_v
	}
	return s
}

ClassMethod Split(csv As %String) As %DynamicArray
{
	set out = []
	for i = 1:1:$length(csv, ",") {
		set v = $piece(csv, ",", i)
		do:v'="" out.%Push(v)
	}
	return out
}

}
