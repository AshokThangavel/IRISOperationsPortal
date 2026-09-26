/// Rules engine: inspects every table of a run and writes <class>SysPerf.Data.Finding</class> rows
/// with severity, evidence and a concrete recommendation. Thresholds come from
/// <class>SysPerf.Config.Threshold</class> (editable in the Admin page).
Class SysPerf.Analyzer [ Abstract ]
{

ClassMethod Analyze(pRunId As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tRun=##class(SysPerf.Data.Run).%OpenId(pRunId)
		if '$isobject(tRun) set tSC=$$$ERROR($$$GeneralError,"Run "_pRunId_" not found") quit
		// keep acknowledgements across re-analysis
		kill tAck
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Code,Title,AckBy,AckTS,AckNote FROM SysPerf_Data.Finding WHERE Run=? AND Acknowledged=1",pRunId)
		while tRS.%Next() { set tAck(tRS.Code)=$lb(tRS.AckBy,tRS.AckTS,tRS.AckNote) }
		&sql(DELETE %NOLOCK FROM SysPerf_Data.Finding WHERE Run=:pRunId)
		kill ^||F
		do ##class(SysPerf.Config.Threshold).Seed()
		set ctx("run")=pRunId,ctx("obj")=tRun
		for tRule="Collection","CPU","Memory","Disk","GlobalBuffers","Routines","WriteDaemon","Journal","Database","Contention","Processes","License","IRISHealth","Config","UnixOS","Virtualization" {
			try {
				do $classmethod($classname(),"Rule"_tRule,.ctx)
			} catch exRule {
				do ..Add(.ctx,"I","Analyzer","ANALYZER","Rule group "_tRule_" could not be evaluated",exRule.DisplayString(),"","","","","")
			}
		}
		// persist
		set (tC,tW,tI)=0
		for i=1:1:$g(^||F) {
			set f=^||F(i)
			set tObj=##class(SysPerf.Data.Finding).%New()
			do tObj.RunSetObjectId(pRunId)
			set tObj.Severity=$li(f,1),tObj.Category=$li(f,2),tObj.Code=$li(f,3),tObj.Title=$e($li(f,4),1,500),tObj.Detail=$li(f,5),tObj.Recommendation=$li(f,6)
			set tObj.Evidence=$li(f,7),tObj.MetricValue=$li(f,8),tObj.Threshold=$li(f,9),tObj.DrillTab=$li(f,10),tObj.FirstTS=$lg(f,11),tObj.LastTS=$lg(f,12),tObj.Occurrences=$lg(f,13)
			if $d(tAck(tObj.Code)) set tObj.Acknowledged=1,tObj.AckBy=$li(tAck(tObj.Code),1),tObj.AckTS=$li(tAck(tObj.Code),2),tObj.AckNote=$li(tAck(tObj.Code),3)
			set tSC=tObj.%Save() quit:$$$ISERR(tSC)
			set:tObj.Severity="C" tC=tC+1
			set:tObj.Severity="W" tW=tW+1
			set:tObj.Severity="I" tI=tI+1
		}
		quit:$$$ISERR(tSC)
		set tRun.CriticalCount=tC,tRun.WarningCount=tW,tRun.InfoCount=tI
		set tScore=100-(tC*15)-(tW*5) set:tScore<0 tScore=0
		set tRun.HealthScore=tScore,tRun.AnalyzedTS=$zdt($h,3)
		set tSC=tRun.%Save()
		kill ^||F
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

// ================================================================ helpers

/// Add a finding. pSev: C/W/I/OK
ClassMethod Add(ByRef ctx, pSev As %String, pCat As %String, pCode As %String, pTitle As %String, pDetail As %String, pRec As %String, pEvidence As %String, pValue As %String, pThreshold As %String, pDrill As %String, pFirst As %String = "", pLast As %String = "", pOcc As %String = "")
{
	set ^||F($i(^||F))=$lb(pSev,pCat,pCode,pTitle,pDetail,pRec,pEvidence,pValue,pThreshold,pDrill,pFirst,pLast,pOcc)
}

/// Evaluate a numeric metric against a threshold rule and add C/W or OK finding
ClassMethod Eval(ByRef ctx, pCode As %String, pValue As %String, pCat As %String, pTitleFmt As %String, pDetail As %String, pRec As %String, pEvidence As %String, pDrill As %String, pFirst As %String = "", pLast As %String = "")
{
	quit:pValue=""
	set tSev=##class(SysPerf.Config.Threshold).Classify(pCode,pValue,.tThr)
	set tTitle=$replace(pTitleFmt,"{v}",##class(SysPerf.Util).R(pValue,2))
	if tSev="" { do ..Add(.ctx,"OK",pCat,pCode,tTitle,pDetail,"",pEvidence,pValue,tThr,pDrill,pFirst,pLast) quit }
	do ..Add(.ctx,tSev,pCat,pCode,tTitle,pDetail,pRec,pEvidence,pValue,tThr,pDrill,pFirst,pLast)
}

/// Statistics of a column: s("avg"),s("min"),s("max"),s("p95"),s("cnt"),s("maxTS"),s("sum")
ClassMethod Stat(pRun As %Integer, pTable As %String, pCol As %String, pWhere As %String = "", Output s)
{
	kill s set s("cnt")=0,(s("avg"),s("min"),s("max"),s("p95"),s("maxTS"),s("sum"))=""
	set tTS=$s(pTable="Finding":"",1:",SampleTS")
	set tSQL="SELECT "_pCol_" V"_tTS_" FROM SysPerf_Data."_pTable_" WHERE Run=? AND "_pCol_" IS NOT NULL"_$s(pWhere'="":" AND "_pWhere,1:"")_" ORDER BY "_pCol
	set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,pRun)
	quit:tRS.%SQLCODE<0
	set n=0,tSum=0
	while tRS.%Next() { set n=n+1,v(n)=tRS.V,tSum=tSum+tRS.V set:tTS'="" t(n)=tRS.SampleTS }
	quit:'n
	set s("cnt")=n,s("sum")=tSum,s("avg")=$fn(tSum/n,"",3),s("min")=v(1),s("max")=v(n),s("maxTS")=$g(t(n))
	set tIdx=n*0.95\1 set:tIdx<1 tIdx=1 set:(n*0.95)>tIdx tIdx=tIdx+1 set:tIdx>n tIdx=n
	set s("p95")=v(tIdx)
}

/// Periods where a column stayed above pThr (gaps up to 2 samples tolerated).
/// Returns text "13:02-14:58 (116 min, peak 99 at 13:44); ..." (longest first, max 5) and total minutes above.
ClassMethod Episodes(pRun As %Integer, pTable As %String, pCol As %String, pWhere As %String, pThr As %Double, Output pMinutes As %Double) As %String
{
	set pMinutes=0,tOut=""
	quit:pThr="" ""
	set tSQL="SELECT SampleTS T,"_pCol_" V FROM SysPerf_Data."_pTable_" WHERE Run=? AND "_pCol_" IS NOT NULL"_$s(pWhere'="":" AND "_pWhere,1:"")_" ORDER BY SampleTS"
	set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,pRun)
	quit:tRS.%SQLCODE<0 ""
	set (tStart,tLast,tPeak,tPeakTS,tPrev)="",tMiss=0,n=0,tStep=""
	while tRS.%Next() {
		if tPrev'="",tStep="" set tStep=##class(SysPerf.Util).DiffSec(tPrev,tRS.T)
		set tPrev=tRS.T
		if tRS.V>pThr {
			if tStart="" set tStart=tRS.T,tPeak=tRS.V,tPeakTS=tRS.T
			if tRS.V>tPeak set tPeak=tRS.V,tPeakTS=tRS.T
			set tLast=tRS.T,tMiss=0
		} elseif tStart'="" {
			set tMiss=tMiss+1
			if tMiss>2 { set n=n+1,e(n)=$lb(tStart,tLast,tPeak,tPeakTS),tStart="",tMiss=0 }
		}
	}
	if tStart'="" set n=n+1,e(n)=$lb(tStart,tLast,tPeak,tPeakTS)
	quit:'n ""
	for i=1:1:n { set tSec=##class(SysPerf.Util).DiffSec($li(e(i),1),$li(e(i),2))+tStep set pMinutes=pMinutes+(tSec/60),o(-tSec,i)="" }
	set k="",c=0
	for { set k=$o(o(k)) quit:k=""  set i="" for { set i=$o(o(k,i)) quit:i=""  set c=c+1 quit:c>5
		set x=e(i),tOut=tOut_$s(tOut="":"",1:"; ")_$e($li(x,1),6,16)_"-"_$e($li(x,2),12,16)_" ("_$fn(-k/60,"",0)_" min, peak "_..Fmt($li(x,3))_" at "_$e($li(x,4),12,16)_")" } quit:c>5 }
	set pMinutes=$fn(pMinutes,"",0)
	quit tOut_$s(n>5:"; +"_(n-5)_" more",1:"")
}

/// Preferred OSStat source for a column
ClassMethod Src(pRun As %Integer, pCol As %String, pList As %String) As %String [ CodeMode = expression ]
{
##class(SysPerf.Rollup).PickSource(pRun,"OSStat",pCol,pList)
}

ClassMethod CPF(pRun As %Integer, pSection As %String, pName As %String) As %String
{
	&sql(SELECT TOP 1 Value INTO :tV FROM SysPerf_Data.ConfigParam WHERE Run=:pRun AND SectionName=:pSection AND Name=:pName)
	quit $s(SQLCODE=0:tV,1:"")
}

ClassMethod CPFExists(pRun As %Integer, pSection As %String) As %Boolean
{
	&sql(SELECT TOP 1 ID INTO :tV FROM SysPerf_Data.ConfigParam WHERE Run=:pRun AND SectionName=:pSection)
	quit SQLCODE=0
}

/// First value of a KeyValue (lowest sample)
ClassMethod KV(pRun As %Integer, pSection As %String, pName As %String) As %String
{
	&sql(SELECT TOP 1 Value INTO :tV FROM SysPerf_Data.KeyValue WHERE Run=:pRun AND SectionName=:pSection AND Name=:pName ORDER BY SampleNo)
	quit $s(SQLCODE=0:tV,1:"")
}

ClassMethod KVMax(pRun As %Integer, pSection As %String, pName As %String) As %String
{
	&sql(SELECT MAX(NumValue) INTO :tV FROM SysPerf_Data.KeyValue WHERE Run=:pRun AND SectionName=:pSection AND Name=:pName)
	quit $s(SQLCODE=0:tV,1:"")
}

ClassMethod Fmt(v, d As %Integer = 1) As %String [ CodeMode = expression ]
{
$s(v="":"n/a",1:$fn(v,",",d))
}

// ================================================================ rules

ClassMethod RuleCollection(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	if tRun.CollectionErrors'="" {
		set tRec="The OS counters for this run are incomplete, so CPU / memory / disk bottlenecks cannot be confirmed from OS data."_$c(10)
		set tRec=tRec_"- Windows: perfmon is started with 'logman'. Run ^SystemPerformance as a user with local administrator rights, or add the IRIS service account to the local 'Performance Log Users' group and restart the IRIS service."_$c(10)
		set tRec=tRec_"- Unix: install the sysstat package (sar/iostat) and make sure the instance owner can run vmstat, iostat and sar."_$c(10)
		set tRec=tRec_"- Re-run the profile and reload the report."
		do ..Add(.ctx,"W","Collection","COLLECT_ERR","A data collector failed during the run","Collector errors: "_tRun.CollectionErrors,tRec,tRun.CollectionErrors,"","","config")
	}
	&sql(SELECT COUNT(*) INTO :tOS FROM SysPerf_Data.OSStat WHERE Run=:r)
	if 'tOS,tRun.CollectionErrors="" {
		do ..Add(.ctx,"W","Collection","COLLECT_ERR","No operating system time-series in this report","The report contains no perfmon / vmstat / iostat / sar samples.","Only IRIS-side metrics (mgstat, irisstat) can be analysed. Fix the OS collector (see above) to get CPU, memory and disk latency analysis.","","","","os")
	}
	set tDur=##class(SysPerf.Util).DiffSec(tRun.StartTS,tRun.EndTS)
	set tMin=##class(SysPerf.Config.Settings).Get().MinRunMinutes
	if tDur'="",tDur<(tMin*60) {
		do ..Add(.ctx,"I","Collection","RUN_SHORT","Run covers only "_##class(SysPerf.Util).Dur(tDur)_" ("_tRun.SampleCount_" samples every "_tRun.IntervalSec_" s)",
			"Short runs show a snapshot, not the daily peak. Trends, P95 values and capacity findings from this run are indicative only.",
			"Collect a full business day: use the built-in '24hours' profile (2-second interval) - do run^SystemPerformance(""24hours"") - or enable automatic daily reports (CPF [Startup] SystemPerformanceDailyReportsOn=1) and let the SysPerf task load them.","Profile: "_tRun.ProfileName,tDur,"min "_tMin_" min","mgstat")
	}
}

ClassMethod RuleCPU(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	set tSrc=..Src(r,"CPUBusyPct","perfmon,sar-u,vmstat,iostat")
	quit:tSrc=""
	set tW="Source='"_tSrc_"'"
	do ..Stat(r,"OSStat","CPUBusyPct",tW,.s)
	set tEv="Source "_tSrc_", "_s("cnt")_" samples. avg "_..Fmt(s("avg"))_"%, p95 "_..Fmt(s("p95"))_"%, max "_..Fmt(s("max"))_"% at "_s("maxTS")_". CPUs: "_tRun.NumCPU
	do ##class(SysPerf.Config.Threshold).Limits("CPU_BUSY_P95",.tWarnP,.tCritP)
	set tEp=..Episodes(r,"OSStat","CPUBusyPct",tW,tWarnP,.tEpMin)
	if tEp'="" set tEv=tEv_$c(10)_"Above "_tWarnP_"% for "_tEpMin_" min in total: "_tEp
	set tRec="Identify the processes consuming CPU (IRIS Jobs / %SS tabs: highest CPU and global reference deltas), look for inefficient SQL (SQL Statement Index / Query plans), runaway loops or excessive business-host pool sizes. If load is legitimate, add vCPUs - keep CPU below ~70% average / 85% peak to leave headroom for failover and bursts."
	do ..Eval(.ctx,"CPU_BUSY_AVG",s("avg"),"CPU","Average CPU busy {v}%","Overall processor utilisation during the run.",tRec,tEv,"os",s("maxTS"))
	do ..Eval(.ctx,"CPU_BUSY_P95",s("p95"),"CPU","95th percentile CPU busy {v}%","5% of the samples were above this value.",tRec,tEv,"os",s("maxTS"))
	set tSrc2=..Src(r,"CPUMaxCorePct","perfmon,sar-u")
	if tSrc2'="" {
		do ..Stat(r,"OSStat","CPUMaxCorePct","Source='"_tSrc2_"'",.s2)
		do ..Eval(.ctx,"CPU_CORE_MAX",s2("avg"),"CPU","Busiest core averages {v}%","Average of the highest single-core utilisation in each sample. A saturated single core with low overall CPU points to a single-threaded bottleneck (one busy process, write daemon, journal daemon, or a single business host).","Check the IRIS Jobs tab for the process with the highest CPU delta; spread work across more pool jobs / work queues, or review the process's code path.","avg "_..Fmt(s2("avg"))_"%, max "_..Fmt(s2("max"))_"% at "_s2("maxTS"),"os",s2("maxTS"))
	}
	set tSrc3=..Src(r,"CPUIOWaitPct","sar-u,vmstat,iostat")
	if tSrc3'="" {
		do ..Stat(r,"OSStat","CPUIOWaitPct","Source='"_tSrc3_"'",.s3)
		do ..Eval(.ctx,"CPU_IOWAIT",s3("avg"),"CPU","Average CPU I/O wait {v}%","Time CPUs were idle waiting for disk I/O.","High iowait means storage cannot keep up. Check the Disk tab for the device with the worst latency; separate database, journal and WIJ onto different volumes; review storage tier / queue depth; consider larger global buffers to reduce physical reads.","avg "_..Fmt(s3("avg"))_"%, p95 "_..Fmt(s3("p95"))_"%, max "_..Fmt(s3("max"))_"% at "_s3("maxTS"),"os",s3("maxTS"))
	}
	set tSrc4=..Src(r,"CPUStealPct","sar-u,vmstat,iostat")
	if tSrc4'="" {
		do ..Stat(r,"OSStat","CPUStealPct","Source='"_tSrc4_"'",.s4)
		do ..Eval(.ctx,"CPU_STEAL",s4("avg"),"CPU","Average CPU steal {v}%","CPU time taken by the hypervisor for other VMs.","The host is over-committed. Ask the virtualisation team for a CPU reservation / fewer vCPUs on the host, or move the VM; for VMware check CPU Ready (> 5% per vCPU is a problem).","avg "_..Fmt(s4("avg"))_"%, max "_..Fmt(s4("max"))_"%","os",s4("maxTS"))
	}
	set tSrc5=..Src(r,"RunQueue","perfmon,vmstat")
	if tSrc5'="",tRun.NumCPU>0 {
		do ..Stat(r,"OSStat","RunQueue","Source='"_tSrc5_"'",.s5)
		set tPer=$fn(s5("avg")/tRun.NumCPU,"",2)
		do ..Eval(.ctx,"CPU_RUNQ",tPer,"CPU","Run queue {v} per core","Processes waiting for a CPU, divided by "_tRun.NumCPU_" CPUs.","A sustained run queue above 1-2 per core means CPU saturation even if % busy looks acceptable. Add CPUs or reduce concurrent work.","avg queue "_..Fmt(s5("avg"))_", max "_..Fmt(s5("max"))_" at "_s5("maxTS"),"os",s5("maxTS"))
	}
}

