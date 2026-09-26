/// Runs PERFMON timed collections ($$Collect^PERFMON in %SYS) from the portal or a task,
/// then loads the HTML report into the SysPerf.PM tables.
/// Only one collection can run at a time (PERFMON is instance-wide).
Class SysPerf.PM.Collector [ Abstract ]
{

Parameter MINSECONDS = 10;

Parameter MAXSECONDS = 3600;

/// Queue a collection in a background job. Returns the request id to poll.
ClassMethod Start(pSeconds As %Integer, Output pReqId As %Integer, pOrigin As %String = "Portal") As %Status
{
	set tSC=$$$OK,pReqId=""
	try {
		set tSC=..Validate(pSeconds) quit:$$$ISERR(tSC)
		set tSC=..CheckIdle() quit:$$$ISERR(tSC)
		set r=##class(SysPerf.PM.CollectRequest).%New()
		set r.DurationSec=pSeconds,r.Origin=pOrigin
		set tSC=r.%Save() quit:$$$ISERR(tSC)
		set pReqId=r.%Id()
		job ##class(SysPerf.PM.Collector).Run(pReqId)::10
		if '$test {
			set r.Status="Error",r.Message="Could not start the background job (process or license limit)",r.EndTS=$zdt($h,3) do r.%Save()
			set tSC=$$$ERROR($$$GeneralError,r.Message)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Synchronous collection (used by the job and by the scheduled task)
ClassMethod Run(pReqId As %Integer) As %Status
{
	set tSC=$$$OK
	set r=##class(SysPerf.PM.CollectRequest).%OpenId(pReqId)
	quit:'$isobject(r) $$$ERROR($$$GeneralError,"Request not found")
	lock +^SysPerf.PMCollect:2
	if '$test {
		set r.Status="Error",r.Message="Another PERFMON collection is running",r.EndTS=$zdt($h,3) do r.%Save()
		quit $$$ERROR($$$GeneralError,r.Message)
	}
	try {
		set r.Status="Collecting",r.StartTS=$zdt($h,3),r.JobPID=$job do r.%Save()
		set tSet=##class(SysPerf.Config.Settings).Get()
		do tSet.EnsureDirs()
		set tDir=$s(tSet.ArchiveDir'="":tSet.ArchiveDir,1:tSet.InboxDir)
		set tFile=##class(%File).NormalizeFilename("PERFMON_"_$tr(##class(%SYS.System).GetInstanceName()," ","_")_"_"_$tr($zdt($h,8)," :","_")_".html",tDir)
		set r.OutputFile=tFile do r.%Save()
		set tRC=..Collect(r.DurationSec,tFile)
		if tRC'=1 {
			set tSC=$$$ERROR($$$GeneralError,"PERFMON collection failed: "_$p(tRC,",",2,*))
			quit
		}
		set r.Status="Loading" do r.%Save()
		set tSC=##class(SysPerf.PM.Loader).LoadFile(tFile,.tId,"Timed")
		quit:$$$ISERR(tSC)
		set r.CollectionId=tId,r.Status="Done",r.Message="Collected "_r.DurationSec_" s and loaded as collection "_tId
	} catch ex { set tSC=ex.AsStatus() }
	if $$$ISERR(tSC) set r.Status="Error",r.Message=$system.Status.GetErrorText(tSC)
	set r.EndTS=$zdt($h,3) do r.%Save()
	lock -^SysPerf.PMCollect
	quit tSC
}

/// Run $$Collect^PERFMON in %SYS. Returns 1 or "negative,message".
ClassMethod Collect(pSeconds As %Integer, pFile As %String) As %String
{
	new $namespace
	set tRC=""
	try {
		set $namespace="%SYS"
		// PERFMON prints progress to the principal device; send it to the null device
		set tDev=$s($zversion(1)=2:"//./nul",1:"/dev/null")
		// $zu(84,8)=1: the performance monitor is already active (PERFMON started interactively, another tool)
		if $zu(84,8) set tRC="-2,The performance monitor is already running (started by PERFMON or another tool). Stop it with do Stop^PERFMON in %SYS, or wait until it ends." quit
		set tStarted=1
		open tDev use tDev
		set tRC=$$Collect^PERFMON(pSeconds,"HTML",pFile)
		close tDev
	} catch ex {
		try { close:$g(tDev)'="" tDev } catch {}
		set tRC="-1,"_ex.DisplayString()
	}
	// never leave a monitor running that this call started
	if tRC'=1,$g(tStarted) {
		try { if $zu(84,8) set x=$$Stop^PERFMON() } catch {}
		if tRC["already running" set tRC="-3,PERFMON could not start collecting. The collecting user needs Read/Write on %DB_IRISSYS (role SysPerfCollector) - PERFMON reported: "_$p(tRC,",",2,*)
	}
	quit tRC
}

ClassMethod Validate(pSeconds) As %Status
{
	if (pSeconds'?1.N)||(pSeconds<..#MINSECONDS)||(pSeconds>..#MAXSECONDS) quit $$$ERROR($$$GeneralError,"Duration must be "_..#MINSECONDS_"-"_..#MAXSECONDS_" seconds")
	quit $$$OK
}

/// Error when a collection is already queued / running
ClassMethod CheckIdle() As %Status
{
	// stale requests (job died) are closed after duration + 10 minutes
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,DurationSec,RequestedTS,JobPID FROM SysPerf_PM.CollectRequest WHERE Status IN ('Queued','Collecting','Loading')")
	set tBusy=0
	while tRS.%Next() {
		set tAge=##class(SysPerf.Util).DiffSec(tRS.RequestedTS,$zdt($h,3))
		if tAge>(tRS.DurationSec+600) {
			set r=##class(SysPerf.PM.CollectRequest).%OpenId(tRS.ID) set r.Status="Error",r.Message="Did not complete (job ended)",r.EndTS=$zdt($h,3) do r.%Save()
			continue
		}
		set tBusy=tRS.ID
	}
	quit $s(tBusy:$$$ERROR($$$GeneralError,"A PERFMON collection is already in progress (request "_tBusy_")"),1:$$$OK)
}

}
