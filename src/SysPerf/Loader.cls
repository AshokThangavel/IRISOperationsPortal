/// Entry points to feed ^SystemPerformance HTML reports into the SysPerf tables.
/// <example>
///  // one file
///  set sc=##class(SysPerf.Loader).LoadFile("D:\perf\HOST_IRIS_20260926_000000_24hours.html",.runId)
///  // every *.html in a folder (moves files to Archive / Error folders from Settings)
///  set sc=##class(SysPerf.Loader).LoadDirectory("D:\perf\inbox\",1,.summary)
///  // default inbox from Settings
///  set sc=##class(SysPerf.Loader).LoadInbox(.summary)
/// </example>
Class SysPerf.Loader [ Abstract ]
{

/// Load one report file. pForce=1 replaces an already loaded copy of the same run.
ClassMethod LoadFile(pFile As %String, Output pRunId As %Integer, pOrigin As %String = "Manual", pForce As %Boolean = 0, pLogId As %Integer = "") As %Status
{
	set tSC=$$$OK,pRunId="",tStart=$zh,tRun=""
	// PERFMON reports have their own loader
	if ##class(%File).Exists(pFile),##class(SysPerf.PM.Parser).IsPerfmon(pFile) quit ##class(SysPerf.PM.Loader).LoadFile(pFile,.pRunId,pOrigin,pForce,pLogId)
	set tLog=$s(pLogId'="":##class(SysPerf.Data.LoadLog).%OpenId(pLogId),1:"")
	if '$isobject(tLog) set tLog=##class(SysPerf.Data.LoadLog).%New()
	set tOrigName=##class(%File).GetFilename(pFile)
	// uploads are stored as upload_<date>_<time>_<job>_<original name>
	if tOrigName?1"upload_"8N1"_"6N1"_"1.N1"_"1.E set tOrigName=$p(tOrigName,"_",5,*)
	set tLog.FilePath=pFile,tLog.FileName=tOrigName,tLog.Origin=pOrigin,tLog.Status="Running",tLog.JobPID=$job
	do tLog.%Save()
	try {
		if '##class(%File).Exists(pFile) set tSC=$$$ERROR($$$GeneralError,"File not found: "_pFile) quit
		set tLog.FileSize=##class(%File).GetFileSize(pFile)
		set tHash=..FileHash(pFile,.tSC) quit:$$$ISERR(tSC)
		// same bytes already loaded?
		&sql(SELECT ID INTO :tDup FROM SysPerf_Data.Run WHERE FileHash=:tHash AND Status='OK')
		if SQLCODE=0,'pForce {
			set tLog.Status="Skipped",tLog.Message="Identical file already loaded as run ID "_tDup,tLog.RunID=tDup,pRunId=tDup
			quit
		}
		set tSC=##class(SysPerf.Parser.Html).Split(pFile,.tBytes) quit:$$$ISERR(tSC)
		if '$g(^||SP("sec")) set tSC=$$$ERROR($$$GeneralError,"Not a ^SystemPerformance / ^pButtons report (no sections found)") quit
		if '##class(SysPerf.Parser.Html).Find("mgstat"),'##class(SysPerf.Parser.Html).Find("Configuration") set tSC=$$$ERROR($$$GeneralError,"Not a ^SystemPerformance report (no mgstat/Configuration section)") quit

		set tRun=##class(SysPerf.Data.Run).%New()
		set tRun.SourceFile=pFile,tRun.FileName=tOrigName,tRun.FileSize=tBytes,tRun.FileHash=tHash,tRun.Status="L"
		set ctx=##class(SysPerf.Parser.Context).%New()
		set ctx.Run=tRun,ctx.KeepRaw=##class(SysPerf.Config.Settings).Get().KeepRawSections
		set tSC=ctx.ParseHeader() quit:$$$ISERR(tSC)
		if tRun.RunId="" set tRun.RunId=$p(tRun.FileName,".",1)
		set tRun.RunKey=$zcvt(tRun.Host,"U")_":"_$zcvt(tRun.Instance,"U")_":"_tRun.RunId
		set tLog.RunKey=tRun.RunKey
		// same run (maybe re-generated file) already loaded?
		set tOld=..RunByKey(tRun.RunKey)
		if tOld'="" {
			set tOldObj=##class(SysPerf.Data.Run).%OpenId(tOld,0)
			if 'pForce,$isobject(tOldObj),tOldObj.Status="OK" {
				set tLog.Status="Skipped",tLog.Message="Run "_tRun.RunKey_" already loaded as ID "_tOld_" (use Force to reload)",tLog.RunID=tOld,pRunId=tOld
				set tRun=""
				quit
			}
			set tSC=##class(SysPerf.Data.Run).Purge(tOld) quit:$$$ISERR(tSC)
		}
		set tSC=tRun.%Save() quit:$$$ISERR(tSC)
		set pRunId=tRun.%Id(),ctx.RunId=pRunId,tLog.RunID=pRunId
		do tLog.%Save()
		set tSC=ctx.ParseBody() quit:$$$ISERR(tSC)
		set tSC=##class(SysPerf.Rollup).Build(pRunId) quit:$$$ISERR(tSC)
		set tSC=##class(SysPerf.Analyzer).Analyze(pRunId) quit:$$$ISERR(tSC)
		set tRun=##class(SysPerf.Data.Run).%OpenId(pRunId)
		set tRun.Status="OK",tRun.LoadSeconds=$fn($zh-tStart,"",2)
		set tRun.StatusText=ctx.Warnings
		set tSC=tRun.%Save() quit:$$$ISERR(tSC)
		set tLog.Status="OK",tLog.RowsLoaded=ctx.Rows
		set tLog.Message="Loaded "_tRun.RunKey_$s(ctx.Warnings'="":" with warnings: "_ctx.Warnings,1:"")
	} catch ex { set tSC=ex.AsStatus() }
	if $$$ISERR(tSC) {
		set tLog.Status="Error",tLog.Message=$system.Status.GetErrorText(tSC)
		if pRunId'="" do ##class(SysPerf.Data.Run).Purge(pRunId) set pRunId=""
	}
	set tLog.EndTS=$zdt($h,3),tLog.Seconds=$fn($zh-tStart,"",2)
	do tLog.%Save()
	kill ^||SP
	quit tSC
}