ClassMethod RuleMemory(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj"),tTot=tRun.TotalMemoryMB
	set tSrc=..Src(r,"MemAvailMB","perfmon,free")
	if tSrc'="",tTot>0 {
		do ..Stat(r,"OSStat","MemAvailMB","Source='"_tSrc_"'",.s)
		set tPct=$fn(s("min")*100/tTot,"",1)
		do ..Eval(.ctx,"MEM_AVAIL_PCT",tPct,"Memory","Lowest available memory {v}% of RAM","Minimum available memory "_..Fmt(s("min"),0)_" MB of "_..Fmt(tTot,0)_" MB.","Low available memory leads to paging of IRIS process memory. Check which processes grow (Processes / OS processes tabs), reduce per-process memory (bbsiz), reduce global buffers if they exceed ~70-75% of RAM, or add RAM.","avg "_..Fmt(s("avg"),0)_" MB, min "_..Fmt(s("min"),0)_" MB","os")
	} elseif tTot>0,tRun.AvailableMemoryMB'="" {
		set tPct=$fn(tRun.AvailableMemoryMB*100/tTot,"",1)
		do ..Eval(.ctx,"MEM_AVAIL_PCT",tPct,"Memory","Available memory {v}% of RAM at collection time","From Windows systeminfo: "_..Fmt(tRun.AvailableMemoryMB,0)_" MB available of "_..Fmt(tTot,0)_" MB (single snapshot, no time series).","Keep at least 10-15% of RAM available for the OS and process growth.","","config")
	}
	if ..Src(r,"MemCommitPct","perfmon")'="" {
		do ..Stat(r,"OSStat","MemCommitPct","Source='perfmon'",.s)
		do ..Eval(.ctx,"MEM_COMMIT_PCT",s("max"),"Memory","Committed memory peaked at {v}%","% Committed Bytes In Use (commit charge vs commit limit).","When commit charge reaches the limit, processes cannot allocate memory (IRIS <STORE>/<SYSTEM> errors). Enlarge the page file or add RAM; check for leaking processes.","max at "_s("maxTS"),"os",s("maxTS"))
	}
	set tSrc=..Src(r,"PageInPerSec","perfmon,vmstat")
	if tSrc'="" {
		do ..Stat(r,"OSStat","PageInPerSec","Source='"_tSrc_"'",.s)
		do ..Eval(.ctx,"MEM_PAGING",s("avg"),"Memory","Hard page reads average {v}/s","Pages read from disk to resolve page faults.","Sustained paging severely hurts IRIS (shared memory must stay resident). Enable large pages / 'Lock pages in memory' for the IRIS service account, reduce memory pressure or add RAM.","avg "_..Fmt(s("avg"))_"/s, max "_..Fmt(s("max"))_"/s at "_s("maxTS"),"os",s("maxTS"))
	}
	if ..Src(r,"SwapInPerSec","vmstat")'="" {
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT AVG(SwapInPerSec+SwapOutPerSec) A, MAX(SwapInPerSec+SwapOutPerSec) M FROM SysPerf_Data.OSStat WHERE Run=? AND Source='vmstat'",r)
		if tRS.%Next() {
			do ..Eval(.ctx,"MEM_SWAP",tRS.A,"Memory","Swap activity averages {v} KB/s","vmstat si+so.","Any sustained swapping on a database server is a problem. Configure huge pages for IRIS shared memory, lower vm.swappiness (ISC recommends <= 10), and add RAM or reduce global buffers.","max "_..Fmt(tRS.M)_" KB/s","os")
		}
	}
	if ..Src(r,"PagingFilePct","perfmon")'="" {
		do ..Stat(r,"OSStat","PagingFilePct","Source='perfmon'",.s)
		do ..Eval(.ctx,"PAGEFILE_PCT",s("max"),"Memory","Paging file usage peaked at {v}%","Paging File(_Total)\% Usage.","High page file usage shows memory was paged out. Investigate memory pressure (see Available memory).","","os",s("maxTS"))
	}
	// systeminfo virtual memory
	set tMax=##class(SysPerf.Util).Num(..KV(r,"Windows info","Virtual Memory: Max Size")),tUse=##class(SysPerf.Util).Num(..KV(r,"Windows info","Virtual Memory: In Use"))
	if tMax>0,tUse'="" {
		set tPct=$fn(tUse*100/tMax,"",1)
		set tSev=$s(tPct>90:"C",tPct>80:"W",1:"OK")
		do ..Add(.ctx,tSev,"Memory","MEM_COMMIT_PCT","Virtual memory in use "_tPct_"% ("_..Fmt(tUse,0)_" of "_..Fmt(tMax,0)_" MB)","Snapshot from systeminfo at collection time.",$s(tSev="OK":"",1:"Commit charge is close to the limit: enlarge the page file or add RAM."),"",tPct,"warn > 80, crit > 90","config")
	}
}

