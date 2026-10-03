Class App.Agent.Session [ Abstract ]
{

Parameter MaxMessages = 60;

ClassMethod New() As %String
{
	set id = $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(12), 1)
	set id = $translate(id, "+/=", "-_")
	set ^App.Agent("s", id, "n") = 0
	return id
}

ClassMethod Exists(id As %String) As %Boolean
{
	return:id="" 0
	return ''$data(^App.Agent("s", id, "n"))
}

ClassMethod Append(id As %String, msg As %DynamicObject)
{
	set n = $get(^App.Agent("s", id, "n")) + 1
	set ^App.Agent("s", id, n) = msg.%ToJSON()
	set ^App.Agent("s", id, "n") = n
	set ^App.Agent("s", id, "ts") = $zdatetime($ztimestamp, 3, 1, 3)
	do:(msg.%Get("role")="user")&&('$data(^App.Agent("s",id,"title"))) ..Title(id, msg.%Get("content"))
	kill:n>..#MaxMessages ^App.Agent("s", id, n - ..#MaxMessages)
}

ClassMethod Title(id As %String, text As %String)
{
	set ^App.Agent("s", id, "title") = $extract($zstrip(text, "<>W"), 1, 120)
}

ClassMethod List() As %DynamicArray
{
	set out = [], id = ""
	for {
		set id = $order(^App.Agent("s", id))
		quit:id=""
		set n = +$get(^App.Agent("s", id, "n"))
		continue:n=0
		do:'$data(^App.Agent("s", id, "title")) ..Name(id, n)
		do out.%Push({"id": (id), "title": ($get(^App.Agent("s", id, "title"), "untitled")), "updatedAt": ($get(^App.Agent("s", id, "ts"))), "messages": (n)})
	}
	return out
}

ClassMethod Messages(id As %String) As %DynamicArray
{
	set out = [], i = ""
	for {
		set i = $order(^App.Agent("s", id, i))
		quit:i=""
		continue:i'=+i
		do out.%Push(##class(%DynamicAbstractObject).%FromJSON(^App.Agent("s", id, i)))
	}
	return out
}

ClassMethod Name(id As %String, n As %Integer)
{
	for i = 1:1:n {
		continue:'$data(^App.Agent("s", id, i))
		set m = ##class(%DynamicAbstractObject).%FromJSON(^App.Agent("s", id, i))
		continue:m.%Get("role")'="user"
		do ..Title(id, m.%Get("content"))
		quit
	}
	set:'$data(^App.Agent("s", id, "title")) ^App.Agent("s", id, "title") = "untitled"
}

ClassMethod Clean(messages As %DynamicArray) As %DynamicArray
{
	set out = [], it = messages.%GetIterator()
	while it.%GetNext(.i, .m) {
		// api reject the note role
		continue:m.%Get("role")="note"
		// orphan tool results gets refused
		continue:(m.%Get("role")="tool")&&('$data(asked(m.%Get("tool_call_id"))))
		set calls = m.%Get("tool_calls")
		if $isobject(calls) {
			set ci = calls.%GetIterator()
			while ci.%GetNext(.k, .call) {
				set asked(call.%Get("id")) = ""
			}
		}
		set c = {}
		for key = "role", "content", "tool_calls", "tool_call_id", "name" {
			do:m.%IsDefined(key) c.%Set(key, m.%Get(key))
		}
		do out.%Push(c)
	}
	return out
}

ClassMethod SetPending(id As %String, pending As %DynamicObject)
{
	set ^App.Agent("s", id, "pending") = pending.%ToJSON()
}

ClassMethod Pending(id As %String) As %DynamicObject
{
	return:'$data(^App.Agent("s", id, "pending")) ""
	return ##class(%DynamicAbstractObject).%FromJSON(^App.Agent("s", id, "pending"))
}

ClassMethod Delete(id As %String) As %Integer
{
	do:id="" ##class(App.Err).Throw("bad_request", "no conversation was named")
	do:'..Exists(id) ##class(App.Err).Throw("not_found", "this instance has no conversation "_id)
	set n = +$get(^App.Agent("s", id, "n"))
	kill ^App.Agent("s", id)
	return n
}

ClassMethod Model(id As %String, model As %String = "") As %String
{
	set:model'="" ^App.Agent("s", id, "model") = model
	return $get(^App.Agent("s", id, "model"))
}

ClassMethod ClearPending(id As %String)
{
	kill ^App.Agent("s", id, "pending")
}

}
