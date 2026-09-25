Class App.Tools.Security.RoleChange Extends App.Tools.Base [ Abstract ]
{

Parameter Category = "security";

Parameter Requires = "GET /v2/security/user, PUT /v2/security/user";

Parameter Mutating = 1;

Parameter Privilege = "%Admin_Secure:U";

Parameter Adds As BOOLEAN = 1;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["username", "role"],
  "properties": {
    "username": { "type": "string", "title": "User" },
    "role": { "type": "string", "title": "Role" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set username = args.username, role = args.role

	// PUT back the whole user
	set user = ##class(App.Admin.Client).Call("GET", "/v2/security/user", {"name": (username)}).data
	set current = user.%Get("Roles")
	set:'$isobject(current) current = []

	set next = [], had = 0
	set it = current.%GetIterator()
	while it.%GetNext(.i, .r) {
		if r = role { set had = 1 continue }
		do next.%Push(r)
	}
	do:..#Adds next.%Push(role)

	if had = ..#Adds {
		return {"data": (user), "warnings": [($select(had: username_" already has "_role, 1: username_" does not have "_role_" to begin with"))]}
	}

	do user.%Set("Roles", next)
	return ##class(App.Admin.Client).Call("PUT", "/v2/security/user", {"name": (username)}, user)
}

}
