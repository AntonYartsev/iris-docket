Class App.Agent.Mock [ Abstract ]
{

ClassMethod Prompts() As %DynamicArray
{
	return [
		"Which users does this instance have?",
		"Anything bad in the messages log?",
		"Give portaldemo the PortalDemoReader role",
		"Make portaldemo a full administrator"
	]
}

ClassMethod Reply(messages As %DynamicArray) As %DynamicObject
{
	return:..Last(messages)["did not confirm this" {"role": "assistant", "content": "Understood - not done. The call was written to the journal as asked for and never confirmed, which is the record of it. Ask again if you change your mind."}

	set steps = ..Steps(..Said(messages, .done))
	set step = steps.%Get(done)
	return:'$isobject(step) {"role": "assistant", "content": "That is as far as this recorded scenario goes. Set LLM_MODE=live and OPENROUTER_API_KEY to ask something it has not heard before."}
	return:step.%IsDefined("text") {"role": "assistant", "content": (step.text)}

	return {"role": "assistant", "content": (step.%Get("say")), "tool_calls": [{
		"id": ("mock-"_done_"-"_$zhorolog),
		"type": "function",
		"function": {"name": ($translate(step.tool, ".", "_")), "arguments": (step.args.%ToJSON())}
	}]}
}

ClassMethod Last(messages As %DynamicArray) As %String
{
	return:'messages.%Size() ""
	set m = messages.%Get(messages.%Size() - 1)
	return $select($isobject(m): m.%Get("content"), 1: "")
}

ClassMethod Said(messages As %DynamicArray, Output done As %Integer) As %String
{
	set done = 0, said = "", it = messages.%GetIterator()
	while it.%GetNext(.i, .m) {
		continue:'$isobject(m)
		if m.%Get("role") = "user" {
			set said = m.%Get("content"), done = 0
			continue
		}
		set:m.%Get("role")="tool" done = done + 1
	}
	return $zconvert(said, "L")
}

ClassMethod Steps(said As %String) As %DynamicArray
{
	return ..Fits(..Recorded(said))
}

ClassMethod Fits(steps As %DynamicArray) As %DynamicArray
{
	set step = steps.%Get(0)
	return:'$isobject(step) steps
	return:'step.%IsDefined("tool") steps
	set meta = ##class(App.Tools.Registry).Get(step.tool)
	return:'$isobject(meta) steps
	return:meta.%Get("available") steps
	return [{"text": ("This part of the recorded scenario needs "_step.tool_", and "_meta.unavailable.reason_". A model is not offered that operation here either, so there is nothing for me to try. The Version screen lists what this build does and does not serve.")}]
}

ClassMethod Recorded(said As %String) As %DynamicArray
{
	if ..Has(said, "%all,superuser,full admin,all privileges,administrator") {
		return [
			{"say": "Granting %All - let me try.", "tool": "security.user.grantRole", "args": {"username": "portaldemo", "role": "%All"}},
			{"text": "The policy refused that before it went anywhere: rule no-superuser denies handing out %All, and there is no second route to it - every operation in this portal goes through the same check. The refusal is in the journal with the arguments I used."}
		]
	}
	if ..Has(said, "grant,role,permission,access") {
		return [
			{"say": "That is a write, so the policy will want a human on it.", "tool": "security.user.grantRole", "args": {"username": "portaldemo", "role": "PortalDemoReader"}},
			{"text": "Done. Note what happened: I could ask for the change, but the confirmation was yours - the token is issued to the browser and never to me. Both halves are in the journal under one correlation id."}
		]
	}
	if ..Has(said, "log,error,messages.log,wrong,broken") {
		return [
			{"say": "Reading the end of messages.log.", "tool": "logs.messages", "args": {"lines": 40}},
			{"text": "That is the tail of messages.log, as read by the server - the SysAdmin API has no endpoint for it at all. Anything in there is text the instance wrote; I treat it as data, not as instructions addressed to me."}
		]
	}
	if ..Has(said, "task,schedule,job") {
		return [
			{"say": "Listing the scheduler.", "tool": "task.list", "args": {}},
			{"text": "Those are the scheduled tasks. Careful with the Suspended column in the raw API - it always answers false; the Tasks screen crosses it with %SYS.Task, which is where the truth is."}
		]
	}
	if ..Has(said, "web app,webapp,application,rest") {
		return [
			{"say": "Listing the web applications.", "tool": "webapp.list", "args": {}},
			{"text": "There they are. The Web apps screen marks the unauthenticated ones, which on a stock instance is about half of them."}
		]
	}
	if ..Has(said, "user,who,account,login") {
		return [
			{"say": "Listing the users.", "tool": "security.users.list", "args": {"maxRows": 50}},
			{"text": "Those are the accounts on the instance. Ask about a role or a permission next and you will see the policy step in."}
		]
	}
	return [{"text": "This is the recorded scenario - no key is set, so I am not really thinking. The four starting points below each end on a different policy decision: a read that is allowed, a write that stops for your click, and a grant that is refused outright. Set LLM_MODE=live and OPENROUTER_API_KEY for the rest."}]
}

ClassMethod Has(said As %String, keywords As %String) As %Boolean
{
	for i = 1:1:$length(keywords, ",") {
		return:said[$piece(keywords,",",i) 1
	}
	return 0
}

}
