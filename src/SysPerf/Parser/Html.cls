/// Streaming splitter for ^SystemPerformance / ^pButtons HTML reports.
/// Reads the file line by line (works for 100MB+ 24h reports) and stores the plain text of every
/// section and sample in the process-private global ^||SP:
/// <pre>
/// ^||SP("title")                      report title
/// ^||SP("debug",n)                    lines of the "Debug snapshot" comment
/// ^||SP("sec")                        number of sections
/// ^||SP("sec",i)                      $lb(Name, DivId)
/// ^||SP("sec",i,"max")                highest sample number
/// ^||SP("sec",i,s)                    line count of sample s (0 = text not inside a sample)
/// ^||SP("sec",i,s,n)                  text line
/// ^||SP("idx",Name)                   i
/// </pre>
Class SysPerf.Parser.Html [ Abstract ]
{

ClassMethod Split(pFile As %String, Output pBytes As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		kill ^||SP
		set pBytes=##class(%File).GetFileSize(pFile)
		set tStream=##class(%Stream.FileCharacter).%New()
		set tStream.TranslateTable="RAW"
		set tSC=tStream.LinkToFile(pFile) quit:$$$ISERR(tSC)
		set tStream.LineTerminator=$c(10)
		set st("sec")=0,st("sample")=0,st("inPre")=0,st("inA")=0,st("inTitle")=0,st("inComment")=0,st("expectTitle")=0,st("cur")="",st("just")=0,st("debug")=0
		set ^||SP("sec")=0
		while 'tStream.AtEnd {
			set tLine=tStream.ReadLine(32000,.tSC) quit:$$$ISERR(tSC)
			if $e(tLine,*)=$c(13) set tLine=$e(tLine,1,*-1)
			do ..Line(tLine,.st)
		}
		quit:$$$ISERR(tSC)
		if st("inPre"),st("cur")'="" do ..Emit(.st)
		set ^||SP("title")=$zstrip($g(st("title")),"<>W")
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Process one physical line
ClassMethod Line(pLine As %String, ByRef st) [ Private ]
{
	set tPos=1,tLen=$l(pLine),tHadContent=0
	while tPos<=tLen {
		if st("inComment") {
			set e=$find(pLine,"-->",tPos)
			if 'e {
				set tTxt=$e(pLine,tPos,*)
				set:st("debug") ^||SP("debug",$i(^||SP("debug")))=tTxt
				set tPos=tLen+1
				quit
			}
			set tTxt=$e(pLine,tPos,e-4)
			set:st("debug")&&(tTxt'="") ^||SP("debug",$i(^||SP("debug")))=tTxt
			set st("inComment")=0,tPos=e
			continue
		}
		set lt=$find(pLine,"<",tPos)
		if 'lt {
			set tTxt=$e(pLine,tPos,*)
			if tTxt'="" do ..Text(tTxt,.st) set tHadContent=1
			quit
		}
		set tTxt=$e(pLine,tPos,lt-2)
		if tTxt'="" do ..Text(tTxt,.st) set tHadContent=1
		if $e(pLine,lt,lt+2)="!--" {
			set st("inComment")=1,tPos=lt+3
			set st("debug")=($e(pLine,lt+3,lt+40)["Debug snapshot")
			continue
		}
		set gt=$find(pLine,">",lt)
		if 'gt {
			do ..Text("<"_$e(pLine,lt,*),.st) set tHadContent=1
			quit
		}
		set tTag=$e(pLine,lt,gt-2),tPos=gt
		do ..Tag(tTag,.st,.tHadContent)
	}
	// end of physical line
	if st("inPre") {
		if st("just"),'tHadContent,st("cur")="" {
			// newline right after <pre> is not content
		} else {
			do ..Emit(.st)
		}
		set st("just")=0
	}
}

ClassMethod Tag(pTag As %String, ByRef st, ByRef pHadContent) [ Private ]
{
	set tName=$zcvt($p($p(pTag," ",1),$c(9),1),"L")
	if tName="pre" { set st("inPre")=1,st("just")=1,st("cur")="",pHadContent=0 quit }
	if tName="/pre" {
		if st("inPre"),st("cur")'="" do ..Emit(.st)
		set st("inPre")=0,st("just")=0,st("cur")=""
		quit
	}
	if tName="a" { set st("inA")=($zcvt(pTag,"L")["href") quit }
	if tName="/a" { set st("inA")=0 quit }
	if tName="title" { set st("inTitle")=1 quit }
	if tName="/title" { set st("inTitle")=0 quit }
	if tName="div",$zcvt(pTag,"L")["id=" {
		set tRest=$e(pTag,$find($zcvt(pTag,"L"),"id="),*),tQ=$e(tRest)
		if (tQ="""")||(tQ="'") { set tId=$p($e(tRest,2,*),tQ,1) } else { set tId=$p(tRest," ",1) }
		set i=$i(^||SP("sec")),^||SP("sec",i)=$lb(tId,tId),^||SP("sec",i,"max")=0
		set st("sec")=i,st("sample")=0,st("expectTitle")=1
		quit
	}
}

ClassMethod Text(pText As %String, ByRef st) [ Private ]
{
	set tText=##class(SysPerf.Util).Unescape(pText)
	if st("inTitle") { set st("title")=$g(st("title"))_tText quit }
	if st("inPre") { set st("cur")=st("cur")_tText quit }
	quit:st("inA")
	set t=$zstrip(tText,"<>W")
	quit:t=""
	set i=st("sec")
	quit:'i
	if st("expectTitle") {
		set st("expectTitle")=0
		set $li(^||SP("sec",i),1)=t
		set:'$d(^||SP("idx",t)) ^||SP("idx",t)=i
		quit
	}
	if t?1"sample "1.N1" of "1.N {
		set st("sample")=+$p(t," ",2)
		set:st("sample")>^||SP("sec",i,"max") ^||SP("sec",i,"max")=st("sample")
		set ^||SP("sec",i,"count")=+$p(t," of ",2)
		quit
	}
	// loose text outside <pre> (e.g. "irisstat arguments: ...")
	set s=st("sample"),n=$i(^||SP("sec",i,s)),^||SP("sec",i,s,n)=t
}

ClassMethod Emit(ByRef st) [ Private ]
{
	set i=st("sec")
	if 'i { set st("cur")="" quit }
	set s=st("sample"),n=$i(^||SP("sec",i,s)),^||SP("sec",i,s,n)=st("cur")
	set st("cur")=""
}

/// Return the section index for a name ("" if absent)
ClassMethod Find(pName As %String) As %Integer [ CodeMode = expression ]
{
$g(^||SP("idx",pName))
}

/// Return the text of section i sample s as one string with $c(10) separators
ClassMethod Text2String(pSec As %Integer, pSample As %Integer = 0) As %String
{
	set tOut=""
	for n=1:1:$g(^||SP("sec",pSec,pSample)) set tOut=tOut_$s(n>1:$c(10),1:"")_^||SP("sec",pSec,pSample,n)
	quit tOut
}

}