ClassMethod RuleDisk(ByRef ctx)
{
	set r=ctx("run")
	set tSrc=##class(SysPerf.Rollup).PickSource(r,"DiskStat","Device","perfmon,iostat,sar-d")
	quit:tSrc=""
	// per device averages
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT %EXACT(Device) Device,AVG(ReadLatMs) RL,AVG(WriteLatMs) WL,AVG(AwaitMs) AW,AVG(QueueLen) Q,AVG(UtilPct) U,AVG(ReadsPerSec+WritesPerSec) IOPS,AVG(TransfersPerSec) T,MAX(ReadLatMs) MRL,MAX(WriteLatMs) MWL,MAX(AwaitMs) MAW FROM SysPerf_Data.DiskStat WHERE Run=? AND Source=? GROUP BY %EXACT(Device)",r,tSrc)
	set (tWR,tWW,tWQ,tWU)="",(tDR,tDW,tDQ,tDU)="",tEv=""
	while tRS.%Next() {
		set tIOPS=$s(tRS.T'="":tRS.T,1:tRS.IOPS)
		continue:(tIOPS<0.5)&&(tRS.U<1)
		set tRL=$s(tRS.RL'="":tRS.RL,1:tRS.AW),tWLat=$s(tRS.WL'="":tRS.WL,1:tRS.AW)
		set tEv=tEv_tRS.Device_": read "_..Fmt(tRL,2)_" ms, write "_..Fmt(tWLat,2)_" ms, queue "_..Fmt(tRS.Q,2)_$s(tRS.U'="":", util "_..Fmt(tRS.U)_"%",1:"")_", "_..Fmt(tIOPS)_" IOPS"_$c(10)
		if tRL'="",(tWR="")||(tRL>tWR) set tWR=tRL,tDR=tRS.Device
		if tWLat'="",(tWW="")||(tWLat>tWW) set tWW=tWLat,tDW=tRS.Device
		if tRS.Q'="",(tWQ="")||(tRS.Q>tWQ) set tWQ=tRS.Q,tDQ=tRS.Device
		if tRS.U'="",(tWU="")||(tRS.U>tWU) set tWU=tRS.U,tDU=tRS.Device
	}
	set tRec="Database reads should average < 5-10 ms and journal/WIJ writes < 1-2 ms on SSD. Actions: place databases, journals (primary + alternate) and the WIJ on separate volumes/LUNs; use SSD/NVMe tier; check SAN/datastore contention and VM disk controller (PVSCSI on VMware); on Linux use noop/none scheduler and XFS; increase global buffers to cut physical reads."
	do ..Eval(.ctx,"DISK_READ_LAT",tWR,"Disk","Worst average read latency {v} ms ("_tDR_")","Average read service time of the slowest active device.",tRec,tEv,"disk")
	do ..Eval(.ctx,"DISK_WRITE_LAT",tWW,"Disk","Worst average write latency {v} ms ("_tDW_")","Average write service time of the slowest active device. Journal and WIJ writes are synchronous for commits and write-daemon cycles.",tRec,tEv,"disk")
	do ..Eval(.ctx,"DISK_QUEUE",tWQ,"Disk","Worst average disk queue {v} ("_tDQ_")","Outstanding I/O requests.",tRec,tEv,"disk")
	do ..Eval(.ctx,"DISK_UTIL",tWU,"Disk","Busiest device {v}% utilised ("_tDU_")","% of time the device was busy.",tRec,tEv,"disk")
	// p95 of worst latency
	set tSrc2=..Src(r,"DiskMaxReadLatMs",tSrc)
	if tSrc2'="" {
		do ..Stat(r,"OSStat","DiskMaxReadLatMs","Source='"_tSrc2_"'",.s1)
		do ..Stat(r,"OSStat","DiskMaxWriteLatMs","Source='"_tSrc2_"'",.s2)
		set tP=$s(s1("p95")>s2("p95"):s1("p95"),1:s2("p95"))
		do ##class(SysPerf.Config.Threshold).Limits("DISK_READ_LAT",.tDW,.tDC)
		set tEpR=..Episodes(r,"OSStat","DiskMaxReadLatMs","Source='"_tSrc2_"'",tDW,.tMinR)
		set tEpW=..Episodes(r,"OSStat","DiskMaxWriteLatMs","Source='"_tSrc2_"'",tDW,.tMinW)
		set tEv2=$s(tEpR'="":$c(10)_"Read latency above "_tDW_" ms for "_tMinR_" min: "_tEpR,1:"")_$s(tEpW'="":$c(10)_"Write latency above "_tDW_" ms for "_tMinW_" min: "_tEpW,1:"")
		do ..Eval(.ctx,"DISK_LAT_P95",tP,"Disk","P95 worst-device latency {v} ms","95th percentile of the highest read/write latency across devices per sample (spikes).",tRec,"read p95 "_..Fmt(s1("p95"),2)_" ms (max "_..Fmt(s1("max"),2)_" at "_s1("maxTS")_"), write p95 "_..Fmt(s2("p95"),2)_" ms (max "_..Fmt(s2("max"),2)_" at "_s2("maxTS")_")"_tEv2,"disk",s1("maxTS"),s2("maxTS"))
	}
}

ClassMethod RuleGlobalBuffers(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	&sql(SELECT SUM(Glorefs),SUM(PhyRds),AVG(Glorefs),AVG(PhyRds),MAX(PhyRds),COUNT(*) INTO :tG,:tP,:tAG,:tAP,:tMP,:tN FROM SysPerf_Data.Mgstat WHERE Run=:r)
	quit:(SQLCODE'=0)||('tN)
	do ..Stat(r,"Mgstat","PhyRds","",.sp)
	set tEv="avg Glorefs "_..Fmt(tAG,0)_"/s, avg PhyRds "_..Fmt(tAP,1)_"/s, max PhyRds "_..Fmt(tMP,0)_"/s at "_sp("maxTS")_", global buffers "_..Fmt(tRun.GlobalBuffersMB,0)_" MB"
	set tRec="Increase global buffers (Memory and Startup page / CPF [config] globals) so the working set stays in memory, keeping total IRIS shared memory well below physical RAM. Also look for queries doing full scans (SQL Statement Index) and large $ORDER loops over cold data."
	if tAG<500 {
		set tHit=$s(tG>0:$fn(100*(1-(tP/tG)),"",2),1:"")
		do ..Add(.ctx,"OK","Global Buffers","GB_CACHE_HIT","Global load is light (avg "_..Fmt(tAG,0)_" glorefs/s) - cache hit "_$s(tHit="":"n/a",1:tHit_"%"),"With this little activity the cache ratio is not meaningful.","",tEv,tHit,"","mgstat")
	} else {
		set tHit=$fn(100*(1-(tP/tG)),"",3)
		do ..Eval(.ctx,"GB_CACHE_HIT",tHit,"Global Buffers","Global buffer cache hit {v}%","Share of global references served from memory.",tRec,tEv,"mgstat")
	}
	do ..Eval(.ctx,"GB_PHYRDS",tAP,"Global Buffers","Physical reads average {v}/s","Database blocks read from disk per second.",tRec,tEv,"mgstat",sp("maxTS"))
	// sizing vs RAM
	if tRun.GlobalBuffersMB>0,tRun.TotalMemoryMB>0 {
		set tPct=$fn(tRun.GlobalBuffersMB*100/tRun.TotalMemoryMB,"",1)
		set tSevL=##class(SysPerf.Config.Threshold).Classify("GB_LARGE_PCT",tPct,.tThrL)
		if tSevL'="" {
			do ..Add(.ctx,tSevL,"Global Buffers","GB_LARGE_PCT","Global buffers are "_tPct_"% of RAM","Global buffers "_..Fmt(tRun.GlobalBuffersMB,0)_" MB of "_..Fmt(tRun.TotalMemoryMB,0)_" MB physical memory.","Leave room for the OS, routine buffers, gmheap and every IRIS process (bbsiz per process x number of processes). Reduce global buffers or add RAM to avoid paging.",tEv,tPct,tThrL,"config")
		} else {
			set tSevS=##class(SysPerf.Config.Threshold).Classify("GB_SMALL_PCT",tPct,.tThrS)
			// small buffers only matter when there are physical reads
			if tSevS'="",tAP>100 {
				do ..Add(.ctx,tSevS,"Global Buffers","GB_SMALL_PCT","Global buffers are only "_tPct_"% of RAM while physical reads average "_..Fmt(tAP,0)_"/s","Global buffers "_..Fmt(tRun.GlobalBuffersMB,0)_" MB of "_..Fmt(tRun.TotalMemoryMB,0)_" MB.",tRec,tEv,tPct,tThrS,"config")
			} else {
				do ..Add(.ctx,"OK","Global Buffers","GB_SIZE","Global buffers "_..Fmt(tRun.GlobalBuffersMB,0)_" MB = "_tPct_"% of RAM","Sizing is within the expected range for the observed load.","",tEv,tPct,"","config")
			}
		}
	}
	// globals=0 (automatic)
	set tGlob=..CPF(r,"config","globals")
	if tGlob'="",$tr(tGlob,"0,")="" {
		do ..Add(.ctx,"W","Configuration","CFG_GLOBALS_AUTO","Global buffers are set to automatic (globals="_tGlob_")","IRIS sized the database cache itself at startup ("_..Fmt(tRun.GlobalBuffersMB,0)_" MB). Automatic sizing is intended for development; it can change after RAM changes and is not tuned for the workload.","Set global buffers explicitly for the 8 KB block size (Management Portal > System Administration > Configuration > System Configuration > Memory and Startup, or CPF [config] globals=0,0,<MB>,0,0,0). On a dedicated database server a common starting point is 50-70% of RAM, sized from the database working set, leaving memory for the OS, gmheap, routine buffers and processes.","CPF globals="_tGlob,"","","config")
	}
}

