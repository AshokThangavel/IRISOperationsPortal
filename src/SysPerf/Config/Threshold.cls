/// Analyzer rule catalogue with editable thresholds. One row per rule code.
/// Direction H = higher value is worse, L = lower value is worse, B = boolean/config check.
Class SysPerf.Config.Threshold Extends %Persistent [ SqlTableName = Threshold ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Threshold";

Property Code As %String(MAXLEN = 50) [ Required ];

Property Category As %String(MAXLEN = 50);

Property Description As %String(MAXLEN = 1000);

Property Unit As %String(MAXLEN = 30);

Property WarnValue As %Double;

Property CritValue As %Double;

Property Direction As %String(VALUELIST = ",H,L,B") [ InitialExpression = "H" ];

Property Enabled As %Boolean [ InitialExpression = 1 ];

Property ModifiedBy As %String(MAXLEN = 200);

Property ModifiedTS As %TimeStamp;

Index CodeIdx On Code [ IdKey, Unique ];

/// Get warn / crit for a code. Returns 0 if the rule is disabled.
ClassMethod Limits(pCode As %String, Output pWarn As %Double, Output pCrit As %Double) As %Boolean
{
	set (pWarn,pCrit)=""
	if '$d(^SysPerf.ThresholdD) do ..Seed()
	set tObj=..%OpenId(pCode,0)
	if '$isobject(tObj) {
		do ..Seed()
		set tObj=..%OpenId(pCode,0)
		quit:'$isobject(tObj) 1
	}
	set pWarn=tObj.WarnValue,pCrit=tObj.CritValue
	quit tObj.Enabled
}

/// Classify a value against a rule: returns C, W or "" (fine)
ClassMethod Classify(pCode As %String, pValue As %Double, Output pThresholdText As %String) As %String
{
	set pThresholdText=""
	quit:pValue="" ""
	quit:'..Limits(pCode,.tW,.tC) ""
	set tObj=..%OpenId(pCode,0)
	set tDir=$s($isobject(tObj):tObj.Direction,1:"H")
	if tDir="L" {
		set pThresholdText="warn < "_tW_", crit < "_tC
		quit $s((tC'="")&&(pValue<tC):"C",(tW'="")&&(pValue<tW):"W",1:"")
	}
	set pThresholdText="warn > "_tW_", crit > "_tC
	quit $s((tC'="")&&(pValue>tC):"C",(tW'="")&&(pValue>tW):"W",1:"")
}

/// Insert missing default rules (existing rows are never overwritten so admin edits survive upgrades)
ClassMethod Seed(pReset As %Boolean = 0) As %Status
{
	set tSC=$$$OK
	set tXD=##class(%Dictionary.CompiledXData).%OpenId($classname()_"||Defaults",0)
	quit:'$isobject(tXD) $$$ERROR($$$GeneralError,"Defaults XData missing")
	while 'tXD.Data.AtEnd {
		set tLine=$zstrip(tXD.Data.ReadLine(),"<>WC")
		set tCode=$p(tLine,"|",1)
		continue:tCode=""
		if 'pReset,..%ExistsId(tCode) continue
		set tObj=$s(..%ExistsId(tCode):..%OpenId(tCode),1:..%New())
		set tObj.Code=tCode
		set tObj.Category=$p(tLine,"|",2)
		set tObj.Direction=$p(tLine,"|",3)
		set tObj.Unit=$p(tLine,"|",4)
		set tObj.WarnValue=$p(tLine,"|",5)
		set tObj.CritValue=$p(tLine,"|",6)
		set tObj.Description=$p(tLine,"|",7)
		set tObj.Enabled=1
		set tSC=$$$ADDSC(tSC,tObj.%Save())
	}
	quit tSC
}

