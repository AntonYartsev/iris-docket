/// api lies about Suspended.. D-15
Class App.Tools.Task.States Extends App.Tools.Base
{

Parameter ToolName = "task.states";

Parameter Title = "The suspended flag of every task, read from %SYS.Task";

Parameter Category = "task";

Parameter Mutating = 0;

Parameter Privilege = "%Admin_Task:U";

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {}
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set out = []
	set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID,Suspended FROM %SYS.Task ORDER BY ID")
	do:rs.%SQLCODE<0 ##class(App.Err).Throw("tool_error", "cannot read %SYS.Task: "_rs.%Message)
	while rs.%Next() {
		set one = {"id": (+rs.ID)}
		do one.%Set("suspended", ''rs.Suspended, "boolean")
		set one.mode = $case(+rs.Suspended, 1: "left in the task queue", 2: "removed from the queue and rescheduled", : "")
		do out.%Push(one)
	}
	return {"data": (out)}
}

}