ClassMethod RuleRoutines(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	do ..Stat(r,"Mgstat","RouLaS","",.s)
	do ..Eval(.ctx,"RTN_LOADS",s("avg"),"Routine Buffers","Routine loads/saves average {v}/s","Routines/classes loaded into the routine cache per second (cache misses).","Increase routine buffers (CPF [config] routines) so application code stays cached; HealthShare / IRIS for Health loads many classes - 1 GB+ of routine buffers is common for large productions.","avg "_..Fmt(s("avg"))_"/s, max "_..Fmt(s("max"))_"/s at "_s("maxTS")_"; routine buffers "_..Fmt(tRun.RoutineBuffersMB,0)_" MB","mgstat",s("maxTS"))
	set tRtn=..CPF(r,"config","routines")
	if tRtn'="",+tRtn=0,$tr(tRtn,"0,")="" {
		do ..Add(.ctx,"I","Configuration","CFG_ROUTINES_AUTO","Routine buffers are automatic (routines="_tRtn_")","Current routine cache "_..Fmt(tRun.RoutineBuffersMB,0)_" MB.","Set routine buffers explicitly for production (CPF [config] routines=<MB>), sized so RouLaS stays near zero at peak.","","","","config")
	}
	set tHeap=..CPF(r,"config","gmheap")
	if tHeap'="" {
		set tMB=tHeap\1024
		if +tHeap=0 {
			do ..Add(.ctx,"W","Configuration","CFG_GMHEAP","Shared memory heap is automatic (gmheap=0)","gmheap holds the lock table, class/routine descriptors, ECP and other shared structures. HealthShare productions with many processes and locks need more than the minimum.","Set gmheap explicitly (CPF [config] gmheap in KB), typically 512 MB - 1 GB for HealthShare / IRIS for Health production servers, then check 'Shared Memory Heap Usage' in the Management Portal.","CPF gmheap="_tHeap,"","","config")
		} elseif tMB<256 {
			do ..Add(.ctx,"I","Configuration","CFG_GMHEAP","gmheap is "_tMB_" MB","Small shared memory heap for an IRIS for Health server.","Consider 512 MB+ for productions with many business hosts, locks or ECP.","","","","config")
		} else {
			do ..Add(.ctx,"OK","Configuration","CFG_GMHEAP","gmheap is "_tMB_" MB","","","","","","config")
		}
	}
	set tLock=..CPF(r,"config","locksiz")
	if tLock'="",+tLock=0 do ..Add(.ctx,"I","Configuration","CFG_LOCKSIZ","Lock table size is automatic (locksiz=0)","The lock table grows from gmheap.","If you see <LOCKTABLEFULL> in messages.log, raise gmheap / set locksiz explicitly.","","","","config")
}

