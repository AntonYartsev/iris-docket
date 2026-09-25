Class App.Tools.Logs.FileBase Extends App.Tools.Base [ Abstract ]
{

Parameter Category = "logs";

Parameter Source = "manual";

Parameter Privilege = "%Admin_Operate:U";

/// never a path from caller!!
Parameter LogFile;

Parameter SourceName;

XData Schema [ MimeType = application/json ]
{
{
  "type": "object",
  "properties": {
    "lines": {
      "type": "integer",
      "minimum": 1,
      "maximum": 2000,
      "title": "How many entries to read from the end of the file. Default 200."
    }
  }
}
}

ClassMethod Execute(args As %DynamicObject) As %DynamicObject
{
	set lines = +args.%Get("lines")
	set:lines'>0 lines = 200
	set:lines>2000 lines = 2000

	set path = ..Path()
	do:'##class(%File).Exists(path) ##class(App.Err).Throw("not_found", path_" does not exist on this instance")
	set stream = ##class(%Stream.FileCharacter).%New()
	set sc = stream.LinkToFile(path)
	do:$system.Status.IsError(sc) ##class(App.Err).Throw("tool_error", "cannot open "_path_": "_$system.Status.GetErrorText(sc))

	set window = lines * 512
	set:window<64000 window = 64000
	set from = stream.Size - window
	if from > 1 {
		do stream.MoveTo(from)
		do stream.ReadLine()
	}

	set rows = [], cur = ""
	while 'stream.AtEnd {
		set line = $zstrip(stream.ReadLine(), ">C")
		if '..Starts(line) {
			// stack dumps spans lines
			do:$isobject(cur) cur.%Set("text", cur.text_$char(10)_line)
			continue
		}
		set cur = ..Parse(line)
		do rows.%Push(cur)
	}

	set out = []
	for i = rows.%Size() - 1 : -1 : $select(rows.%Size() > lines: rows.%Size() - lines, 1: 0) {
		do out.%Push(rows.%Get(i))
	}
	return {"data": (out)}
}

ClassMethod Path() As %String
{
	do ##class(Config.config).Get(.cfg)
	set console = $get(cfg("ConsoleFile"))
	return:(console'="")&&(..#LogFile="messages.log") console
	set dir = $select(console = "": ##class(%File).ManagerDirectory(), 1: ##class(%File).GetDirectory(console))
	return ##class(%File).NormalizeFilename(..#LogFile, dir)
}

ClassMethod Starts(line As %String) As %Boolean
{
	return $extract(line, 1, 21) ? 2N1"/"2N1"/"2N1"-"2N1":"2N1":"2N1":"3N
}

ClassMethod Parse(line As %String) As %DynamicObject
{
	set rest = $piece(line, " ", 2, *)
	set tail = $piece(rest, " ", 3, *)
	set row = {}
	set row.ts = ..Stamp($piece(line, " "))
	set row.source = ..#SourceName
	set row.process = $translate($piece(rest, " "), "()")
	set row.level = $case($piece(rest, " ", 2), 0: "info", 1: "warn", 2: "severe", 3: "fatal", : "info")
	set row.category = $select($extract(tail) = "[": $piece($extract(tail, 2, *), "]"), 1: "")
	set row.text = $select(row.category = "": tail, 1: $zstrip($piece(tail, "]", 2, *), "<W"))
	return row
}

ClassMethod Stamp(raw As %String) As %String
{
	set d = $piece(raw, "-"), t = $piece(raw, "-", 2)
	return:$length(d, "/")'=3 raw
	return "20"_$piece(d, "/", 3)_"-"_$piece(d, "/")_"-"_$piece(d, "/", 2)_" "_$piece(t, ":", 1, 3)_"."_$piece(t, ":", 4)
}

}