/// Code|Category|Direction|Unit|Warn|Crit|Description (one rule per line)
XData Defaults [ MimeType = text/plain ]
{
CPU_BUSY_AVG|CPU|H|%|70|85|Average CPU busy over the run
CPU_BUSY_P95|CPU|H|%|85|95|95th percentile CPU busy
CPU_CORE_MAX|CPU|H|%|95|99|Average of the busiest single core (single-thread bottleneck)
CPU_IOWAIT|CPU|H|%|10|25|Average CPU I/O wait (Unix)
CPU_STEAL|CPU|H|%|5|10|Average CPU steal - hypervisor overcommit (Unix VM)
CPU_RUNQ|CPU|H|per core|1|2|Average run queue per CPU core
MEM_AVAIL_PCT|Memory|L|% RAM|15|5|Minimum available memory as % of physical RAM
MEM_COMMIT_PCT|Memory|H|%|85|95|Max % committed bytes in use (Windows)
MEM_PAGING|Memory|H|pages/s|200|1000|Average hard page reads per second (Windows) / page-ins (Unix)
MEM_SWAP|Memory|H|pages/s|1|50|Average swap in+out per second (Unix)
PAGEFILE_PCT|Memory|H|%|50|80|Max paging file usage (Windows)
DISK_READ_LAT|Disk|H|ms|10|20|Average read latency of the worst device
DISK_WRITE_LAT|Disk|H|ms|10|20|Average write latency of the worst device
DISK_LAT_P95|Disk|H|ms|25|50|95th percentile read or write latency of the worst device
DISK_QUEUE|Disk|H|requests|2|8|Average queue length of the worst device
DISK_UTIL|Disk|H|%|70|90|Average % utilisation of the worst device (Unix)
FS_USED_PCT|Disk|H|%|80|90|File system used %
GB_CACHE_HIT|Global Buffers|L|%|99|95|Global buffer cache hit ratio (100*(1-PhyRds/Glorefs))
GB_PHYRDS|Global Buffers|H|reads/s|1000|5000|Average physical database reads per second
GB_SMALL_PCT|Global Buffers|L|% RAM|20|10|Global buffers as % of RAM (too small)
GB_LARGE_PCT|Global Buffers|H|% RAM|75|85|Global buffers as % of RAM (too large, OS starvation risk)
RTN_LOADS|Routine Buffers|H|loads/s|50|200|Average routine loads/saves per second (routine buffer misses)
WD_ACTIVE_PCT|Write Daemon|H|% samples|50|80|% of samples where the write daemon was in an active phase
WD_QUEUE|Write Daemon|H|blocks|100000|300000|Maximum write daemon queue size
JRN_WRITES|Journal|H|writes/s|1000|3000|Average journal writes per second
DB_EXPAND|Database|H|blocks/s|10|100|Average database blocks added per second (expansion during load)
DB_NEAR_MAX|Database|H|% of max|80|90|Database size as % of configured maximum
IRISTEMP_MB|Database|H|MB|20480|102400|IRISTEMP size
RES_CONTENTION|Contention|H|%|1|5|Resource Nseize/Aseize/Bseize % (irisstat)
BLOCK_COLL|Contention|H|per sample|5|50|Block collisions per irisstat -D sample
PROC_GLOB_SHARE|Process|H|%|40|70|Share of global references done by a single process
LIC_USAGE|License|H|%|80|95|License units in use vs authorised
IRIS_ERRORS|IRIS|H|errors|1|10|Errors in irisstat error log
RUN_SHORT|Collection|B||||Run shorter than the minimum length for capacity analysis
COLLECT_ERR|Collection|B||||A data collector failed (e.g. perfmon access denied)
CFG_GLOBALS_AUTO|Configuration|B||||Global buffers are automatic (globals=0)
CFG_ROUTINES_AUTO|Configuration|B||||Routine buffers are automatic (routines=0)
CFG_GMHEAP|Configuration|B||||Shared memory heap (gmheap) is automatic/small
CFG_LOCKSIZ|Configuration|B||||Lock table size (locksiz) default
CFG_JRN_SAME_VOL|Configuration|B||||Journal, WIJ and databases on the same volume
CFG_JRN_ALT_SAME|Configuration|B||||Alternate journal directory equals primary
CFG_WIJ_DEFAULT|Configuration|B||||WIJ in default location (mgr directory)
CFG_FREEZE_ON_ERR|Configuration|B||||Journal FreezeOnError disabled
CFG_NO_MIRROR|Configuration|B||||Instance not a mirror member (no HA)
CFG_DAILY_PERF_OFF|Configuration|B||||Daily ^SystemPerformance reports not enabled
CFG_CONSOLE_LOG|Configuration|B||||messages.log max size is small
CFG_SYS_DRIVE|Configuration|B||||Instance / databases on the operating system drive
CFG_JRN_PURGE|Configuration|B||||Journal purge settings
CFG_DB_NOJRN|Configuration|B||||Application database not journaled
CFG_LARGE_PAGES|Configuration|B||||Large/huge pages for shared memory
LIC_EVAL|License|B||||Evaluation / non-production license or no license key
OS_HUGEPAGES|OS|B||||Linux huge pages not configured
OS_SWAPPINESS|OS|H||10|60|Linux vm.swappiness
OS_DIRTY|OS|B||||Linux dirty page ratios
OS_UPTIME|OS|B||||Server uptime
OS_VM|OS|B||||Virtual machine guidance
ECP_ACTIVE|ECP|B||||ECP activity
PM_HOT_GLOBAL|PERFMON Globals|H|% refs|25|50|Share of all global references on a single global
PM_GLOBAL_PHYRD|PERFMON Globals|H|reads/s|500|2000|Physical block reads per second caused by a single global (cache misses / scans)
PM_GLOBAL_JRN|PERFMON Globals|H|entries/s|300|1500|Journal entries per second for a single global
PM_GLOBAL_UPD|PERFMON Globals|H|updates/s|5000|20000|Sets + kills per second on a single global
PM_BLKALLOC|PERFMON Globals|H|blocks/s|50|500|New blocks allocated per second for a single global (growth)
PM_DICT_REFS|PERFMON Globals|H|% refs|5|15|Share of references to the class dictionary (^oddCOM, ^oddDEF, ^oddXML, ...) - runtime reflection
PM_SQL_TEMP|PERFMON Globals|H|% refs|10|25|Share of references to SQL / process temporary globals (%ISCQueryTemp, IRIS.Temp*, CacheTemp*)
PM_HOT_ROUTINE|PERFMON Routines|H|% lines|20|40|Share of all executed lines in a single routine
PM_SQL_LINES|PERFMON Routines|H|% lines|30|60|Share of executed lines in cached SQL query routines (%sqlcq.*)
PM_RTN_LOADS|PERFMON Routines|H|loads/s|10000|50000|Routine loads per second by a single process (call overhead)
PM_PROC_SHARE|PERFMON Processes|H|% refs|25|50|Share of all global references by a single process
PM_LOCK_WAIT|PERFMON Processes|H|processes|1|5|Processes waiting for a LOCK at collection time
PM_SHORT|PERFMON Collection|B||||Collection shorter than 30 seconds
}

Storage Default
{
<Data name="ThresholdDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Category</Value>
</Value>
<Value name="3">
<Value>Description</Value>
</Value>
<Value name="4">
<Value>Unit</Value>
</Value>
<Value name="5">
<Value>WarnValue</Value>
</Value>
<Value name="6">
<Value>CritValue</Value>
</Value>
<Value name="7">
<Value>Direction</Value>
</Value>
<Value name="8">
<Value>Enabled</Value>
</Value>
<Value name="9">
<Value>ModifiedBy</Value>
</Value>
<Value name="10">
<Value>ModifiedTS</Value>
</Value>
</Data>
<DataLocation>^SysPerf.ThresholdD</DataLocation>
<DefaultData>ThresholdDefaultData</DefaultData>
<IdLocation>^SysPerf.ThresholdD</IdLocation>
<IndexLocation>^SysPerf.ThresholdI</IndexLocation>
<StreamLocation>^SysPerf.ThresholdS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