ClassMethod RuleWriteDaemon(ByRef ctx)
{
	set r=ctx("run")
	&sql(SELECT COUNT(*),SUM(CASE WHEN WDphase>0 THEN 1 ELSE 0 END),MAX(WDQsz),AVG(PhyWrs),MAX(PhyWrs),AVG(WIJwri) INTO :tN,:tAct,:tMaxQ,:tAW,:tMW,:tWIJ FROM SysPerf_Data.Mgstat WHERE Run=:r)
	quit:(SQLCODE'=0)||('tN)
	set tPct=$fn(tAct*100/tN,"",1)
	set tRec="The write daemon flushes modified buffers every cycle; long active phases mean database/WIJ writes are slow. Put the WIJ on its own fast volume (CPF [config] wijdir), keep databases on low-latency storage, and consider more write daemons (Aux WDs) on very write-heavy systems."
	set tEv="WD active in "_tAct_" of "_tN_" samples; max WDQsz "_..Fmt(tMaxQ,0)_"; PhyWrs avg "_..Fmt(tAW)_" max "_..Fmt(tMW)_"/s; WIJ writes avg "_..Fmt(tWIJ)_"/s"
	do ..Eval(.ctx,"WD_ACTIVE_PCT",tPct,"Write Daemon","Write daemon active in {v}% of samples","Share of mgstat samples where WDphase was non-zero.",tRec,tEv,"mgstat")
	do ..Eval(.ctx,"WD_QUEUE",tMaxQ,"Write Daemon","Maximum write daemon queue {v} blocks","WDQsz peak.",tRec,tEv,"mgstat")
	// irisstat -c1 sanity counters
	for tK="WIJExpandFailCnt","IJPANIC","WDSTOP" {
		set tV=..KVMax(r,"irisstat -c1",tK)
		if tV>0 do ..Add(.ctx,"C","Write Daemon","IRIS_ERRORS",tK_" = "_tV,"irisstat reports a non-zero "_tK_" counter.","Check messages.log immediately; contact InterSystems WRC if the cause is not understood.","","","","iris")
	}
}