ClassMethod RunByKey(pKey As %String) As %String
{
	&sql(SELECT ID INTO :tID FROM SysPerf_Data.Run WHERE RunKey=:pKey)
	quit $s(SQLCODE=0:tID,1:"")
}

/// SHA-256 of the file (hex)
ClassMethod FileHash(pFile As %String, Output pSC As %Status) As %String
{
	set pSC=$$$OK,tHex=""
	try {
		set tStream=##class(%Stream.FileBinary).%New()
		set pSC=tStream.LinkToFile(pFile) quit:$$$ISERR(pSC)
		set tBin=$system.Encryption.SHAHashStream(256,tStream,.pSC) quit:$$$ISERR(pSC)
		for i=1:1:$l(tBin) set tHex=tHex_$tr($j($zhex($a(tBin,i)),2)," ","0")
	} catch ex { set pSC=ex.AsStatus() }
	quit $zcvt(tHex,"L")
}

/// Load every matching file of a folder. pArchive=1 moves loaded files to ArchiveDir and failed ones to ErrorDir.
ClassMethod LoadDirectory(pDir As %String = "", pArchive As %Boolean = 1, Output pSummary As %String, pOrigin As %String = "Manual", pForce As %Boolean = 0) As %Status
{
	set tSC=$$$OK,pSummary="",(tOK,tSkip,tErr)=0
	try {
		set tSet=##class(SysPerf.Config.Settings).Get()
		if pDir="" set pDir=tSet.InboxDir
		if '##class(%File).DirectoryExists(pDir) set tSC=$$$ERROR($$$GeneralError,"Folder not found: "_pDir) quit
		do tSet.EnsureDirs()
		set tRS=##class(%ResultSet).%New("%File:FileSet")
		set tSC=tRS.Execute(pDir,tSet.FilePattern,"DateModified",0) quit:$$$ISERR(tSC)
		kill tFiles
		while tRS.Next() { continue:tRS.Get("Type")'="F"  set tFiles($i(tFiles))=tRS.Get("Name") }
		for i=1:1:$g(tFiles) {
			set tFile=tFiles(i)
			set tOne=..LoadFile(tFile,.tRunId,pOrigin,pForce)
			set tLogStatus=..LastLogStatus(tFile)
			if $$$ISERR(tOne) {
				set tErr=tErr+1,pSummary=pSummary_"ERROR "_##class(%File).GetFilename(tFile)_": "_$system.Status.GetErrorText(tOne)_$c(13,10)
				if pArchive,tSet.ErrorDir'="" do ..MoveFile(tFile,tSet.ErrorDir)
			} else {
				if tLogStatus="Skipped" { set tSkip=tSkip+1 } else { set tOK=tOK+1 }
				set pSummary=pSummary_$s(tLogStatus="Skipped":"SKIPPED ",1:"OK ")_##class(%File).GetFilename(tFile)_" -> run "_tRunId_$c(13,10)
				if pArchive,tSet.ArchiveDir'="" do ..MoveFile(tFile,tSet.ArchiveDir)
			}
		}
		set pSummary="Loaded "_tOK_", skipped "_tSkip_", failed "_tErr_$c(13,10)_pSummary
		set tSet.LastScanTS=$zdt($h,3) do tSet.%Save()
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

ClassMethod LoadInbox(Output pSummary As %String, pOrigin As %String = "Task") As %Status
{
	quit ..LoadDirectory("",1,.pSummary,pOrigin)
}

/// Background job entry for "Scan inbox now"
ClassMethod BackgroundInbox()
{
	do ..LoadDirectory("",1,.tSummary,"Manual")
}

ClassMethod LastLogStatus(pFile As %String) As %String
{
	&sql(SELECT TOP 1 Status INTO :tS FROM SysPerf_Data.LoadLog WHERE FilePath=:pFile ORDER BY ID DESC)
	quit $s(SQLCODE=0:tS,1:"")
}

/// Move a file into a folder (adds a timestamp suffix when the name already exists)
ClassMethod MoveFile(pFile As %String, pDir As %String) As %Boolean
{
	set tDir=##class(%File).NormalizeDirectory(pDir)
	do:'##class(%File).DirectoryExists(tDir) ##class(%File).CreateDirectoryChain(tDir)
	set tName=##class(%File).GetFilename(pFile),tTarget=tDir_tName
	if ##class(%File).Exists(tTarget) set tTarget=tDir_$p(tName,".",1,$l(tName,".")-1)_"_"_$tr($zdt($h,8)," :","_")_"."_$p(tName,".",$l(tName,"."))
	quit ##class(%File).Rename(pFile,tTarget)
}

/// Save an uploaded stream into the inbox and load it (in the background when configured).
/// Returns the LoadLog id to poll.
/// pKind: SystemPerformance | PERFMON (the file must be of this type) | "" (any)
ClassMethod LoadUpload(pStream As %Stream.Object, pFileName As %String, pForce As %Boolean = 0, Output pLogId As %Integer, Output pRunId As %Integer, pKind As %String = "") As %Status
{
	set tSC=$$$OK,pLogId="",pRunId=""
	try {
		set tSet=##class(SysPerf.Config.Settings).Get()
		set tSC=tSet.EnsureDirs() quit:$$$ISERR(tSC)
		// sanitise the client file name (no path parts, safe characters only)
		set tName=$tr(pFileName,"\","/"),tName=$p(tName,"/",$l(tName,"/"))
		set tName=$zstrip(tName,"*C"),tName=$tr(tName,":*?""<>|;&$`'","____________")
		if tName="" set tName="upload.html"
		set tExt=$zcvt($p(tName,".",$l(tName,".")),"L")
		if (tExt'="html")&&(tExt'="htm") set tSC=$$$ERROR($$$GeneralError,"Only .html/.htm reports are accepted") quit
		if pStream.Size>(tSet.MaxUploadMB*1048576) set tSC=$$$ERROR($$$GeneralError,"File exceeds the maximum upload size of "_tSet.MaxUploadMB_" MB") quit
		set tTarget=tSet.InboxDir_"upload_"_$tr($zdt($h,8)," :","_")_"_"_$job_"_"_tName
		set tFile=##class(%Stream.FileBinary).%New()
		set tSC=tFile.LinkToFile(tTarget) quit:$$$ISERR(tSC)
		do pStream.Rewind()
		set tSC=tFile.CopyFromAndSave(pStream) quit:$$$ISERR(tSC)
		kill tFile
		set tIsPM=##class(SysPerf.PM.Parser).IsPerfmon(tTarget)
		if pKind="PERFMON",'tIsPM do ##class(%File).Delete(tTarget) set tSC=$$$ERROR($$$GeneralError,"Not a PERFMON report. Load ^SystemPerformance files on SystemPerformance > Load SystemPerformance Files.") quit
		if pKind="SystemPerformance",tIsPM do ##class(%File).Delete(tTarget) set tSC=$$$ERROR($$$GeneralError,"This is a PERFMON report. Load it on PERFMON > Load PERFMON Files.") quit
		set tLog=##class(SysPerf.Data.LoadLog).%New()
		set tLog.FilePath=tTarget,tLog.FileName=tName,tLog.Origin="Upload",tLog.Status="Queued",tLog.FileSize=pStream.Size,tLog.Kind=$s(tIsPM:"PERFMON",1:"SystemPerformance")
		set tSC=tLog.%Save() quit:$$$ISERR(tSC)
		set pLogId=tLog.%Id()
		if tSet.BackgroundLoad {
			job ##class(SysPerf.Loader).BackgroundLoad(tTarget,pLogId,pForce)::10
			if '$test {
				// could not start a job (e.g. license or process limit) - load in this process instead
				set tSC=..LoadFile(tTarget,.pRunId,"Upload",pForce,pLogId)
				do ..ArchiveAfterLoad(tTarget,tSC)
			}
		} else {
			set tSC=..LoadFile(tTarget,.pRunId,"Upload",pForce,pLogId)
			do ..ArchiveAfterLoad(tTarget,tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Background job entry (JOB command)
ClassMethod BackgroundLoad(pFile As %String, pLogId As %Integer, pForce As %Boolean = 0)
{
	set tSC=..LoadFile(pFile,.tRunId,"Upload",pForce,pLogId)
	do ..ArchiveAfterLoad(pFile,tSC)
}

ClassMethod ArchiveAfterLoad(pFile As %String, pSC As %Status) [ Private ]
{
	set tSet=##class(SysPerf.Config.Settings).Get()
	if $$$ISERR(pSC) { do:tSet.ErrorDir'="" ..MoveFile(pFile,tSet.ErrorDir) }
	else { do:tSet.ArchiveDir'="" ..MoveFile(pFile,tSet.ArchiveDir) }
}

/// Re-run roll-ups and analyzer for one run (after threshold changes) - pRunId="" = all runs
ClassMethod Reanalyze(pRunId As %String = "") As %Status
{
	set tSC=$$$OK
	if pRunId'="" {
		set tSC=##class(SysPerf.Rollup).Build(pRunId) quit:$$$ISERR(tSC) tSC
		quit ##class(SysPerf.Analyzer).Analyze(pRunId)
	}
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM SysPerf_Data.Run WHERE Status='OK'")
	while tRS.%Next() { set tSC=$$$ADDSC(tSC,..Reanalyze(tRS.ID)) }
	quit tSC
}

/// Delete runs older than RetentionDays (by run start). Returns number deleted.
ClassMethod PurgeOld(Output pCount As %Integer) As %Status
{
	set tSC=$$$OK,pCount=0
	set tDays=##class(SysPerf.Config.Settings).Get().RetentionDays
	quit:tDays<1 tSC
	set tCut=$zd($h-tDays,3)_" 00:00:00"
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM SysPerf_Data.Run WHERE StartTS < ? OR (Status<>'OK' AND LoadedTS < ?)",tCut,$zdt($h-1,3))
	while tRS.%Next() { set tSC=$$$ADDSC(tSC,##class(SysPerf.Data.Run).Purge(tRS.ID)) set pCount=pCount+1 }
	// loads that never finished (process killed / server restart)
	set tStale=$zdt($h-1,3)
	&sql(UPDATE SysPerf_Data.LoadLog SET Status='Error', Message='Load did not complete (process ended)' WHERE Status IN ('Queued','Running') AND StartTS < :tStale)
	// trim load log as well
	&sql(DELETE %NOLOCK FROM SysPerf_Data.LoadLog WHERE StartTS < :tCut)
	quit tSC
}

/// Mark load-log rows whose job is gone as failed: Running with a dead PID, or Queued for more than 30 minutes.
ClassMethod CloseStale()
{
	try {
		set tCut=##class(SysPerf.Util).AddSec($zdt($h,3),-1800)
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Status,StartTS,JobPID FROM SysPerf_Data.LoadLog WHERE Status IN ('Queued','Running')")
		while tRS.%Next() {
			set tDead=$s(tRS.Status="Running":(tRS.JobPID'="")&&'$d(^$JOB(tRS.JobPID)),1:tRS.StartTS']tCut)
			set:(tRS.Status="Running")&&(tRS.JobPID="")&&(tRS.StartTS']tCut) tDead=1
			continue:'tDead
			set l=##class(SysPerf.Data.LoadLog).%OpenId(tRS.ID) continue:'$isobject(l)
			set l.Status="Error",l.Message="Load did not complete (the loading process ended, e.g. instance restart)",l.EndTS=$zdt($h,3) do l.%Save()
		}
	} catch {}
}

}
