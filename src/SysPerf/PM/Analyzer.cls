/// Rules for PERFMON collections: hot globals, cache misses, journal / update hot spots,
/// runtime class-dictionary access, SQL temp usage, hot routines, cached-query load,
/// routine call overhead, dominant processes and lock waits.
Class SysPerf.PM.Analyzer [ Abstract ]
{

ClassMethod Analyze(pId As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set c=##class(SysPerf.PM.Collection).%OpenId(pId)
		if '$isobject(c) set tSC=$$$ERROR($$$GeneralError,"Collection not found") quit
		kill tAck
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Code,Subject,AckBy,AckTS,AckNote FROM SysPerf_PM.Finding WHERE Coll=? AND Acknowledged=1",pId)
		while tRS.%Next() { set tAck(tRS.Code,tRS.Subject_" ")=$lb(tRS.AckBy,tRS.AckTS,tRS.AckNote) }
		&sql(DELETE FROM SysPerf_PM.Finding WHERE Coll=:pId)
		do ##class(SysPerf.Config.Threshold).Seed()
		kill ^||PF
		set ctx("id")=pId,ctx("c")=c,ctx("dur")=$s(c.DurationSec>0:c.DurationSec,1:1)
		for tRule="Collection","Globals","Dictionary","Routines","Processes","Databases" {
			try { do $classmethod($classname(),"Rule"_tRule,.ctx) }
			catch exR { do ..Add(.ctx,"I","Analyzer","ANALYZER","","Rule group "_tRule_" could not be evaluated",exR.DisplayString(),"","","","","") }
		}
		set (tC,tW,tI)=0
		for i=1:1:$g(^||PF) {
			set f=^||PF(i),o=##class(SysPerf.PM.Finding).%New()
			do o.CollSetObjectId(pId)
			set o.Rank=i,o.Severity=$li(f,1),o.Category=$li(f,2),o.Code=$li(f,3),o.Subject=$e($li(f,4),1,500),o.Title=$e($li(f,5),1,500),o.Detail=$li(f,6),o.Recommendation=$li(f,7),o.Evidence=$li(f,8),o.MetricValue=$li(f,9),o.Threshold=$li(f,10),o.DrillTab=$li(f,11)
			if $d(tAck(o.Code,o.Subject_" ")) set a=tAck(o.Code,o.Subject_" "),o.Acknowledged=1,o.AckBy=$li(a,1),o.AckTS=$li(a,2),o.AckNote=$li(a,3)
			set tSC=o.%Save() quit:$$$ISERR(tSC)
			set:o.Severity="C" tC=tC+1
			set:o.Severity="W" tW=tW+1
			set:o.Severity="I" tI=tI+1
		}
		quit:$$$ISERR(tSC)
		set c.CriticalCount=tC,c.WarningCount=tW,c.InfoCount=tI
		// score on distinct rules so one noisy rule (e.g. 5 hot globals) does not zero the score
		&sql(SELECT COUNT(DISTINCT Code) INTO :tDC FROM SysPerf_PM.Finding WHERE Coll=:pId AND Severity='C')
		&sql(SELECT COUNT(DISTINCT Code) INTO :tDW FROM SysPerf_PM.Finding WHERE Coll=:pId AND Severity='W')
		set tScore=100-(tDC*15)-(tDW*5) set:tScore<0 tScore=0
		set c.HealthScore=tScore,c.AnalyzedTS=$zdt($h,3)
		set tSC=c.%Save()
		kill ^||PF
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Sev, Category, Code, Subject, Title, Detail, Recommendation, Evidence, Value, Threshold, Drill tab
ClassMethod Add(ByRef ctx, pSev, pCat, pCode, pSubject, pTitle, pDetail, pRec, pEvidence, pValue, pThr, pDrill)
{
	set ^||PF($i(^||PF))=$lb(pSev,pCat,pCode,pSubject,pTitle,pDetail,pRec,pEvidence,pValue,pThr,pDrill)
}

ClassMethod F(v, d As %Integer = 1) As %String [ CodeMode = expression ]
{
$s(v="":"n/a",1:$fn(v,",",d))
}

/// Top N rows of a PM table as evidence text
ClassMethod Top(pSQL As %String, pId As %Integer, pFmt As %String) As %String
{
	set tOut="",tRS=##class(%SQL.Statement).%ExecDirect(,pSQL,pId)
	while tRS.%Next() {
		set l=pFmt
		for i=1:1:tRS.%GetMetadata().columns.Count() { set v=tRS.%GetData(i) set l=$replace(l,"{"_i_"}",$s(##class(SysPerf.Util).IsNum(v)&&(v'?1.N):$fn(v,",",1),##class(SysPerf.Util).IsNum(v):$fn(v,","),1:v)) }
		set tOut=tOut_l_$c(10)
	}
	quit tOut
}

// ---------------------------------------------------------------- rules

ClassMethod RuleCollection(ByRef ctx)
{
	set c=ctx("c")
	if c.DurationSec<30 do ..Add(.ctx,"I","Collection","PM_SHORT","","Collection covers only "_c.DurationSec_" seconds","Short collections may miss periodic work (batch jobs, purges, task manager runs).","Collect 30-120 seconds while the problem is happening; for recurring issues schedule collections (Task Manager > SysPerf PERFMON collection) at the busy hour.","","","","")
	set tRefs=c.TotalGloRefs/ctx("dur"),tLines=c.TotalRtnLines/ctx("dur"),tPhy=c.TotalPhyBlkRd/ctx("dur"),tJrn=c.TotalJrnEntry/ctx("dur")
	set tEv="Global references: "_..F(tRefs,0)_"/s"_$c(10)_"Global sets: "_..F(c.TotalGloSets/ctx("dur"),0)_"/s, kills: "_..F(c.TotalGloKills/ctx("dur"),0)_"/s"_$c(10)_"Logical block reads: "_..F(c.TotalLogBlkRd/ctx("dur"),0)_"/s, physical block reads: "_..F(tPhy,0)_"/s, physical writes: "_..F(c.TotalPhyBlkWrt/ctx("dur"),0)_"/s"_$c(10)_"Journal entries: "_..F(tJrn,0)_"/s, blocks allocated: "_..F(c.TotalBlkAlloc/ctx("dur"),0)_"/s"_$c(10)_"Routine lines: "_..F(tLines,0)_"/s, routine loads: "_..F(c.TotalRtnLoads/ctx("dur"),0)_"/s"_$c(10)_"Processes: "_c.ProcessCount
	do ..Add(.ctx,"I","Collection","PM_SUMMARY","","Workload: "_..F(tRefs,0)_" global refs/s, "_..F(tPhy,0)_" physical reads/s, "_..F(tLines,0)_" routine lines/s","Totals over the "_c.DurationSec_" second collection (top-N rows plus 'Other').","",tEv,tRefs,"","globals")
}

ClassMethod RuleGlobals(ByRef ctx)
{
	set id=ctx("id"),d=ctx("dur")
	// hot global (share of refs)
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 3 GlobalName,PctRefs,TotRefs,Directory,RefsPerSec FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 ORDER BY TotRefs DESC",id)
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_HOT_GLOBAL",tRS.PctRefs,.tThr) continue:tSev=""
		set tCallers=..Top("SELECT TOP 5 Routine,PctRefs,TotRefs FROM SysPerf_PM.RoutineGlobal WHERE Coll=? AND IsOther=0 ORDER BY TotRefs DESC",id,"{1}: {2}% of refs ({3})")
		do ..Add(.ctx,tSev,"Globals","PM_HOT_GLOBAL",tRS.GlobalName,"^"_tRS.GlobalName_" receives "_..F(tRS.PctRefs)_"% of all global references ("_..F(tRS.RefsPerSec,0)_"/s)","Database "_tRS.Directory_". A single global dominating the reference count is the first place to look for inefficient loops, repeated lookups of the same data or missing caching.","Review the code that reads this global (see the routines below and the Global x Routine tab). Typical fixes: cache static data in a process variable or ^||PPG, avoid re-reading inside loops, add an index instead of scanning, use $ORDER with a narrower subscript range.","Top routines by global references:"_$c(10)_tCallers,tRS.PctRefs,tThr,"globals")
	}
	// physical reads per global
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 5 GlobalName,PhyBlkRd,PhyRdPerSec,LogBlkRd,MissPct,Directory,TotRefs FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 ORDER BY PhyBlkRd DESC",id)
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_GLOBAL_PHYRD",tRS.PhyRdPerSec,.tThr) continue:tSev=""
		set tScan=(tRS.PhyBlkRd>tRS.LogBlkRd)
		set tCallers=..Top("SELECT TOP 5 Routine,PhyBlkRd,PhyRdPerSec FROM SysPerf_PM.RoutineGlobal WHERE Coll=? AND IsOther=0 AND PhyBlkRd>0 ORDER BY PhyBlkRd DESC",id,"{1}: {2} physical reads ({3}/s)")
		set tDetail="Database "_tRS.Directory_". "_..F(tRS.PhyBlkRd,0)_" physical block reads vs "_..F(tRS.LogBlkRd,0)_" logical block reads (physical = "_..F(tRS.MissPct,1)_"% of logical)."_$s(tScan:" More physical than logical reads means read-ahead / sequential scanning of a large range (typically a full table scan or a report over historical data).",1:" The data is not staying in the global buffer cache.")
		do ..Add(.ctx,tSev,"Globals","PM_GLOBAL_PHYRD",tRS.GlobalName,"^"_tRS.GlobalName_" causes "_..F(tRS.PhyRdPerSec,0)_" physical block reads per second",tDetail,"Find the query / code scanning it (routines below; %sqlcq routines can be looked up in System Explorer > SQL > SQL Statements by routine name) and add a selective index or restrict the date range. Archive or purge historical data kept in this global. Only if the hot working set legitimately exceeds the cache, increase global buffers.","Top routines by physical reads:"_$c(10)_tCallers,tRS.PhyRdPerSec,tThr,"globals")
	}
	// journal hot spots
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 5 GlobalName,JrnEntry,JrnPerSec,GloSet,GloKill,Directory FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 AND JrnEntry>0 ORDER BY JrnEntry DESC",id)
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_GLOBAL_JRN",tRS.JrnPerSec,.tThr)
		set tU=$zcvt(tRS.GlobalName,"U"),tTemp=(tU["TEMP")||(tU["TMP")||(tU["CACHE")||(tU["QUEUE")||(tU["SESSION")||(tU["BUFFER")||(tU["WORK")
		continue:(tSev="")&&('tTemp)
		set:tSev="" tSev="I"
		do ..Add(.ctx,tSev,"Globals","PM_GLOBAL_JRN",tRS.GlobalName,"^"_tRS.GlobalName_" writes "_..F(tRS.JrnPerSec,0)_" journal entries per second"_$s(tTemp:" (name suggests transient data)",1:""),"Database "_tRS.Directory_". Sets "_..F(tRS.GloSet,0)_", kills "_..F(tRS.GloKill,0)_" during the collection. Every journal entry is disk I/O and grows journal files, mirror traffic and restore time.",$s(tTemp:"If this global holds scratch / cache / queue data that does not need recovery, map it to a non-journaled database (or IRISTEMP / process-private globals ^||name).",1:"Check whether all these updates are needed (e.g. audit / monitoring rows written per message); batch updates, or move audit data to a separate journaled database with its own retention."),"",tRS.JrnPerSec,tThr,"globals")
	}
	// update-heavy globals
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 3 GlobalName,UpdPerSec,GloSet,GloKill,Directory FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 ORDER BY (GloSet+GloKill) DESC",id)
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_GLOBAL_UPD",tRS.UpdPerSec,.tThr) continue:tSev=""
		set tCallers=..Top("SELECT TOP 5 Routine,GloSet,GloKill FROM SysPerf_PM.RoutineGlobal WHERE Coll=? AND IsOther=0 AND GloSet+GloKill>0 ORDER BY GloSet+GloKill DESC",id,"{1}: {2} sets, {3} kills")
		do ..Add(.ctx,tSev,"Globals","PM_GLOBAL_UPD",tRS.GlobalName,"^"_tRS.GlobalName_" is updated "_..F(tRS.UpdPerSec,0)_" times per second","Sets "_..F(tRS.GloSet,0)_", kills "_..F(tRS.GloKill,0)_" in database "_tRS.Directory_".","High update rates on one global create write-daemon load and block contention. Check for rebuilding the same temporary structure repeatedly (e.g. a query or report executed per message).","Top updating routines:"_$c(10)_tCallers,tRS.UpdPerSec,tThr,"globals")
	}
	// block allocation (growth)
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 3 GlobalName,BlkAlloc,Directory FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 AND BlkAlloc>0 ORDER BY BlkAlloc DESC",id)
	while tRS.%Next() {
		set tPer=tRS.BlkAlloc/d
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_BLKALLOC",tPer,.tThr) continue:tSev=""
		set tIsTemp=($zcvt(tRS.Directory,"L")["iristemp")||($zcvt(tRS.Directory,"L")["cachetemp")
		if tIsTemp {
			do ..Add(.ctx,$s(tSev="C":"W",1:"I"),"Globals","PM_BLKALLOC",tRS.GlobalName,"^"_tRS.GlobalName_" allocates "_..F(tPer,0)_" IRISTEMP blocks per second","Temporary data in "_tRS.Directory_" (about "_..F(tPer*8*3600/1024,0)_" MB per hour if sustained). IRISTEMP is reset at restart, but fast growth fills its disk and churns the buffer pool.",$s(tRS.GlobalName["Stream":"Temporary streams (%IRIS.Stream / %Stream.TmpCharacter) are created for large messages / SOAP payloads - make sure they are not kept longer than needed and not copied repeatedly.",1:"Find the code building this temporary structure (Global x Routine tab) and check it is killed after use and not rebuilt per request."),"",tPer,tThr,"databases")
			continue
		}
		do ..Add(.ctx,tSev,"Globals","PM_BLKALLOC",tRS.GlobalName,"^"_tRS.GlobalName_" allocates "_..F(tPer,0)_" new blocks per second","Database "_tRS.Directory_" grows by about "_..F(tPer*8*3600/1024,0)_" MB per hour at this rate (8 KB blocks).","Confirm the growth is expected; plan purge / archive, and pre-expand the database to avoid expansion during peak.","",tPer,tThr,"databases")
	}
	// SQL / temp globals
	&sql(SELECT SUM(TotRefs) INTO :tTmp FROM SysPerf_PM.GlobalStat WHERE Coll=:id AND IsOther=0 AND (GlobalName %STARTSWITH '%ISCQueryTemp' OR GlobalName %STARTSWITH 'IRIS.Temp' OR GlobalName %STARTSWITH 'CacheTemp' OR GlobalName %STARTSWITH 'IRIS.TempNoJrn' OR GlobalName %STARTSWITH 'mtemp'))
	set tTot=ctx("c").TotalGloRefs
	if tTot>0,tTmp>0 {
		set tPct=$fn(tTmp*100/tTot,"",1)
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_SQL_TEMP",tPct,.tThr)
		set tEv=..Top("SELECT TOP 5 GlobalName,TotRefs,GloSet,BlkAlloc FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 AND (GlobalName %STARTSWITH '%ISCQueryTemp' OR GlobalName %STARTSWITH 'IRIS.Temp' OR GlobalName %STARTSWITH 'CacheTemp' OR GlobalName %STARTSWITH 'mtemp') ORDER BY TotRefs DESC",id,"{1}: {2} refs, {3} sets, {4} blocks allocated")
		set tEv=tEv_"Top routines creating temporary data:"_$c(10)_..Top("SELECT TOP 5 Routine,GloSet,BlkAlloc FROM SysPerf_PM.RoutineGlobal WHERE Coll=? AND IsOther=0 AND GloSet>0 ORDER BY GloSet DESC",id,"{1}: {2} sets, {3} blocks allocated")
		do ..Add(.ctx,$s(tSev="":"I",1:tSev),"Globals","PM_SQL_TEMP","","Temporary / SQL work globals take "_tPct_"% of global references","SQL sorts, DISTINCT / GROUP BY and some class queries materialise results in %ISCQueryTemp / IRIS.Temp* (IRISTEMP).","Review the queries of the routines below: add indexes that match ORDER BY / GROUP BY, avoid SELECT DISTINCT on large sets, and avoid running catalogue queries (e.g. %Library.ClassDefinition / %Dictionary queries) repeatedly at runtime.",tEv,tPct,$g(tThr),"globals")
	}
}

ClassMethod RuleDictionary(ByRef ctx)
{
	set id=ctx("id"),tTot=ctx("c").TotalGloRefs
	quit:tTot'>0
	&sql(SELECT SUM(TotRefs) INTO :tDict FROM SysPerf_PM.GlobalStat WHERE Coll=:id AND IsOther=0 AND (GlobalName %STARTSWITH 'odd' OR GlobalName %STARTSWITH 'rINDEX' OR GlobalName %STARTSWITH 'rOBJ' OR GlobalName %STARTSWITH 'IRIS.Msg'))
	quit:tDict'>0
	set tPct=$fn(tDict*100/tTot,"",1)
	set tSev=##class(SysPerf.Config.Threshold).Classify("PM_DICT_REFS",tPct,.tThr)
	&sql(SELECT SUM(GloSet+GloKill) INTO :tDictUpd FROM SysPerf_PM.GlobalStat WHERE Coll=:id AND IsOther=0 AND (GlobalName %STARTSWITH 'odd' OR GlobalName %STARTSWITH 'rINDEX' OR GlobalName %STARTSWITH 'rOBJ'))
	if tDictUpd>0 {
		do ..Add(.ctx,$s(tSev="":"I",1:"W"),"Globals","PM_COMPILE","","Classes or routines were being compiled / imported during the collection","The class dictionary globals were updated "_..F(tDictUpd,0)_" times, which only happens when code is compiled, imported or a class is (re)defined at runtime.","Avoid compiling or deploying code on production during business hours; if an application defines classes at runtime (e.g. dynamic SQL table creation, %Dictionary saves), move that to deployment time.","",tDictUpd,"","globals")
		quit
	}
	set tEv="Dictionary globals:"_$c(10)_..Top("SELECT TOP 8 GlobalName,TotRefs,PctRefs,Directory FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 AND (GlobalName %STARTSWITH 'odd' OR GlobalName %STARTSWITH 'rINDEX' OR GlobalName %STARTSWITH 'rOBJ' OR GlobalName %STARTSWITH 'IRIS.Msg') ORDER BY TotRefs DESC",id,"^{1}: {2} refs ({3}%) {4}")
	set tEv=tEv_"Routines doing the most global references (likely callers):"_$c(10)_..Top("SELECT TOP 6 Routine,TotRefs,PctRefs FROM SysPerf_PM.RoutineGlobal WHERE Coll=? AND IsOther=0 ORDER BY TotRefs DESC",id,"{1}: {2} refs ({3}%)")
	do ..Add(.ctx,$s(tSev="":"OK",1:tSev),"Globals","PM_DICT_REFS","","Class dictionary globals take "_tPct_"% of all global references","^oddCOM / ^oddDEF / ^oddXML / ^rINDEX are the compiled class metadata. Applications normally read them only at compile time; heavy runtime access means code is doing reflection on every call - e.g. $CLASSMETHOD/$PROPERTY with metadata lookups, %Dictionary.* or %Library.ClassDefinition objects/queries, %XML.Adaptor / %JSON.Adaptor export of dynamic classes, or $$$comMemberKeyGet style macros in a loop.",$s(tSev="":"",1:"Find the caller in the routines listed (Global x Routine tab) and cache the metadata result once per process (e.g. in a process-private global ^||cache or a class parameter), or generate code at compile time instead of looking it up at runtime. Avoid opening %Dictionary / %Library.ClassDefinition objects inside message processing loops."),tEv,tPct,$g(tThr),"routines")
}

ClassMethod RuleRoutines(ByRef ctx)
{
	set id=ctx("id"),d=ctx("dur"),c=ctx("c")
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 3 Routine,PctLines,RtnLines,LinesPerSec,RtnLoads,IsSQL,ClassName FROM SysPerf_PM.RoutineStat WHERE Coll=? AND IsOther=0 ORDER BY RtnLines DESC",id)
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_HOT_ROUTINE",tRS.PctLines,.tThr) continue:tSev=""
		do ..Add(.ctx,tSev,"Routines","PM_HOT_ROUTINE",tRS.Routine,tRS.Routine_" executes "_..F(tRS.PctLines)_"% of all lines ("_..F(tRS.LinesPerSec,0)_" lines/s)",$s(tRS.IsSQL:"This is a cached SQL query routine - one SQL statement is using a large share of CPU.",tRS.ClassName'="":"Class "_tRS.ClassName_".",1:""),$s(tRS.IsSQL:"Look the routine name up in System Explorer > SQL > SQL Statements (or INFORMATION_SCHEMA.STATEMENTS) to get the statement text and plan; check for full table scans, missing indexes or outdated TuneTable statistics.",1:"Profile the method with ^%SYS.MONLBL (line-by-line monitor) during a busy period to find the expensive lines; look for loops over large collections, repeated string concatenation, or per-message object opens that can be cached."),"",tRS.PctLines,tThr,"routines")
	}
	&sql(SELECT SUM(PctLines),SUM(RtnLines) INTO :tSqlPct,:tSqlLines FROM SysPerf_PM.RoutineStat WHERE Coll=:id AND IsOther=0 AND IsSQL=1)
	if tSqlPct>0 {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_SQL_LINES",tSqlPct,.tThr)
		set tEv=..Top("SELECT TOP 8 Routine,RtnLines,PctLines FROM SysPerf_PM.RoutineStat WHERE Coll=? AND IsOther=0 AND IsSQL=1 ORDER BY RtnLines DESC",id,"{1}: {2} lines ({3}%)")
		do ..Add(.ctx,$s(tSev="":"I",1:tSev),"Routines","PM_SQL_LINES","","Cached SQL queries execute "_$fn(tSqlPct,"",1)_"% of all routine lines","SQL statements (routines %sqlcq.<namespace>.*) account for this share of the CPU work measured by PERFMON.","Map each routine to its statement (SQL Statements list, filter by routine), then check the query plan. A few statements dominating is common - tuning the top one or two often gives the biggest gain.",tEv,tSqlPct,$g(tThr),"routines")
	}
	// routine call overhead per process
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 3 PID,RtnLoads,RtnLines,LinePerLoad,Routine,Namespace,UserName FROM SysPerf_PM.ProcessStat WHERE Coll=? AND IsOther=0 ORDER BY RtnLoads DESC",id)
	while tRS.%Next() {
		set tPer=tRS.RtnLoads/d
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_RTN_LOADS",tPer,.tThr) continue:tSev=""
		do ..Add(.ctx,$s(tSev="C":"W",1:"I"),"Routines","PM_RTN_LOADS",tRS.PID,"Process "_tRS.PID_" loads routines "_..F(tPer,0)_" times per second (only "_..F(tRS.LinePerLoad)_" lines per load)","Current routine "_tRS.Routine_" in "_tRS.Namespace_", user "_tRS.UserName_". Very short routines / methods called in tight loops spend time on call overhead.","Usually harmless for object-oriented code, but in hot paths consider inlining small helper methods (CodeMode=expression), reducing $CLASSMETHOD / indirection calls, and making sure routine buffers are large enough (mgstat RouLaS near 0).","",tPer,tThr,"processes")
	}
}

ClassMethod RuleProcesses(ByRef ctx)
{
	set id=ctx("id")
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 3 PID,PctRefs,TotRefs,RefsPerSec,PhyBlkRd,Routine,Namespace,UserName,ClientIP,State FROM SysPerf_PM.ProcessStat WHERE Coll=? AND IsOther=0 ORDER BY TotRefs DESC",id)
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("PM_PROC_SHARE",tRS.PctRefs,.tThr) continue:tSev=""
		do ..Add(.ctx,tSev,"Processes","PM_PROC_SHARE",tRS.PID,"Process "_tRS.PID_" does "_..F(tRS.PctRefs)_"% of all global references ("_..F(tRS.RefsPerSec,0)_"/s)","Routine "_tRS.Routine_", namespace "_tRS.Namespace_", user "_tRS.UserName_$s(tRS.ClientIP'="":", client "_tRS.ClientIP,1:"")_", state "_tRS.State_", physical reads "_..F(tRS.PhyBlkRd,0)_".","Identify the job (Management Portal > Processes, PID "_tRS.PID_", or the business host / task that runs it). If it is a batch or purge, schedule it outside peak hours or split the work.","",tRS.PctRefs,tThr,"processes")
	}
	&sql(SELECT COUNT(*) INTO :tLock FROM SysPerf_PM.Process WHERE Coll=:id AND State %STARTSWITH 'LOCK')
	set tSev=##class(SysPerf.Config.Threshold).Classify("PM_LOCK_WAIT",tLock,.tThr)
	if tSev'="" {
		set tEv=..Top("SELECT TOP 10 PID,Routine,Namespace,UserName FROM SysPerf_PM.Process WHERE Coll=? AND State %STARTSWITH 'LOCK'",id,"PID {1}: {2} [{3}] {4}")
		do ..Add(.ctx,tSev,"Processes","PM_LOCK_WAIT","",tLock_" process(es) were waiting for a LOCK","Process state LOCK at collection time.","Open Locks in this portal (System Operation > Locks) while it happens to see the owner; shorten transactions holding locks, use timeouts on LOCK commands, and avoid locking whole globals.",tEv,tLock,tThr,"proclist")
	}
	// state distribution (info)
	set tEv=..Top("SELECT State,COUNT(*) N FROM SysPerf_PM.Process WHERE Coll=? GROUP BY State ORDER BY 2 DESC",id,"{1}: {2}")
	do ..Add(.ctx,"I","Processes","PM_STATES","",ctx("c").ProcessCount_" IRIS processes at collection time","Process states from the Process List (RUN = executing, GORD/GDEF/GGET/GSET = inside a global operation, EVTW/HANG/READ = waiting, LOCK = waiting for a lock).","",tEv,ctx("c").ProcessCount,"","proclist")
}

ClassMethod RuleDatabases(ByRef ctx)
{
	set id=ctx("id")
	set tEv=..Top("SELECT %EXACT(Directory) Dir,SUM(TotRefs) R,SUM(PhyBlkRd) P,SUM(JrnEntry) J,SUM(BlkAlloc) B FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 GROUP BY %EXACT(Directory) ORDER BY 2 DESC",id,"{1}: {2} refs, {3} physical reads, {4} journal entries, {5} blocks allocated")
	do ..Add(.ctx,"I","Databases","PM_DB_HOTSPOT","","Database activity (from the top globals)","Global metrics summed per database directory.","Databases with most physical reads benefit most from fast storage; databases with most journal entries drive journal volume.",tEv,"","","databases")
}

}
