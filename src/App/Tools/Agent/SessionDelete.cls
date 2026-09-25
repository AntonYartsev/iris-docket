Class App.Tools.Agent.SessionDelete Extends App.Tools.Base
{

Parameter ToolName = "agent.session.delete";

Parameter Title = "Delete one of the agent console's conversations";

Parameter Category = "agent";

Parameter Mutating = 1;

Parameter Privilege = "";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "required": ["sessionId"],
  "properties": {
    "sessionId": { "type": "string", "title": "Conversation" }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set n = ##class(App.Agent.Session).Delete(args.sessionId)
	return {"data": {"sessionId": (args.sessionId), "messages": (n)}}
}

}