ClassMethod RuleJournal(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	do ..Stat(r,"Mgstat","Jrnwrts","",.s)
	do ..Eval(.ctx,"JRN_WRITES",s("avg"),"Journal","Journal writes average {v}/s","Journal buffer writes per second.","High journal rates need a dedicated low-latency journal volume. Check for mass updates/kills that could use journal-less temporary globals (IRISTEMP / ^||PPG) and for purging jobs running at peak time.","avg "_..Fmt(s("avg"))_", max "_..Fmt(s("max"))_" at "_s("maxTS"),"mgstat",s("maxTS"))
	quit:'..CPFExists(r,"Journal")
	set tCur=..CPF(r,"Journal","CurrentDirectory"),tAlt=..CPF(r,"Journal","AlternateDirectory")
	set tWij=..CPF(r,"config","wijdir")
	set tMgr=$s(tRun.InstanceDirectory'="":##class(SysPerf.Util).NormDir(tRun.InstanceDirectory)_"mgr/",1:"")
	if tWij="",tMgr'="" set tWij=tMgr
	// application database volumes
	kill tVol
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Name,Value FROM SysPerf_Data.ConfigParam WHERE Run=? AND SectionName='Databases'",r)
	while tRS.%Next() { set tV=##class(SysPerf.Util).Volume($p(tRS.Value,",",1)) set:tV'="" tVol(tV)=$g(tVol(tV))_$s($d(tVol(tV)):",",1:"")_tRS.Name }
	set tJV=##class(SysPerf.Util).Volume(tCur),tAV=##class(SysPerf.Util).Volume(tAlt),tWV=##class(SysPerf.Util).Volume(tWij)
	set tEv="Journal: "_tCur_$c(10)_"Alternate: "_tAlt_$c(10)_"WIJ: "_$s(..CPF(r,"config","wijdir")="":"(default) "_tWij,1:tWij)_$c(10)_"Database volumes: " set v="" for { set v=$o(tVol(v)) quit:v=""  set tEv=tEv_v_" ("_$l(tVol(v),",")_" DBs) " }
	if tJV'="",$d(tVol(tJV)) {
		do ..Add(.ctx,"W","Journal","CFG_JRN_SAME_VOL","Journal files are on the same volume as databases ("_tJV_")","Database, journal"_$s(tWV=tJV:" and WIJ",1:"")_" I/O compete on one volume. A storage failure also takes out both the databases and the journals needed to recover them.","InterSystems recommends separate volumes (ideally separate physical storage) for: databases, primary journal, alternate journal, and the WIJ. Move the journal directory in Management Portal > System Administration > Configuration > System Configuration > Journal Settings.",tEv,"","","config")
	} else {
		do ..Add(.ctx,"OK","Journal","CFG_JRN_SAME_VOL","Journals are on a separate volume from databases","","",tEv,"","","config")
	}
	if tWV'="",$d(tVol(tWV)),tWV'=tJV {
		do ..Add(.ctx,"W","Journal","CFG_WIJ_DEFAULT","WIJ is on the same volume as databases ("_tWV_")","The write image journal is written every write-daemon cycle.","Configure wijdir (CPF [config]) on its own fast volume.",tEv,"","","config")
	} elseif ..CPF(r,"config","wijdir")="" {
		do ..Add(.ctx,"I","Journal","CFG_WIJ_DEFAULT","WIJ is in the default location (install mgr directory)","","For production put the WIJ on a dedicated volume (CPF [config] wijdir).",tEv,"","","config")
	}
	if tAlt'="",##class(SysPerf.Util).NormDir(tAlt)=##class(SysPerf.Util).NormDir(tCur) {
		do ..Add(.ctx,"W","Journal","CFG_JRN_ALT_SAME","Alternate journal directory is the same as the primary","If the journal volume fills or fails, IRIS has nowhere to switch and journaling stops (or the system freezes when FreezeOnError=1).","Set AlternateDirectory to a different volume.",tEv,"","","config")
	}
	set tFreeze=..CPF(r,"Journal","FreezeOnError")
	if tFreeze="0" do ..Add(.ctx,"I","Journal","CFG_FREEZE_ON_ERR","Journal FreezeOnError is disabled","On a journal I/O error IRIS disables journaling and continues, which can leave databases unrecoverable to a point in time.","For systems where data integrity matters more than availability (and on mirror members) set FreezeOnError=1 together with a reliable alternate journal directory.","FreezeOnError=0","","","config")
	set tDays=..CPF(r,"Journal","DaysBeforePurge"),tBk=..CPF(r,"Journal","BackupsBeforePurge")
	if tDays'="" do ..Add(.ctx,"I","Journal","CFG_JRN_PURGE","Journals purged after "_tDays_" days / "_tBk_" backups","Journal retention determines how far back you can roll forward after restoring a backup.","Make sure retention covers at least two full backup cycles and your recovery point objective. Compressed journals (CompressFiles="_..CPF(r,"Journal","CompressFiles")_") reduce space.","","","","config")
}

