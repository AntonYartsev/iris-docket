Class App.Json [ Abstract ]
{

ClassMethod Canonical(json As %String) As %String [ Language = python ]
{
    import json as j
    return j.dumps(j.loads(json), sort_keys=True, separators=(",", ":"), ensure_ascii=False)
}

ClassMethod SchemaErrors(schema As %String, args As %String) As %String [ Language = python ]
{
    import json
    from jsonschema import Draft202012Validator
    out = []
    for e in Draft202012Validator(json.loads(schema)).iter_errors(json.loads(args)):
        out.append({"path": e.json_path, "rule": e.validator, "message": e.message})
    return json.dumps(out)
}

}
