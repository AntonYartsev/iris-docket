Class App.Agent.Llm [ Abstract ]
{

Parameter Host = "openrouter.ai";

Parameter Path = "/api/v1/chat/completions";

Parameter DefaultModel = "anthropic/claude-sonnet-4.5";

/// what the console may switch to, OPENROUTER_MODELS replaces it
Parameter Models = "anthropic/claude-sonnet-4.5,openai/gpt-4.1-mini,google/gemini-2.5-flash,meta-llama/llama-3.3-70b-instruct";

Parameter MaxTokens = 1500;

ClassMethod Mode() As %String
{
	return $select(($zconvert($system.Util.GetEnviron("LLM_MODE"), "L") = "live") && (..Key() '= ""): "live", 1: "mock")
}

ClassMethod Key() As %String
{
	return $system.Util.GetEnviron("OPENROUTER_API_KEY")
}

ClassMethod Model() As %String
{
	set m = $system.Util.GetEnviron("OPENROUTER_MODEL")
	return $select(m '= "": m, 1: ..#DefaultModel)
}

/// the key is the server's, so the browser picks only from this list. Default model always first
ClassMethod Models() As %DynamicArray
{
	set list = $system.Util.GetEnviron("OPENROUTER_MODELS")
	set:list="" list = ..#Models
	set out = [(..Model())], seen(..Model()) = ""
	for i = 1:1:$length(list, ",") {
		set m = $zstrip($piece(list, ",", i), "<>W")
		continue:(m="")||$data(seen(m))
		set seen(m) = ""
		do out.%Push(m)
	}
	return out
}

ClassMethod Chat(messages As %DynamicArray, tools As %DynamicArray, model As %String = "") As %DynamicObject
{
	return:..Mode()="mock" ##class(App.Agent.Mock).Reply(messages)

	set:model="" model = ..Model()
	set body = {"model": (model), "messages": (messages), "max_tokens": (..#MaxTokens)}
	do body.%Set("temperature", 0, "number")
	if $isobject(tools), tools.%Size() {
		set body.tools = tools
		do body.%Set("tool_choice", "auto")
	}

	set req = ##class(%Net.HttpRequest).%New()
	set req.Server = ..#Host
	set req.Port = 443
	set req.Https = 1
	set req.SSLConfiguration = ##class(App.Setup).#SSLConfig
	set req.Timeout = 120
	set req.ContentType = "application/json"
	set req.ContentCharset = "utf-8"
	do req.SetHeader("Authorization", "Bearer "_..Key())
	do req.SetHeader("X-Title", "Docket")
	do req.SetHeader("HTTP-Referer", "https://github.com/intersystems-community")
	do body.%ToJSON(req.EntityBody)

	set sc = req.Post(..#Path)
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("internal", "cannot reach "_..#Host_": "_$system.Status.GetErrorText(sc))

	set rsp = req.HttpResponse, json = ""
	if $isobject(rsp.Data), rsp.Data.Size {
		do rsp.Data.Rewind()
		try { set json = ##class(%DynamicAbstractObject).%FromJSON(rsp.Data) } catch { set json = "" }
	}
	if rsp.StatusCode '= 200 {
		set detail = ""
		set:$isobject(json) detail = $select($isobject(json.%Get("error")): json.error.%Get("message"), 1: "")
		do ##class(App.Err).Throw("internal", "OpenRouter answered "_rsp.StatusCode_$select(detail = "": "", 1: ": "_detail), {"model": (model)})
	}

	set choices = $select($isobject(json): json.%Get("choices"), 1: "")
	do:('$isobject(choices))||('choices.%Size()) ##class(App.Err).Throw("internal", "OpenRouter answered without a choice")
	set msg = choices.%Get(0).%Get("message")
	do:'$isobject(msg) ##class(App.Err).Throw("internal", "OpenRouter answered without a message")
	set msg.role = "assistant"
	return msg
}

}
