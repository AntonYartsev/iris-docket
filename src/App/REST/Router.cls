Class App.REST.Router Extends %CSP.REST
{

Parameter HandleCorsRequest = 0;

Parameter UseSession = 1;

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/info" Method="GET" Call="Info"/>
<Route Url="/logout" Method="POST" Call="Logout"/>
<Route Url="/tools" Method="GET" Call="Tools"/>
<Route Url="/openapi.json" Method="GET" Call="OpenApi"/>
<Route Url="/tools/:name/invoke" Method="POST" Call="Invoke"/>
<Route Url="/policy" Method="GET" Call="Policy"/>
<Route Url="/policy/simulate" Method="POST" Call="Simulate"/>
<Route Url="/audit" Method="GET" Call="Audit"/>
<Route Url="/audit/verify" Method="GET" Call="Verify"/>
<Route Url="/audit/export" Method="GET" Call="Export"/>
<Route Url="/agent/sessions" Method="GET" Call="AgentSessions"/>
<Route Url="/agent/session" Method="GET" Call="AgentSession"/>
<Route Url="/agent/session/:id" Method="GET" Call="AgentSession"/>
<Route Url="/agent/turn" Method="POST" Call="AgentTurn"/>
</Routes>
}

ClassMethod Info() As %Status
{
	try {
		set caps = ##class(App.Admin.Capabilities).Probe($get(%request.Data("refresh", 1)))
		set info = ##class(App.Admin.Client).Info()
		set portal = {}
		set portal.instanceName = ##class(%SYS.System).GetInstanceName()
		set portal.host = $system.INetInfo.LocalHostName()
		set portal.roles = $roles
		set portal.agentMode = ##class(App.Agent.Llm).Mode()
		set portal.capabilities = caps
		set portal.now = $zdatetime($horolog, 3), portal.utc = $zdatetime($ztimestamp, 3)
		return ..Ok({"data": {"user": ($username), "instance": (info), "portal": (portal)}})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Logout() As %Status
{
	set %session.EndSession = 1
	return ..Ok({"data": {"signedOut": true}})
}

ClassMethod Tools() As %Status
{
	try {
		do:$get(%request.Data("refresh", 1)) ##class(App.Tools.Registry).Build()
		return ..Ok({"data": (##class(App.Tools.Registry).List($get(%request.Data("category", 1))))})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod OpenApi() As %Status
{
	try {
		set paths = {}
		set it = ##class(App.Tools.Registry).List().%GetIterator()
		while it.%GetNext(, .m) {
			set op = {"operationId": (m.name), "tags": [(m.category)]}
			set op.summary = m.title
			set op.description = m.title_$char(10,10)
				_"Upstream: "_m.method_" "_m.path_$char(10)
				_"Requires at least: "_$select(m.privilege="": "nothing declared", 1: m.privilege)_$char(10)
				_$select(''m.mutating: "Mutating: the policy may answer 409 with a confirmation token, which a human spends.", 1: "Read-only.")
			set op.requestBody = {"required": true, "content": {"application/json": {"schema": {"type": "object", "properties": {"args": (m.schema), "confirmToken": {"type": "string", "description": "The token from a previous 409. Bound to a hash of these arguments, single use."}}}}}}
			set op.responses = {
				"200": {"description": "The tool ran. meta carries the journal row it left."},
				"409": {"description": "The policy asks for a human. detail.confirmToken is the token to spend."},
				"403": {"description": "The policy refused. The refusal is in the journal too."}
			}
			do paths.%Set("/tools/"_m.name_"/invoke", {"post": (op)})
		}
		return ..Ok({
			"openapi": "3.1.0",
			"info": {"title": "Docket - tool registry", "version": "1", "description": "Every operation the portal can perform, as the portal itself declares them. The UI, the agent console and a script all go through these and through nothing else."},
			"servers": [{"url": "/portal/api"}],
			"paths": (paths)
		})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Invoke(name As %String) As %Status
{
	try {
		set body = ..Payload()
		return ..Ok(##class(App.Tools.Invoker).Run(name, body.%Get("args"), , "ui", body.%Get("confirmToken")))
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Policy() As %Status
{
	try {
		return ..Ok({"data": {"config": (##class(App.Policy.Engine).Config()), "versions": (##class(App.Policy.Engine).Versions())}})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Simulate() As %Status
{
	try {
		set body = ..Payload()
		set actor = body.%Get("actor")
		set:actor="" actor = "user:"_$username
		return ..Ok({"data": (##class(App.Tools.Invoker).Simulate(body.%Get("tool"), body.%Get("args"), actor, $select(body.%Get("channel")="": "ui", 1: body.channel)))})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Audit() As %Status
{
	try {
		set limit = +$get(%request.Data("limit", 1), 100)
		set:(limit'>0)||(limit>500) limit = 100
		set q = $zconvert($get(%request.Data("q", 1)), "U")
		set decision = $get(%request.Data("decision", 1))
		set corr = $get(%request.Data("correlationId", 1))
		set before = +$get(%request.Data("before", 1))
		set who = $case($get(%request.Data("actor", 1)), "agent": "agent:", "user": "user:", : "")
		set reads = ""
		if $get(%request.Data("changes", 1)) {
			set it = ##class(App.Tools.Registry).List().%GetIterator()
			while it.%GetNext(, .m) {
				set:'m.mutating reads = reads_","_m.name
			}
			set reads = reads_","
		}
		set items = []
		// [ is contains, LIKE eats %
		set sql = "SELECT TOP ? Seq,Ts,Actor,Channel,CorrelationId,Tool,Args,Decision,RuleId,Outcome,ErrorText,DurationMs,AsyncId,Hash,PrevHash FROM App_Audit.Entry"
			_" WHERE (? = 0 OR Decision = ?) AND (? = 0 OR CorrelationId = ?)"
			_" AND (? = 0 OR UPPER(COALESCE(Tool,'')||' '||COALESCE(Actor,'')||' '||COALESCE(Args,'')||' '||COALESCE(RuleId,'')||' '||COALESCE(Outcome,'')||' '||COALESCE(ErrorText,'')||' '||COALESCE(AsyncId,'')) [ ?)"
			_" AND (? = 0 OR Seq < ?)"
			_" AND (? = 0 OR Actor %STARTSWITH ?)"
			_" AND (? = 0 OR Decision <> 'allow' OR NOT (? [ (','||Tool||',')))"
			_" ORDER BY Seq DESC"
		set rs = ##class(%SQL.Statement).%ExecDirect(, sql, limit, $length(decision)>0, decision, $length(corr)>0, corr, $length(q)>0, q, before>0, before, $length(who)>0, who, $length(reads)>0, reads)
		do:rs.%SQLCODE<0 ##class(App.Err).Throw("internal", "the journal query failed: "_rs.%Message)
		while rs.%Next() {
			set e = {}
			set e.seq = rs.Seq, e.ts = rs.Ts, e.actor = rs.Actor, e.channel = rs.Channel
			set e.correlationId = rs.CorrelationId, e.tool = rs.Tool, e.decision = rs.Decision
			set e.ruleId = rs.RuleId, e.outcome = rs.Outcome, e.errorText = rs.ErrorText
			set e.durationMs = rs.DurationMs, e.asyncId = rs.AsyncId
			set e.hash = rs.Hash, e.prevHash = rs.PrevHash
			set e.args = ##class(%DynamicAbstractObject).%FromJSON($select(rs.Args="": "{}", 1: rs.Args))
			do items.%Push(e)
		}
		return ..Ok({"data": (items)})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod AgentSessions() As %Status
{
	try {
		return ..Ok({"data": (##class(App.Agent.Session).List())})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod AgentSession(id As %String = "") As %Status
{
	try {
		return ..Ok({"data": (##class(App.Agent.Loop).State($select(##class(App.Agent.Session).Exists(id): id, 1: ##class(App.Agent.Session).New())))})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod AgentTurn() As %Status
{
	try {
		set body = ..Payload()
		return ..Ok({"data": (##class(App.Agent.Loop).Turn(body.%Get("sessionId"), body.%Get("message"), body.%Get("confirmToken"), ''body.%Get("decline")))})
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Export() As %Status
{
	try {
		return ..Ok(##class(App.Tools.Invoker).Run("audit.export"))
	} catch ex {
		return ..Failed(ex)
	}
}

ClassMethod Verify() As %Status
{
	try {
		return ..Ok(##class(App.Tools.Invoker).Run("audit.verifyChain"))
	} catch ex {
		return ..Failed(ex)
	}
}

/// body allways comes as bytes
ClassMethod Payload() As %DynamicObject
{
	return:'$isobject(%request.Content) {}
	try {
		do %request.Content.Rewind()
		set text = ""
		while '%request.Content.AtEnd {
			set text = text_%request.Content.Read(32000)
		}
		set body = ##class(%DynamicAbstractObject).%FromJSON($zconvert(text, "I", "UTF8"))
	} catch {
		do ##class(App.Err).Throw("bad_request", "the request body is not valid JSON")
	}
	return $select($isobject(body): body, 1: {})
}

ClassMethod Ok(payload As %DynamicObject, status As %String = "200 OK") As %Status
{
	set %response.Status = status
	set %response.ContentType = "application/json"
	write payload.%ToJSON()
	return $$$OK
}

ClassMethod Failed(ex As %Exception.AbstractException) As %Status
{
	set http = $select(ex.%IsA("App.Err"): +ex.Code, 1: 500)
	return ..Ok(##class(App.Err).Json(ex), http_" "_$case(http, 400:"Bad Request", 403:"Forbidden", 404:"Not Found", 409:"Conflict", 501:"Not Implemented", :"Internal Server Error"))
}

}
