/// Streaming parser for PERFMON HTML reports (Collect^PERFMON / Report^PERFMON "HTML" format).
/// Output in ^||PM:
/// <pre>
/// ^||PM("config"), ^||PM("host"), ^||PM("dur"), ^||PM("ts")
/// ^||PM("t")=n tables ; ^||PM("t",i)=title ; ^||PM("t",i,"h")=$lb(header) ; ^||PM("t",i,r)=$lb(cells) ; ^||PM("t",i,"n")=rows
/// </pre>
Class SysPerf.PM.Parser [ Abstract ]
{

ClassMethod IsPerfmon(pFile As %String) As %Boolean
{
	set tStream=##class(%Stream.FileCharacter).%New()
	quit:$$$ISERR(tStream.LinkToFile(pFile)) 0
	set tHead=tStream.Read(4000)
	quit (tHead["PERFMON")&&((tHead["Collection Report")||(tHead["PERFMON Report")||(tHead["Global metrics"))
}

ClassMethod Parse(pFile As %String) As %Status
{
	set tSC=$$$OK
	try {
		kill ^||PM
		set tStream=##class(%Stream.FileCharacter).%New()
		set tStream.TranslateTable="UTF8"
		set tSC=tStream.LinkToFile(pFile) quit:$$$ISERR(tSC)
		set tStream.LineTerminator=$c(10)
		set tTbl=0,tBuf="",tDone=0,^||PM("t")=0
		while 'tStream.AtEnd {
			set tL=tStream.ReadLine(32000,.tSC) quit:$$$ISERR(tSC)
			set tL=$tr(tL,$c(13),"")
			// header lines
			if tL["Configuration ",tL[" on System " {
				set tT=..Strip(tL)
				set ^||PM("config")=$zstrip($p($p(tT,"Configuration ",2)," on System ",1),"<>W")
				set ^||PM("host")=$tr($zstrip($p(tT," on System ",2),"<>W"),"""","")
			}
			if tL["Collection taken for" {
				set tT=..Strip(tL)
				set ^||PM("dur")=+$zstrip($p(tT,"Collection taken for ",2),"<>W")
				set tUnit=$p($zstrip($p(tT,"Collection taken for ",2),"<>W")," ",2)
				if tUnit["minute" set ^||PM("dur")=^||PM("dur")*60
				// "... on 05 May 2026 12:17:32"
				set tD=$zstrip($p(tT," on ",$l(tT," on ")),"<>W")
				set ^||PM("ts")=##class(SysPerf.Util).TS($p(tD," ",2)_" "_$p(tD," ",1)_" "_$p(tD," ",3),$p(tD," ",4))
			}
			if $zcvt(tL,"L")["<h3>" {
				if tTbl,'tDone do ..Rows(tTbl,tBuf)
				set tTbl=$i(^||PM("t")),^||PM("t",tTbl)=..Strip($p($p(tL,"<h3>",2),"</h3>",1)),^||PM("t",tTbl,"n")=0
				set tBuf=$p(tL,"</h3>",2,*),tDone=0
				continue
			}
			continue:('tTbl)||tDone
			set tBuf=tBuf_" "_tL
			set tEnd=$find($zcvt(tBuf,"L"),"</table>")
			if tEnd {
				do ..Rows(tTbl,$e(tBuf,1,tEnd-9))
				set tBuf="",tDone=1
				continue
			}
			if $l(tBuf)>200000 {
				// hand over complete rows, keep the last (possibly incomplete) one
				set tLow=$zcvt(tBuf,"L"),tLast=0,p=1
				for { set x=$find(tLow,"<tr",p) quit:'x  set tLast=x,p=x }
				if tLast>4 do ..Rows(tTbl,$e(tBuf,1,tLast-4)) set tBuf=$e(tBuf,tLast-3,*)
			}
		}
		quit:$$$ISERR(tSC)
		if tTbl,'tDone,tBuf'="" do ..Rows(tTbl,tBuf)
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Split table text into rows ("<tr" separated) and emit each
ClassMethod Rows(pTbl As %Integer, pText As %String) [ Private ]
{
	set tLow=$zcvt(pText,"L"),p=$find(tLow,"<tr")
	while p {
		set q=$find(tLow,"<tr",p)
		set tRow=$e(pText,p,$s(q:q-4,1:$l(pText)))
		set tE=$find($zcvt(tRow,"L"),"</tr>") if tE set tRow=$e(tRow,1,tE-6)
		do ..EmitRow(pTbl,tRow)
		set p=q
	}
}

/// Extract <th>/<td> cells from the text of one row
ClassMethod EmitRow(pTbl As %Integer, pRow As %String) [ Private ]
{
	set tLow=$zcvt(pRow,"L"),p=1,tCells="",tIsHdr=0
	for {
		set a1=$find(tLow,"<td",p),a2=$find(tLow,"<th",p)
		set a=$s('a1:a2,'a2:a1,a1<a2:a1,1:a2) quit:'a
		set:a=a2 tIsHdr=1
		set gt=$find(tLow,">",a) quit:'gt
		set tClose=$find(tLow,"</t",gt)
		set o1=$find(tLow,"<td",gt),o2=$find(tLow,"<th",gt),tOpen=$s('o1:o2,'o2:o1,o1<o2:o1,1:o2)
		if tClose,('tOpen)||(tClose<tOpen) {
			set tVal=$e(pRow,gt,tClose-4),p=tClose
		} elseif tOpen {
			set tVal=$e(pRow,gt,tOpen-4),p=tOpen-3
		} else {
			set tVal=$e(pRow,gt,*),p=$l(pRow)+1
		}
		set tCells=tCells_$lb(..Strip(tVal))
	}
	quit:tCells=""
	if tIsHdr,'$d(^||PM("t",pTbl,"h")) { set ^||PM("t",pTbl,"h")=tCells quit }
	set n=$i(^||PM("t",pTbl,"n")),^||PM("t",pTbl,n)=tCells
}

/// Remove tags and entities, trim
ClassMethod Strip(pText As %String) As %String
{
	set t=pText,o=""
	for {
		set a=$f(t,"<") if 'a set o=o_t quit
		set o=o_$e(t,1,a-2),b=$f(t,">",a)
		if 'b quit
		set t=$e(t,b,*)
	}
	quit $zstrip(##class(SysPerf.Util).Unescape(o),"<>W")
}

/// Table index by title (case-insensitive contains)
ClassMethod Find(pTitle As %String) As %Integer
{
	set tOut=0
	for i=1:1:+$g(^||PM("t")) if $zcvt(^||PM("t",i),"L")=$zcvt(pTitle,"L") set tOut=i quit
	quit tOut
}

}