ClassMethod RuleDatabase(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	&sql(SELECT MAX(SampleNo),MIN(SampleNo) INTO :tLast,:tFirst FROM SysPerf_Data.DatabaseFile WHERE Run=:r)
	if SQLCODE=0,tLast'="" {
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Directory,DBName,SizeMB,MaxSizeMB,Blocks,MaxBlocks,ReadOnly,Journaled,Flags FROM SysPerf_Data.DatabaseFile WHERE Run=? AND SampleNo=?",r,tLast)
		set tTot=0,tCnt=0,tNoJ="",tEv=""
		while tRS.%Next() {
			set tCnt=tCnt+1,tTot=tTot+tRS.SizeMB
			set tName=$s(tRS.DBName'="":tRS.DBName,1:tRS.Directory)
			set tEv=tEv_tName_": "_..Fmt(tRS.SizeMB,0)_" MB"_$s(tRS.ReadOnly:" (read-only)",1:"")_$s('tRS.Journaled:" (not journaled)",1:"")_$c(10)
			if tRS.MaxBlocks>0 {
				set tPct=$fn(tRS.Blocks*100/tRS.MaxBlocks,"",1)
				set tSev=##class(SysPerf.Config.Threshold).Classify("DB_NEAR_MAX",tPct,.tThr)
				if tSev'="" do ..Add(.ctx,tSev,"Database","DB_NEAR_MAX","Database "_tName_" is at "_tPct_"% of its maximum size","Size "_..Fmt(tRS.SizeMB,0)_" MB, maximum "_..Fmt(tRS.MaxSizeMB,0)_" MB.","When the maximum is reached updates fail with <FILEFULL>. Raise the maximum size or clean up / archive data.","",tPct,tThr,"db")
			}
			set tU=$zcvt(tName,"U")
			if tU["IRISTEMP" {
				do ..Eval(.ctx,"IRISTEMP_MB",tRS.SizeMB,"Database","IRISTEMP is {v} MB","IRISTEMP grows with temporary globals (SQL sorts, ^||PPG, process-private data).","Find the processes/queries creating large temporary data; IRISTEMP is reset at restart. Put IRISTEMP on fast storage separate from application databases.","","db")
			}
			if 'tRS.Journaled,'tRS.ReadOnly,'$lf($lb("IRISTEMP","IRISLOCALDATA","HSSYSLOCALTEMP","CACHETEMP","IRISMETRICS","ENSLIB","IRISLIB","HSLIB"),tU),tU'["TEMP",tU'["LOCALDATA" {
				set tNoJ=tNoJ_$s(tNoJ="":"",1:", ")_tName
			}
		}
		do ..Add(.ctx,"I","Database","DB_INVENTORY",tCnt_" databases mounted, "_..Fmt(tTot/1024,1)_" GB in total","Sizes from irisstat GFILETAB (last sample).","",tEv,tTot,"","db")
		if tNoJ'="" do ..Add(.ctx,"W","Database","CFG_DB_NOJRN","Application database(s) not journaled: "_tNoJ,"Updates to these databases are not in the journal: they are lost on crash recovery / restore and are not replicated by mirroring.","Enable journaling for application databases (Management Portal > System Administration > Configuration > System Configuration > Local Databases > Global Journal State = Yes) unless the data is truly disposable.","","","","db")
		// growth during the run
		if tLast>tFirst {
			set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT a.DBName,a.Directory,b.SizeMB-a.SizeMB G FROM SysPerf_Data.DatabaseFile a JOIN SysPerf_Data.DatabaseFile b ON b.Run=a.Run AND b.SFN=a.SFN AND b.SampleNo=? WHERE a.Run=? AND a.SampleNo=? AND b.SizeMB>a.SizeMB",tLast,r,tFirst)
			set tG="" while tRS.%Next() { set tG=tG_$s(tRS.DBName'="":tRS.DBName,1:tRS.Directory)_" +"_..Fmt(tRS.G,1)_" MB"_$c(10) }
			if tG'="" do ..Add(.ctx,"I","Database","DB_GROWTH","Databases grew during the run","Growth between first and last irisstat sample.","Plan capacity from the Database growth chart across runs; pre-expand busy databases to avoid expansion during peak.",tG,"","","db")
		}
	}
	do ..Stat(r,"Mgstat","Addblk","",.s)
	do ..Eval(.ctx,"DB_EXPAND",s("avg"),"Database","Databases expanding {v} blocks/s","Blocks added to databases per second (online expansion).","Frequent expansion during business hours adds latency; pre-expand databases or set a larger expansion size.","max "_..Fmt(s("max"))_" at "_s("maxTS"),"mgstat",s("maxTS"))
	// install on system drive (Windows)
	if tRun.Platform="W",tRun.InstanceDirectory'="" {
		set tVol=##class(SysPerf.Util).Volume(tRun.InstanceDirectory),tOnC=""
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Name,Value FROM SysPerf_Data.ConfigParam WHERE Run=? AND SectionName='Databases'",r)
		while tRS.%Next() { if ##class(SysPerf.Util).Volume($p(tRS.Value,",",1))="c:" set tOnC=tOnC_$s(tOnC="":"",1:", ")_tRS.Name }
		if tOnC'="" do ..Add(.ctx,"W","Configuration","CFG_SYS_DRIVE","Databases are on the Windows system drive C: ("_$l(tOnC,",")_" databases)","Databases on C: compete with the OS, page file and logs; if C: fills up Windows and IRIS both stop.","Move application databases, journals and the WIJ to dedicated data volumes (e.g. D:, E:, F:); keep only the IRIS binaries on C:.",tOnC,"","","config")
	}
}

ClassMethod RuleContention(ByRef ctx)
{
	set r=ctx("run")
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT %EXACT(ResName) ResName,MAX(NSeizePct) N,MAX(ASeizePct) A,MAX(BSeizePct) B,MAX(Seize) S,MAX(BlockCollisions) BC FROM SysPerf_Data.ResourceStat WHERE Run=? AND Source='D' GROUP BY %EXACT(ResName)",r)
	set tWorst="",tWName="",tEv="",tColl=0,tAny=0
	while tRS.%Next() {
		set tAny=1
		set m=tRS.N set:tRS.A>m m=tRS.A set:tRS.B>m m=tRS.B
		if m>0 set tEv=tEv_tRS.ResName_": Nseize "_tRS.N_"%, Aseize "_tRS.A_"%, Bseize "_tRS.B_"% (seizes "_tRS.S_")"_$c(10)
		if (tWorst="")||(m>tWorst) set tWorst=m,tWName=tRS.ResName
		if tRS.BC>tColl set tColl=tRS.BC
	}
	if tAny {
		do ..Eval(.ctx,"RES_CONTENTION",tWorst,"Contention","Worst resource contention {v}% ("_tWName_")","Maximum of Nseize/Aseize/Bseize % per resource across irisstat -D samples. Non-zero values mean processes waited for a system latch.","Global/GlobalBuffer/LRU contention: hot blocks (e.g. an incrementing counter global, index on a sequential value) - use $SEQUENCE / $INCREMENT with distributed keys. Routine/ObjClass: routine buffer too small. Lock/LockHTAB: heavy LOCK usage. Journal: slow journal disk.",$s(tEv="":"no contention recorded",1:tEv),"resource")
		do ..Eval(.ctx,"BLOCK_COLL",tColl,"Contention","{v} block collisions per irisstat -D sample","Processes trying to access the same database block concurrently.","Identify the hot global from the irisstat -D detail (raw section) and redesign access (split counters, $SEQUENCE, avoid single-node queues).","","resource")
	}
}

ClassMethod RuleProcesses(ByRef ctx)
{
	set r=ctx("run")
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 5 PID,Namespace,Routine,UserLocation,GlobDelta,GlobPerSec,GlobSharePct,CPUDelta FROM SysPerf_Data.ProcessDelta WHERE Run=? ORDER BY GlobDelta DESC",r)
	set tEv="",tTop="",tTopName=""
	while tRS.%Next() {
		if tTop="" set tTop=tRS.GlobSharePct,tTopName=tRS.PID_" "_tRS.Routine_" ("_tRS.Namespace_")"
		set tEv=tEv_"PID "_tRS.PID_" "_tRS.Routine_" ["_tRS.Namespace_"] "_tRS.UserLocation_": "_..Fmt(tRS.GlobDelta,0)_" glorefs ("_..Fmt(tRS.GlobPerSec)_"/s, "_..Fmt(tRS.GlobSharePct)_"%), "_..Fmt(tRS.CPUDelta,0)_" lines"_$c(10)
	}
	&sql(SELECT AVG(Glorefs) INTO :tAvgG FROM SysPerf_Data.Mgstat WHERE Run=:r)
	if tTop'="",tAvgG<500 {
		do ..Add(.ctx,"I","Process","PROC_GLOB_SHARE","Busiest process: "_tTopName_" ("_..Fmt(tTop)_"% of a light load)","Global references per process between the first and last %SS sample. System load is light (avg "_..Fmt(tAvgG,0)_" glorefs/s), so the share is not significant.","",tEv,tTop,"","process")
	} elseif tTop'="" {
		do ..Eval(.ctx,"PROC_GLOB_SHARE",tTop,"Process","Busiest process did {v}% of global references: "_tTopName,"Global references per process between the first and last %SS sample.","Review what this process does at peak time (routine / business host / SQL). A single process dominating the load is often a batch job, purge task or a loop that can be rescheduled, parallelised or optimised.",tEv,"process")
	}
	&sql(SELECT MAX(NumValue) INTO :tU FROM SysPerf_Data.KeyValue WHERE Run=:r AND SectionName='%SS' AND Name='User processes')
	&sql(SELECT MAX(NumValue) INTO :tS FROM SysPerf_Data.KeyValue WHERE Run=:r AND SectionName='%SS' AND Name='System processes')
	if tU'="" do ..Add(.ctx,"I","Process","PROC_COUNT","Up to "_tU_" user and "_tS_" system IRIS processes","From %SS summary lines.","","","","","process")
}

ClassMethod RuleLicense(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	set tAuth=..KV(r,"License","Total Authorized LU"),tCur=..KV(r,"License","Current Users active"),tMaxU=..KV(r,"License","Maximum Users active")
	set tProd=..KV(r,"License","Product"),tNonProd=..KV(r,"License","Non-Production")
	if (tRun.Customer["No local key")||(tProd="Evaluation")||(tNonProd="yes") {
		do ..Add(.ctx,$s(tRun.Customer["No local key":"W",1:"I"),"License","LIC_EVAL","License: "_$s(tProd'="":tProd,1:"unknown")_$s(tNonProd="yes":" / Non-Production",1:"")_$s(tRun.Customer["No local key":" - no local key found",1:""),"Customer: "_tRun.Customer_$c(10)_"Authorized LU: "_tAuth_", current users: "_tCur_", max users: "_tMaxU,"Install the correct iris.key (or confirm the license server is reachable) before go-live. Evaluation / single-user keys limit concurrent connections and features.","","","","license")
	}
	if tAuth>0,tMaxU'="" {
		set tPct=$fn(tMaxU*100/tAuth,"",1)
		do ..Eval(.ctx,"LIC_USAGE",tPct,"License","Peak license use {v}% ("_tMaxU_" of "_tAuth_")","Maximum users active vs authorised license units.","Plan additional license units before reaching the limit; check for leaked CSP sessions / connections.","","license")
	}
}

ClassMethod RuleIRISHealth(ByRef ctx)
{
	set r=ctx("run")
	set tErr=..KVMax(r,"irisstat -c1","Errors total")
	if tErr'="" do ..Eval(.ctx,"IRIS_ERRORS",tErr,"IRIS","{v} errors in the IRIS kernel error log","irisstat ERROR LOG.","Review messages.log and the irisstat ERROR LOG section (raw sections tab) for the error codes and routines.","","iris")
	set tECP=0
	&sql(SELECT MAX(ActECP) INTO :tECP FROM SysPerf_Data.Mgstat WHERE Run=:r)
	if tECP>0 do ..Add(.ctx,"I","ECP","ECP_ACTIVE","ECP is active (max "_tECP_" connections)","Remote global references are served over ECP.","Watch RemGrefs, network latency and ECP buffer statistics; ECP application servers need their own SystemPerformance reports.","","","","mgstat")
	// Daily reports
	set tDaily=..CPF(r,"Startup","SystemPerformanceDailyReportsOn")
	if tDaily="0" do ..Add(.ctx,"I","Configuration","CFG_DAILY_PERF_OFF","Automatic daily ^SystemPerformance reports are off","Without daily reports there is no baseline to compare against when a problem happens.","Enable them (CPF [Startup] SystemPerformanceDailyReportsOn=1, retention SystemPerformanceDailyReportsRetentionDays="_..CPF(r,"Startup","SystemPerformanceDailyReportsRetentionDays")_") or schedule run^SystemPerformance(""24hours"") in Task Manager, and point the SysPerf inbox task at the output folder so every day appears in this dashboard.","","","","config")
	set tLog=..CPF(r,"Startup","MaxConsoleLogSize")
	if tLog'="",tLog<50 do ..Add(.ctx,"I","Configuration","CFG_CONSOLE_LOG","messages.log rolls over at "_tLog_" MB","Small console log size means errors from a few days ago are already rotated away when you investigate.","Set MaxConsoleLogSize to 50-100 MB (CPF [Startup]).","","","","config")
}

ClassMethod RuleConfig(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	if ..CPFExists(r,"MirrorMember") {
		set tJoin=..CPF(r,"MirrorMember","JoinMirror"),tSys=..CPF(r,"MirrorMember","SystemName")
		if 'tJoin,tSys="",'..CPFExists(r,"Mirrors") {
			do ..Add(.ctx,"I","High Availability","CFG_NO_MIRROR","Instance is not a mirror member","There is no automatic failover for this instance; recovery relies on backups + journals or VM-level HA.","For production HealthShare systems configure a synchronous failover mirror (plus arbiter), or document the VM HA / backup-restore RTO/RPO.","JoinMirror="_tJoin,"","","config")
		} else {
			do ..Add(.ctx,"OK","High Availability","CFG_NO_MIRROR","Instance participates in mirroring","","","","","","config")
		}
	}
	if tRun.LargePages'="" {
		if tRun.LargePages {
			do ..Add(.ctx,"OK","Configuration","CFG_LARGE_PAGES","Shared memory uses large pages","irisstat SHMEMPAGESZ > 64 KB.","","","","","iris")
		} else {
			do ..Add(.ctx,"W","Configuration","CFG_LARGE_PAGES","Shared memory is not using large/huge pages","Without large pages the database cache can be paged out and TLB misses add CPU overhead.",$s(tRun.Platform="W":"Grant the IRIS service account the 'Lock pages in memory' user right (secpol.msc > Local Policies > User Rights Assignment) and restart IRIS.",1:"Configure Linux huge pages (vm.nr_hugepages) to cover IRIS shared memory and restart IRIS; disable transparent huge pages."),"","","","iris")
		}
	}
	// uptime
	if tRun.BootTime'="" {
		set tB=##class(SysPerf.Util).TS($p(tRun.BootTime,",",1),$zstrip($p(tRun.BootTime,",",2),"<>W"))
		set tD=$s(tB'="":##class(SysPerf.Util).DiffSec(tB,tRun.EndTS)\86400,1:"")
		if tD'="" do ..Add(.ctx,$s(tD>180:"I",1:"OK"),"OS","OS_UPTIME","Server up "_tD_" days (boot "_tRun.BootTime_")","",$s(tD>180:"Long uptime usually means OS patches are pending; plan a maintenance window.",1:""),"",tD,"","config")
	}
}

ClassMethod RuleUnixOS(ByRef ctx)
{
	set r=ctx("run"),tRun=ctx("obj")
	quit:tRun.Platform'="U"
	set tHP=..KV(r,"sysctl","vm.nr_hugepages")
	if tHP'="" {
		set tShm=..KV(r,"ipcs","Shared memory total MB")
		if +tHP=0 {
			do ..Add(.ctx,"W","OS","OS_HUGEPAGES","Linux huge pages are not configured (vm.nr_hugepages=0)","IRIS shared memory"_$s(tShm'="":" ("_tShm_" MB)",1:"")_" is using 4 KB pages.","Allocate huge pages for the IRIS shared memory segment: vm.nr_hugepages = (shared memory MB / 2) + ~5% in /etc/sysctl.conf, set memlock limits for the instance owner, disable transparent huge pages, restart IRIS and confirm 'Allocated ... MB shared memory using Huge Pages' in messages.log.","vm.nr_hugepages=0","","","config")
		} else {
			do ..Add(.ctx,"OK","OS","OS_HUGEPAGES","Huge pages configured (vm.nr_hugepages="_tHP_")","","","","","","config")
		}
	}
	set tSw=..KV(r,"sysctl","vm.swappiness")
	if tSw'="" do ..Eval(.ctx,"OS_SWAPPINESS",tSw,"OS","vm.swappiness = {v}","How aggressively Linux swaps process memory.","InterSystems recommends a low value (e.g. vm.swappiness=5..10) on database servers.","","config")
	set tDB=..KV(r,"sysctl","vm.dirty_background_ratio"),tDR=..KV(r,"sysctl","vm.dirty_ratio")
	if tDB'="",(tDB>5)||(tDR>10) do ..Add(.ctx,"I","OS","OS_DIRTY","Dirty page ratios are Linux defaults (background "_tDB_"%, dirty "_tDR_"%)","Large dirty ratios let the OS accumulate many dirty pages and then flush them in bursts (I/O stalls for journal/WIJ).","InterSystems guidance: vm.dirty_background_ratio=5 and vm.dirty_ratio=10.","","","","config")
	// file systems
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Name,NumValue FROM SysPerf_Data.KeyValue WHERE Run=? AND SectionName='df' AND GroupName='Use%' ORDER BY NumValue DESC",r)
	set tFirst=1
	while tRS.%Next() {
		set tSev=##class(SysPerf.Config.Threshold).Classify("FS_USED_PCT",tRS.NumValue,.tThr)
		if tSev'="" do ..Add(.ctx,tSev,"Disk","FS_USED_PCT","File system "_tRS.Name_" is "_tRS.NumValue_"% full","From df -m.","Free space or extend the file system; a full journal or database file system stops IRIS.","",tRS.NumValue,tThr,"os")
		if tSev="",tFirst do ..Add(.ctx,"OK","Disk","FS_USED_PCT","Fullest file system "_tRS.Name_" at "_tRS.NumValue_"%","","","",tRS.NumValue,"","os")
		set tFirst=0
	}
}

ClassMethod RuleVirtualization(ByRef ctx)
{
	set tRun=ctx("obj")
	quit:'tRun.IsVirtual
	do ..Add(.ctx,"I","Virtualization","OS_VM","Running on a virtual machine ("_tRun.Hypervisor_")","IRIS on VMs performs well when resources are guaranteed.","- Reserve 100% of VM memory (no ballooning / swapping at host level)."_$c(10)_"- Avoid CPU over-commit; watch CPU Ready (VMware) / steal (KVM)."_$c(10)_"- Use paravirtual disk controllers (PVSCSI) and network (VMXNET3); separate virtual disks/controllers for databases, journals and WIJ."_$c(10)_"- Thick provision eager-zeroed disks for databases and journals."_$c(10)_"- Exclude IRIS database/journal folders from antivirus and from VM snapshots during business hours.","","","","config")
}

}
