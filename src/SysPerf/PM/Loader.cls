/// Loads a PERFMON HTML report into the SysPerf.PM.* tables.
Class SysPerf.PM.Loader [ Abstract ]
{

ClassMethod LoadFile(pFile As %String, Output pCollId As %Integer, pOrigin As %String = "Manual", pForce As %Boolean = 0, pLogId As %Integer = "") As %Status
{
	set tSC=$$$OK,pCollId="",tStart=$zh
	set tLog=$s(pLogId'="":##class(SysPerf.Data.LoadLog).%OpenId(pLogId),1:"")
	if '$isobject(tLog) set tLog=##class(SysPerf.Data.LoadLog).%New()
	set tName=##class(%File).GetFilename(pFile)
	if tName?1"upload_"8N1"_"6N1"_"1.N1"_"1.E set tName=$p(tName,"_",5,*)
	set tLog.FilePath=pFile,tLog.FileName=tName,tLog.Origin=pOrigin,tLog.Status="Running",tLog.JobPID=$job,tLog.Kind="PERFMON"
	do tLog.%Save()
	try {
		if '##class(%File).Exists(pFile) set tSC=$$$ERROR($$$GeneralError,"File not found: "_pFile) quit
		set tLog.FileSize=##class(%File).GetFileSize(pFile)
		set tHash=##class(SysPerf.Loader).FileHash(pFile,.tSC) quit:$$$ISERR(tSC)
		&sql(SELECT ID INTO :tDup FROM SysPerf_PM.Collection WHERE FileHash=:tHash AND Status='OK')
		if SQLCODE=0,'pForce { set tLog.Status="Skipped",tLog.Message="Identical PERFMON file already loaded as collection "_tDup,tLog.RunID=tDup,pCollId=tDup quit }
		set tSC=##class(SysPerf.PM.Parser).Parse(pFile) quit:$$$ISERR(tSC)
		if '$g(^||PM("t")) set tSC=$$$ERROR($$$GeneralError,"Not a PERFMON report (no tables found)") quit
		set tKey=$zcvt($g(^||PM("host")),"U")_":"_$zcvt($g(^||PM("config")),"U")_":"_$g(^||PM("ts"))
		set tLog.RunKey="PERFMON "_tKey
		&sql(SELECT ID,Status INTO :tOld,:tOldSt FROM SysPerf_PM.Collection WHERE CollKey=:tKey)
		if SQLCODE=0 {
			if 'pForce,tOldSt="OK" { set tLog.Status="Skipped",tLog.Message="Collection "_tKey_" already loaded as ID "_tOld,tLog.RunID=tOld,pCollId=tOld quit }
			// forced reload: keep the notes and acknowledgements of the collection being replaced
			kill tCarry
			set tCarry("notes")=##class(SysPerf.PM.Collection).NotesGetStored(tOld)
			set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Code,Subject,AckBy,AckTS,AckNote FROM SysPerf_PM.Finding WHERE Coll=? AND Acknowledged=1",tOld)
			while tRS.%Next() { set tCarry("ack",tRS.Code,tRS.Subject_" ")=$lb(tRS.AckBy,tRS.AckTS,tRS.AckNote) }
			set tSC=##class(SysPerf.PM.Collection).Purge(tOld) quit:$$$ISERR(tSC)
		}
		set c=##class(SysPerf.PM.Collection).%New()
		set c.CollKey=tKey,c.Config=$g(^||PM("config")),c.Host=$g(^||PM("host")),c.CollectedTS=$g(^||PM("ts")),c.DurationSec=$g(^||PM("dur"))
		set c.Origin=pOrigin,c.SourceFile=pFile,c.FileName=tName,c.FileSize=tLog.FileSize,c.FileHash=tHash,c.Status="L"
		if ##class(SysPerf.Config.Settings).Get().KeepRawSections {
			set tF=##class(%Stream.FileCharacter).%New() set tF.TranslateTable="UTF8"
			if $$$ISOK(tF.LinkToFile(pFile)) do c.RawHtml.CopyFrom(tF)
		}
		set tSC=c.%Save() quit:$$$ISERR(tSC)
		set pCollId=c.%Id(),tLog.RunID=pCollId
		do tLog.%Save()
		set tSC=..Store(c,.tRows) quit:$$$ISERR(tSC)
		set tSC=##class(SysPerf.PM.Analyzer).Analyze(pCollId) quit:$$$ISERR(tSC)
		set c=##class(SysPerf.PM.Collection).%OpenId(pCollId)
		if $d(tCarry) {
			set:c.Notes="" c.Notes=$g(tCarry("notes"))
			set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Code,Subject FROM SysPerf_PM.Finding WHERE Coll=?",pCollId)
			while tRS.%Next() {
				set a=$g(tCarry("ack",tRS.Code,tRS.Subject_" ")) continue:a=""
				set f=##class(SysPerf.PM.Finding).%OpenId(tRS.ID) continue:'$isobject(f)
				set f.Acknowledged=1,f.AckBy=$lg(a,1),f.AckTS=$lg(a,2),f.AckNote=$lg(a,3) do f.%Save()
			}
		}
		set c.Status="OK",c.LoadSeconds=$fn($zh-tStart,"",2)
		set tSC=c.%Save() quit:$$$ISERR(tSC)
		set tLog.Status="OK",tLog.RowsLoaded=tRows,tLog.Message="Loaded PERFMON "_tKey
	} catch ex { set tSC=ex.AsStatus() }
	if $$$ISERR(tSC) {
		set tLog.Status="Error",tLog.Message=$system.Status.GetErrorText(tSC)
		if pCollId'="" do ##class(SysPerf.PM.Collection).Purge(pCollId) set pCollId=""
	}
	set tLog.EndTS=$zdt($h,3),tLog.Seconds=$fn($zh-tStart,"",2)
	do tLog.%Save()
	kill ^||PM
	quit tSC
}

/// Write every table of ^||PM into the typed tables
ClassMethod Store(c As SysPerf.PM.Collection, Output pRows As %Integer) As %Status
{
	set tSC=$$$OK,pRows=0,tId=c.%Id(),tDur=c.DurationSec,tList=""
	try {
		// process list first (used to enrich per-process rows)
		kill tProc
		for i=1:1:^||PM("t") set tList=tList_$lb(^||PM("t",i))
		set c.TableList=$lts(tList,",")
		set i=##class(SysPerf.PM.Parser).Find("Process List")
		if i {
			set h=$g(^||PM("t",i,"h"))
			for r=1:1:^||PM("t",i,"n") {
				set v=^||PM("t",i,r),o=##class(SysPerf.PM.Process).%New()
				do o.CollSetObjectId(tId)
				set o.Rank=r
				// header and row cell counts can differ between IRIS versions / process types:
				// keep the raw row and only store values that are valid for the typed property
				if $ll(v)'=$ll(h) do o.Extra.SetAt($e($lts(v," | "),1,500),"_rawRow"),o.Extra.SetAt("row has "_$ll(v)_" cells, header "_$ll(h),"_note")
				for k=1:1:$ll(h) {
					set tH=$zstrip($li(h,k),"<>W"),x=$zstrip($lg(v,k),"<>W")
					set tP=..ProcCol(tH)
					if tP="" { do:tH'="" o.Extra.SetAt($e(x,1,500),$e(tH,1,100)) continue }
					set tOK=..ProcVal(tP,.x)
					if 'tOK { do o.Extra.SetAt($e(x,1,500),$e(tH,1,100)) continue }
					set $property(o,tP)=x
				}
				set tSC=o.%Save()
				if $$$ISERR(tSC) {
					// never fail the whole load on one process row: keep it as a generic row
					set g=##class(SysPerf.PM.GenericRow).%New() do g.CollSetObjectId(tId)
					set g.TableName="Process List (unparsed rows)",g.RowNo=r,g.Header=h,g.Cells=v
					set tSC=g.%Save() quit:$$$ISERR(tSC)
					set pRows=pRows+1
					continue
				}
				set:o.PID'="" tProc(o.PID)=$lb(o.UserName,o.Namespace,o.Routine,o.State,o.ClientName,o.ExeName,o.ClientIP,o.OSUserName,o.Device,o.JobNo)
				set pRows=pRows+1
			}
			quit:$$$ISERR(tSC)
			set c.ProcessCount=^||PM("t",i,"n")
		}
		// per-global
		set i=##class(SysPerf.PM.Parser).Find("Global metrics per Global")
		if i {
			kill tot
			set h=$g(^||PM("t",i,"h"))
			for r=1:1:^||PM("t",i,"n") {
				set v=^||PM("t",i,r),o=##class(SysPerf.PM.GlobalStat).%New()
				do o.CollSetObjectId(tId)
				set o.Rank=r,o.GlobalName=$lg(v,1),o.IsOther=(o.GlobalName="Other")
				do ..GloCols(o,h,v,tDur)
				set o.DBName=..DB(o.Directory)
				for tP="TotRefs","GloSet","GloKill","PhyBlkRd","PhyBlkWrt","LogBlkRd","JrnEntry","BlkAlloc" set tot(tP)=$g(tot(tP))+$property(o,tP)
				set tSC=o.%Save() quit:$$$ISERR(tSC)
				set pRows=pRows+1
			}
			quit:$$$ISERR(tSC)
			set c.TotalGloRefs=$g(tot("TotRefs")),c.TotalGloSets=$g(tot("GloSet")),c.TotalGloKills=$g(tot("GloKill")),c.TotalPhyBlkRd=$g(tot("PhyBlkRd")),c.TotalPhyBlkWrt=$g(tot("PhyBlkWrt")),c.TotalLogBlkRd=$g(tot("LogBlkRd")),c.TotalJrnEntry=$g(tot("JrnEntry")),c.TotalBlkAlloc=$g(tot("BlkAlloc"))
			set c.GlobalCount=^||PM("t",i,"n")
		}
		// per-routine global metrics
		set i=##class(SysPerf.PM.Parser).Find("Global metrics per Routine")
		if i {
			set h=$g(^||PM("t",i,"h"))
			for r=1:1:^||PM("t",i,"n") {
				set v=^||PM("t",i,r),o=##class(SysPerf.PM.RoutineGlobal).%New()
				do o.CollSetObjectId(tId)
				set o.Rank=r,o.Routine=$lg(v,1),o.IsOther=(o.Routine="Other")
				do ..GloCols(o,h,v,tDur)
				set o.DBName=..DB(o.Directory),o.IsSQL=(o.Routine["sqlcq"),o.ClassName=..Cls(o.Routine)
				set tSC=o.%Save() quit:$$$ISERR(tSC)
				set pRows=pRows+1
			}
			quit:$$$ISERR(tSC)
		}
		// routine metrics
		set i=##class(SysPerf.PM.Parser).Find("Routine metrics per Routine")
		if i {
			set h=$g(^||PM("t",i,"h")),(tLines,tLoads)=0
			for r=1:1:^||PM("t",i,"n") {
				set v=^||PM("t",i,r),o=##class(SysPerf.PM.RoutineStat).%New()
				do o.CollSetObjectId(tId)
				set o.Rank=r,o.Routine=$lg(v,1),o.IsOther=(o.Routine="Other")
				do ..RtnCols(o,h,v)
				set o.DBName=..DB(o.Directory),o.IsSQL=(o.Routine["sqlcq"),o.ClassName=..Cls(o.Routine)
				if tDur set o.LinesPerSec=$fn(o.RtnLines/tDur,"",1),o.LoadsPerSec=$fn(o.RtnLoads/tDur,"",1)
				set tLines=tLines+o.RtnLines,tLoads=tLoads+o.RtnLoads
				set tSC=o.%Save() quit:$$$ISERR(tSC)
				set pRows=pRows+1
			}
			quit:$$$ISERR(tSC)
			set c.TotalRtnLines=tLines,c.TotalRtnLoads=tLoads,c.RoutineCount=^||PM("t",i,"n")
		}
		// per process: merge routine + global tables
		kill tPS
		set iR=##class(SysPerf.PM.Parser).Find("Routine metrics per Process"),iG=##class(SysPerf.PM.Parser).Find("Global metrics per Process")
		for tWhich="R","G" {
			set i=$s(tWhich="R":iR,1:iG) continue:'i
			set h=$g(^||PM("t",i,"h"))
			for r=1:1:^||PM("t",i,"n") {
				set v=^||PM("t",i,r),tPID=$lg(v,1) continue:tPID=""
				if '$d(tPS(tPID)) {
					set o=##class(SysPerf.PM.ProcessStat).%New()
					do o.CollSetObjectId(tId)
					set o.PID=tPID,o.IsOther=(tPID="Other")
					if $d(tProc(tPID)) { set p=tProc(tPID) set o.UserName=$li(p,1),o.Namespace=$li(p,2),o.Routine=$li(p,3),o.State=$li(p,4),o.ClientName=$li(p,5),o.ExeName=$li(p,6),o.ClientIP=$li(p,7),o.OSUserName=$li(p,8),o.Device=$li(p,9),o.JobNo=$li(p,10) }
					set tPS(tPID)=o
				}
				set o=tPS(tPID)
				if tWhich="R" { do ..RtnCols(o,h,v) set o.RankLines=r if tDur set o.LinesPerSec=$fn(o.RtnLines/tDur,"",1) }
				else { do ..GloCols(o,h,v,tDur) set o.RankRefs=r }
			}
		}
		set tPID=""
		for { set tPID=$o(tPS(tPID)) quit:tPID=""  set o=tPS(tPID) set o.Rank=$s(o.RankRefs:o.RankRefs,1:o.RankLines) set tSC=o.%Save() quit:$$$ISERR(tSC)  set pRows=pRows+1 }
		quit:$$$ISERR(tSC)
		// any other table -> generic rows (nothing is lost)
		for i=1:1:^||PM("t") {
			set tT=^||PM("t",i)
			continue:$lf($lb("Process List","Global metrics per Global","Global metrics per Routine","Routine metrics per Routine","Routine metrics per Process","Global metrics per Process"),tT)
			for r=1:1:^||PM("t",i,"n") {
				set o=##class(SysPerf.PM.GenericRow).%New()
				do o.CollSetObjectId(tId)
				set o.TableName=tT,o.RowNo=r,o.Rank=r,o.Header=$g(^||PM("t",i,"h")),o.Cells=^||PM("t",i,r),o.IsOther=($lg(o.Cells,1)="Other")
				set tSC=o.%Save() quit:$$$ISERR(tSC)
				set pRows=pRows+1
			}
			quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
		set tSC=c.%Save()
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Map global metric columns by header name
ClassMethod GloCols(o, h As %List, v As %List, pDur As %Integer) [ Private ]
{
	for k=2:1:$ll(h) {
		set tH=$li(h,k),x=$lg(v,k)
		set tP=$case(tH,"TotRefs":"TotRefs","% Refs":"PctRefs","GloSet":"GloSet","GloKill":"GloKill","BlkAlloc":"BlkAlloc","JrnEntry":"JrnEntry","PhyBlkRd":"PhyBlkRd","PhyBlkWrt":"PhyBlkWrt","LogBlkRd":"LogBlkRd","Directory":"Directory",:"")
		continue:tP=""
		set $property(o,tP)=$s(tP="Directory":x,x="":"",1:+x)
	}
	if pDur>0 {
		set o.RefsPerSec=$fn(o.TotRefs/pDur,"",1),o.PhyRdPerSec=$fn(o.PhyBlkRd/pDur,"",1),o.JrnPerSec=$fn(o.JrnEntry/pDur,"",1),o.UpdPerSec=$fn((o.GloSet+o.GloKill)/pDur,"",1)
	}
	if o.LogBlkRd>0 set o.MissPct=$fn(o.PhyBlkRd*100/o.LogBlkRd,"",2)
}

ClassMethod RtnCols(o, h As %List, v As %List) [ Private ]
{
	for k=2:1:$ll(h) {
		set tH=$li(h,k),x=$lg(v,k)
		set tP=$case(tH,"RtnLines":"RtnLines","% Lines":"PctLines","RtnLoads":"RtnLoads","RtnFetch":"RtnFetch","Line/Load":"LinePerLoad","Directory":"Directory",:"")
		continue:tP=""
		continue:(tP="Directory")&&($classname(o)="SysPerf.PM.ProcessStat")
		set $property(o,tP)=$s(tP="Directory":x,x="":"",1:+x)
	}
}

/// Database folder name from a directory path
ClassMethod DB(pDir As %String) As %String
{
	set d=$tr(pDir,"\","/") set:$e(d,*)="/" d=$e(d,1,*-1)
	quit $zcvt($p(d,"/",$l(d,"/")),"U")
}

/// Class name behind a routine (Pkg.Class.1 -> Pkg.Class); "" for non class routines
ClassMethod Cls(pRtn As %String) As %String
{
	quit:pRtn["sqlcq" ""
	quit:$p(pRtn,".",$l(pRtn,"."))'?1.N ""
	quit $p(pRtn,".",1,$l(pRtn,".")-1)
}

/// PERFMON Process List header -> SysPerf.PM.Process property (case / spacing tolerant)
ClassMethod ProcCol(pH As %String) As %String
{
	set k=$zcvt($tr(pH," _-",""),"L")
	quit $case(k,"job#":"JobNo","job":"JobNo","jobno":"JobNo","pid":"PID","displaypid":"DisplayPID","username":"UserName","user":"UserName","device":"Device","nspace":"Namespace","namespace":"Namespace","routine":"Routine","commands":"Commands","globals":"Globals","state":"State","clientname":"ClientName","exename":"ExeName","ipaddress":"ClientIP","clientip":"ClientIP","canbeexamined":"CanBeExamined","canbesuspended":"CanBeSuspended","canbeterminated":"CanBeTerminated","canreceivebroadcast":"CanReceiveBroadcast","prvgblblkcnt":"PrvGblBlkCnt","osusername":"OSUserName","cputime":"CPUTime",:"")
}

/// Validate / normalise a value for a typed Process property. Returns 0 when it does not fit.
ClassMethod ProcVal(pProp As %String, ByRef pVal As %String) As %Boolean
{
	if $lf($lb("CanBeExamined","CanBeSuspended","CanBeTerminated","CanReceiveBroadcast"),pProp) {
		set u=$zcvt(pVal,"U")
		if (u="")||(u="1")||(u="0") quit 1
		if $lf($lb("YES","Y","TRUE"),u) set pVal=1 quit 1
		if $lf($lb("NO","N","FALSE"),u) set pVal=0 quit 1
		quit 0
	}
	if $lf($lb("Commands","Globals","PrvGblBlkCnt","CPUTime","JobNo"),pProp) {
		quit:pVal="" 1
		set n=$tr(pVal,", ")
		quit:'$isvalidnum(n) 0
		set pVal=$s(pProp="JobNo":n\1,1:+n)
		quit 1
	}
	set pVal=$e(pVal,1,$s(pProp="Routine":500,pProp="Device":300,1:200))
	quit 1
}

}
