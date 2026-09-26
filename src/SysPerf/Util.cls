/// Helper functions shared by parser, analyzer and UI.
Class SysPerf.Util [ Abstract ]
{

/// Build an ODBC timestamp (yyyy-mm-dd hh:mm:ss) from the many date/time formats found in reports.
/// Dates: mm/dd/yyyy, mm/dd/yy, yyyy-mm-dd, dd/mm/yyyy (auto when first part > 12), "Sep 26 2026".
/// Times: hh:mm:ss, hh:mm:ss.fff, hh:mm:ss AM/PM.
ClassMethod TS(pDate As %String, pTime As %String = "") As %String
{
	set d=$zstrip($tr(pDate,","," "),"<>W"),t=$zstrip($tr(pTime,","," "),"<>W")
	quit:d="" ""
	set (y,m,dd)=""
	if d["/" {
		set m=+$p(d,"/",1),dd=+$p(d,"/",2),y=+$p(d,"/",3)
		if m>12 { set x=m,m=dd,dd=x }
	} elseif d?4N1"-"1.2N1"-"1.2N.E {
		set y=+$p(d,"-",1),m=+$p(d,"-",2),dd=+$p(d,"-",3)
	} elseif d?3A1." "1.2N1." "4N.E {
		set tMon=$zcvt($e(d,1,3),"L")
		set m=$lf($lb("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"),tMon)
		set tRest=$zstrip($e(d,4,*),"<>W"),dd=+$p(tRest," ",1),y=+$p(tRest," ",2)
	} else {
		quit ""
	}
	quit:(m<1)||(m>12)||(dd<1)||(dd>31) ""
	if y<100 set y=y+2000
	set ampm=$zcvt($p(t," ",2),"U"),t=$p($p(t," ",1),".",1)
	set hh=+$p(t,":",1),mi=+$p(t,":",2),ss=+$p(t,":",3)
	if ampm="PM",hh<12 set hh=hh+12
	if ampm="AM",hh=12 set hh=0
	quit y_"-"_..P2(m)_"-"_..P2(dd)_" "_..P2(hh)_":"_..P2(mi)_":"_..P2(ss)
}

ClassMethod P2(n) As %String [ CodeMode = expression ]
{
$s($l(+n)<2:"0"_+n,1:+n)
}

/// Add seconds to an ODBC timestamp
ClassMethod AddSec(pTS As %String, pSec As %Integer) As %String
{
	quit:pTS="" ""
	set h=$zdth(pTS,3,,,,,,,,"")
	quit:h="" ""
	set tDays=+h,tSec=$p(h,",",2)+pSec
	set tDays=tDays+(tSec\86400),tSec=tSec#86400
	quit $zdt(tDays_","_tSec,3)
}

/// Seconds between two ODBC timestamps (pTo - pFrom)
ClassMethod DiffSec(pFrom As %String, pTo As %String) As %Integer
{
	quit:(pFrom="")||(pTo="") ""
	set h1=$zdth(pFrom,3,,,,,,,,""),h2=$zdth(pTo,3,,,,,,,,"")
	quit:(h1="")||(h2="") ""
	quit (h2-h1)*86400+$p(h2,",",2)-$p(h1,",",2)
}

/// Convert $H to ODBC timestamp
ClassMethod HToTS(pH As %String) As %String [ CodeMode = expression ]
{
$s(pH="":"",1:$zdt(pH,3))
}

/// Split a line on runs of white space into a $list
ClassMethod Words(pLine As %String) As %List [ CodeMode = expression ]
{
$s($zstrip($tr(pLine,$c(9)," "),"<>W")="":"",1:$lfs($zstrip($tr(pLine,$c(9)," "),"<=>W")," "))
}

/// Split a comma separated line (mgstat / free format) into a trimmed $list
ClassMethod CSV(pLine As %String) As %List
{
	set tOut=""
	for i=1:1:$l(pLine,",") set tOut=tOut_$lb($zstrip($p(pLine,",",i),"<>W"))
	quit tOut
}

/// Parse one quoted CSV line ("a","b,c","d") into a $list
ClassMethod QuotedCSV(pLine As %String) As %List
{
	set tOut="",tCur="",tInQ=0,tLen=$l(pLine)
	for i=1:1:tLen {
		set c=$e(pLine,i)
		if tInQ {
			if c="""" {
				if $e(pLine,i+1)="""" { set tCur=tCur_"""",i=i+1 } else { set tInQ=0 }
			} else { set tCur=tCur_c }
		} else {
			if c="""" { set tInQ=1 }
			elseif c="," { set tOut=tOut_$lb(tCur),tCur="" }
			elseif c'=$c(13) { set tCur=tCur_c }
		}
	}
	quit tOut_$lb(tCur)
}

/// Return a numeric value from strings like "65,535 MB", "1,548 K", "12.5%", "3.2e+01"; "" if not numeric
ClassMethod Num(pVal As %String) As %String
{
	set v=$zstrip(pVal,"<>W")
	quit:v="" ""
	set v=$tr(v,",","")
	set v=$zstrip(v,">W")
	for tSuf="%"," MB"," KB"," K"," GB"," ms"," MiB"," KiB"," GiB"," B" { if $e(v,*-$l(tSuf)+1,*)=tSuf set v=$zstrip($e(v,1,*-$l(tSuf)),">W") quit }
	quit:v'?.1"-".N.1".".N.1(1"E",1"e").1(1"+",1"-").N ""
	quit:v'?.E1N.E ""
	quit +v
}

/// True when the value is a plain number
ClassMethod IsNum(pVal As %String) As %Boolean [ CodeMode = expression ]
{
(pVal'="")&&($zstrip(pVal,"<>W")?.1"-".N.1".".N)&&($zstrip(pVal,"<>W")?.E1N.E)
}

/// Decode HTML entities used in reports
ClassMethod Unescape(pText As %String) As %String
{
	quit:pText'["&" pText
	set t=pText
	set t=$replace(t,"&lt;","<"),t=$replace(t,"&gt;",">"),t=$replace(t,"&quot;",""""),t=$replace(t,"&nbsp;"," "),t=$replace(t,"&#39;","'"),t=$replace(t,"&apos;","'")
	while t?.E1"&#"1.5N1";".E {
		set p=$f(t,"&#"),q=$f(t,";",p)
		set n=$e(t,p,q-2)
		quit:n'?1.5N
		set t=$e(t,1,p-3)_$c(n)_$e(t,q,*)
	}
	set t=$replace(t,"&amp;","&")
	quit t
}

/// "hh:mm:ss" or "hhhh:mm:ss" or "d-hh:mm:ss" CPU time to seconds
ClassMethod TimeToSec(pTime As %String) As %Double
{
	set t=$zstrip(pTime,"<>W"),tDays=0
	quit:t="" ""
	if t["-" set tDays=+$p(t,"-",1),t=$p(t,"-",2)
	set n=$l(t,":")
	if n=3 quit tDays*86400+($p(t,":",1)*3600)+($p(t,":",2)*60)+$p(t,":",3)
	if n=2 quit tDays*86400+($p(t,":",1)*60)+$p(t,":",2)
	quit +t
}

/// Percentile from a local array a(value)=count (values as numeric subscripts, sorted by IRIS)
ClassMethod Percentile(ByRef pArr, pTotal As %Integer, pPct As %Double = 95) As %Double
{
	quit:pTotal<1 ""
	set tTarget=pTotal*pPct/100,tRun=0,v=""
	for {
		set v=$o(pArr(v)) quit:v=""
		set tRun=tRun+pArr(v)
		quit:tRun>=tTarget
	}
	quit v
}

/// Round to n decimals, "" stays ""
ClassMethod R(pVal, pDec As %Integer = 2) As %String [ CodeMode = expression ]
{
$s(pVal="":"",1:$fn(pVal,"",pDec)+0)
}

/// Escape for JSON string content (without quotes)
ClassMethod JS(pVal As %String) As %String [ CodeMode = expression ]
{
$zcvt(pVal,"O","JSON")
}

/// Human readable duration
ClassMethod Dur(pSec As %Integer) As %String
{
	quit:pSec="" ""
	set d=pSec\86400,h=pSec#86400\3600,m=pSec#3600\60,s=pSec#60
	quit $s(d:d_"d ",1:"")_$s(d||h:h_"h ",1:"")_$s(d:"",1:m_"m ")_$s(d||h:"",1:s_"s")
}

/// Normalise a directory for comparisons (lowercase on Windows paths, forward slashes, trailing slash)
ClassMethod NormDir(pDir As %String) As %String
{
	set d=$zstrip(pDir,"<>W")
	quit:d="" ""
	set tWin=(d?1A1":".E)||(d["\")
	set d=$tr(d,"\","/")
	if $e(d,*)'="/" set d=d_"/"
	if tWin set d=$zcvt(d,"L")
	quit d
}

/// Volume / drive / mount root of a path: "c:" for Windows, first path element for Unix ("/data")
ClassMethod Volume(pDir As %String) As %String
{
	set d=..NormDir(pDir)
	quit:d="" ""
	if d?1A1":".E quit $e(d,1,2)
	quit "/"_$p(d,"/",2)
}

}
