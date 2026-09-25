Class App.Policy.Confirmation Extends %Persistent
{

Property Token As %String(MAXLEN = 64) [ Required ];

Property Tool As %String(MAXLEN = 128);

Property ArgsHash As %String(MAXLEN = 64);

Property Actor As %String(MAXLEN = 128);

Property ExpiresAt As %TimeStamp;

Property UsedAt As %TimeStamp;

Index TokenIdx On Token [ Unique ];

Parameter TTLSECONDS = 120;

ClassMethod Issue(tool As %String, argsHash As %String, actor As %String) As %String
{
	set c = ..%New()
	set c.Token = ..Sign(tool, argsHash, actor)
	set c.Tool = tool
	set c.ArgsHash = argsHash
	set c.Actor = actor
	set h = $piece($ztimestamp, ",", 1), s = ($piece($ztimestamp, ",", 2) \ 1) + ..#TTLSECONDS
	set:s'<86400 h = h + 1, s = s - 86400
	set c.ExpiresAt = $zdatetime(h_","_s, 3)
	set sc = c.%Save()
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("internal", $system.Status.GetErrorText(sc))
	return c.Token
}

ClassMethod Redeem(token As %String, tool As %String, argsHash As %String, actor As %String)
{
	set c = ..TokenIdxOpen(token)
	do:'$isobject(c) ##class(App.Err).Throw("confirm_invalid", "unknown confirmation token")
	do:c.UsedAt'="" ##class(App.Err).Throw("confirm_invalid", "this confirmation has already been used")
	// ]] compare as text here
	do:$zdatetime($ztimestamp, 3)]]c.ExpiresAt ##class(App.Err).Throw("confirm_invalid", "this confirmation expired - review the operation and confirm again")
	if (c.Tool'=tool) || (c.ArgsHash'=argsHash) || (c.Actor'=actor) {
		do ##class(App.Err).Throw("confirm_invalid", "the confirmed call is not the call being executed")
	}
	set c.UsedAt = $zdatetime($ztimestamp, 3)
	set sc = c.%Save()
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("internal", $system.Status.GetErrorText(sc))
}

/// flags=1 or header gets linebreaks
ClassMethod Sign(tool As %String, argsHash As %String, actor As %String) As %String
{
	set nonce = $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(16), 1)
	set raw = $system.Encryption.HMACSHA(256, tool_"|"_argsHash_"|"_actor_"|"_nonce, ..Secret())
	return $system.Encryption.Base64Encode(raw, 1)
}

ClassMethod Secret() As %String
{
	if '$data(^App.Policy("secret")) {
		set ^App.Policy("secret") = $system.Encryption.Base64Encode($system.Encryption.GenCryptRand(32), 1)
	}
	return ^App.Policy("secret")
}

}
