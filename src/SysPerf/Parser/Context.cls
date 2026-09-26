/// Parse context for one report: holds the Run object and dispatches every section of ^||SP
/// (filled by <class>SysPerf.Parser.Html</class>) to its parser.
Class SysPerf.Parser.Context Extends %RegisteredObject
{

Property Run As SysPerf.Data.Run;

Property RunId As %Integer;

Property Rows As %Integer [ InitialExpression = 0 ];

Property KeepRaw As %Boolean [ InitialExpression = 1 ];

/// Date of the run (yyyy-mm-dd) - used for sources that only print a time (sar)
Property BaseDate As %String;

/// Warnings collected while parsing (non fatal)
Property Warnings As %String(MAXLEN = 32000);

/// CPF database directory (normalised) -> database name
Property DBMap As %String [ MultiDimensional ];

/// Actual mgstat sampling interval in seconds
Property Interval As %Integer;

/// Section name -> parse mode (Parsed/Raw) for the Section table
Property ModeBySection As array Of %String;

/// Phase 1: debug snapshot + Configuration/Profile/Instances/License. Does NOT save anything
/// so the loader can detect duplicates before writing child rows.
Method ParseHeader() As %Status
{
	set tSC=$$$OK
	try {
		set tNames=""
		for i=1:1:+$g(^||SP("sec")) set tNames=tNames_$lb($lg(^||SP("sec",i),1))
		set ..Run.SectionList=$lts(tNames,",")
		// run id = first subscript of pBarray(...) in the debug snapshot
		for n=1:1:+$g(^||SP("debug")) {
			set tL=^||SP("debug",n)
			if $e(tL,1,9)="pBarray(""" { set ..Run.RunId=$p($p(tL,"(""",2),"""",1) quit }
		}
		set tSC=##class(SysPerf.Parser.IRIS).Debug($this) quit:$$$ISERR(tSC)
		for tName="Configuration","Profile" {
			set i=##class(SysPerf.Parser.Html).Find(tName) continue:'i
			set tSC=$classmethod("SysPerf.Parser.IRIS",tName,$this,i) quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Phase 2 (Run already saved): every section into the typed tables
Method ParseBody() As %Status
{
	set tSC=$$$OK
	try {
		for tName="Configuration","Profile","IRIS ALL","Cache ALL","License","CPF file" {
			set i=##class(SysPerf.Parser.Html).Find(tName) continue:'i
			set tSC=..Dispatch(i,tName) quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
		set tSC=..Run.%Save() quit:$$$ISERR(tSC)
		for i=1:1:+$g(^||SP("sec")) {
			set tName=$lg(^||SP("sec",i),1)
			continue:$lf($lb("Configuration","Profile","IRIS ALL","Cache ALL","License","CPF file"),tName)
			set tSC=..Dispatch(i,tName)
			if $$$ISERR(tSC) {
				// one bad section must not lose the whole report
				set ..Warnings=..Warnings_"Section "_tName_": "_$system.Status.GetErrorText(tSC)_$c(10)
				do ..ModeBySection.SetAt("Error",tName)
				set tSC=$$$OK
			}
		}
		if ..KeepRaw set tSC=..SaveRaw() quit:$$$ISERR(tSC)
		set tSC=##class(SysPerf.Parser.OS).DeriveDiskMax($this) quit:$$$ISERR(tSC)
		set tSC=..Run.%Save()
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

Method Dispatch(pSec As %Integer, pName As %String) As %Status
{
	set tSC=$$$OK
	try {
		set tMode="Parsed"
		set tLower=$zcvt(pName,"L")
		if pName="Configuration" { set tSC=##class(SysPerf.Parser.IRIS).Configuration($this,pSec) }
		elseif pName="Profile" { set tSC=##class(SysPerf.Parser.IRIS).Profile($this,pSec) }
		elseif (pName="IRIS ALL")||(pName="Cache ALL") { set tSC=##class(SysPerf.Parser.IRIS).InstanceList($this,pSec) }
		elseif pName="License" { set tSC=##class(SysPerf.Parser.IRIS).License($this,pSec) }
		elseif pName="CPF file" { set tSC=##class(SysPerf.Parser.IRIS).CPF($this,pSec) }
		elseif pName="mgstat" { set tSC=##class(SysPerf.Parser.IRIS).Mgstat($this,pSec) }
		elseif pName="%SS" { set tSC=##class(SysPerf.Parser.IRIS).SS($this,pSec) }
		elseif (tLower="irisstat -c1")||(tLower="cstat -c1") { set tSC=##class(SysPerf.Parser.IRIS).IrisstatC1($this,pSec) }
		elseif (tLower="irisstat -d")||(tLower="cstat -d") { set tSC=##class(SysPerf.Parser.IRIS).IrisstatD($this,pSec) }
		elseif (tLower="irisstat -r")||(tLower="cstat -r") { set tSC=##class(SysPerf.Parser.IRIS).IrisstatR($this,pSec) }
		elseif pName="Windows info" { set tSC=##class(SysPerf.Parser.OS).WindowsInfo($this,pSec) }
		elseif pName="tasklist" { set tSC=##class(SysPerf.Parser.OS).Tasklist($this,pSec) }
		elseif pName="perfmon" { set tSC=##class(SysPerf.Parser.OS).Perfmon($this,pSec) }
		elseif pName="vmstat" { set tSC=##class(SysPerf.Parser.OS).Vmstat($this,pSec) }
		elseif pName="iostat" { set tSC=##class(SysPerf.Parser.OS).Iostat($this,pSec) }
		elseif (pName="sar -u")||(pName="sar -P ALL") { set tSC=##class(SysPerf.Parser.OS).SarU($this,pSec) }
		elseif pName="sar -d" { set tSC=##class(SysPerf.Parser.OS).SarD($this,pSec) }
		elseif pName="free" { set tSC=##class(SysPerf.Parser.OS).Free($this,pSec) }
		elseif pName="ps" { set tSC=##class(SysPerf.Parser.OS).PS($this,pSec) }
		elseif pName="cpu" { set tSC=##class(SysPerf.Parser.OS).CPUInfo($this,pSec) }
		elseif pName="df -m" { set tSC=##class(SysPerf.Parser.OS).DF($this,pSec) }
		elseif pName="sysctl -a" { set tSC=##class(SysPerf.Parser.OS).KeyEq($this,pSec,"sysctl") }
		elseif pName="ipcs" { set tSC=##class(SysPerf.Parser.OS).Ipcs($this,pSec) }
		elseif ($e(tLower,*-4,*)=" info") { set tSC=##class(SysPerf.Parser.OS).UnixInfo($this,pSec) }
		else { set tMode="Raw" }
		do ..ModeBySection.SetAt(tMode,pName)
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Store the raw text of every section/sample (streams)
Method SaveRaw() As %Status
{
	set tSC=$$$OK
	for i=1:1:+$g(^||SP("sec")) {
		set tName=$lg(^||SP("sec",i),1)
		set s=""
		for {
			set s=$o(^||SP("sec",i,s)) quit:s=""
			continue:s'=+s
			set tObj=##class(SysPerf.Data.Section).%New()
			do tObj.RunSetObjectId(..RunId)
			set tObj.Seq=i,tObj.Name=tName,tObj.SampleNo=s,tObj.SampleCount=+$g(^||SP("sec",i,"max"))
			set tObj.ParseMode=..ModeBySection.GetAt(tName)
			set tN=+$g(^||SP("sec",i,s)),tObj.LineCount=tN
			for n=1:1:tN do tObj.Content.WriteLine(^||SP("sec",i,s,n))
			set tSC=tObj.%Save() quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
	}
	// Debug snapshot as its own raw section
	if $d(^||SP("debug")) {
		set tObj=##class(SysPerf.Data.Section).%New()
		do tObj.RunSetObjectId(..RunId)
		set tObj.Seq=0,tObj.Name="Debug snapshot",tObj.SampleNo=0,tObj.ParseMode="Parsed",tObj.LineCount=+^||SP("debug")
		for n=1:1:+^||SP("debug") do tObj.Content.WriteLine(^||SP("debug",n))
		set tSC=tObj.%Save()
	}
	quit tSC
}

/// Add a generic name/value row
Method KV(pSection As %String, pName As %String, pValue As %String, pSample As %Integer = 0, pGroup As %String = "") As %Status
{
	set pName=$zstrip(pName,"<>W"),pValue=$zstrip(pValue,"<>W")
	quit:(pName="")||(..RunId="") $$$OK
	set tObj=##class(SysPerf.Data.KeyValue).%New()
	do tObj.RunSetObjectId(..RunId)
	set tObj.Section=pSection,tObj.GroupName=pGroup,tObj.SampleNo=pSample
	set tObj.Name=$e(pName,1,500),tObj.Value=$e(pValue,1,32000)
	set tObj.NumValue=##class(SysPerf.Util).Num(pValue)
	set ..Rows=..Rows+1,tObj.Seq=..Rows
	quit tObj.%Save()
}

/// Text line n of section/sample
Method L(pSec As %Integer, pSample As %Integer, pN As %Integer) As %String [ CodeMode = expression ]
{
$g(^||SP("sec",pSec,pSample,pN))
}

/// Line count of section/sample
Method N(pSec As %Integer, pSample As %Integer) As %Integer [ CodeMode = expression ]
{
+$g(^||SP("sec",pSec,pSample))
}

/// Samples present in the section: returns $list of sample numbers
Method Samples(pSec As %Integer) As %List
{
	set tOut="",s=""
	for { set s=$o(^||SP("sec",pSec,s)) quit:s=""  if s=+s,$g(^||SP("sec",pSec,s))>0 set tOut=tOut_$lb(s) }
	quit tOut
}

/// Extract "The time is: Sat Sep 26 11:31:17 2026" timestamp of an irisstat sample
Method IrisstatTime(pSec As %Integer, pSample As %Integer) As %String
{
	set tOut="",tMax=..N(pSec,pSample) set:tMax>15 tMax=15
	for n=1:1:tMax {
		set tL=..L(pSec,pSample,n)
		continue:tL'["The time is:"
		// Sat Sep 26 11:31:17 2026
		set t=$zstrip($p(tL,"The time is:",2),"<=>W")
		if $l(t," ")>=5 set tOut=##class(SysPerf.Util).TS($p(t," ",2)_" "_$p(t," ",3)_" "_$p(t," ",5),$p(t," ",4))
		quit
	}
	quit tOut
}

}
