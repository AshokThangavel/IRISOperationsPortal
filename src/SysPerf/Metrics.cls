/// Catalogue of metrics that are rolled up hourly and charted in the dashboard.
/// Code|Label|Unit|Category|Table|Column|Source priority (OSStat/DiskStat only)|Better (H=higher better, L=lower better)
Class SysPerf.Metrics [ Abstract ]
{

XData Catalog [ MimeType = text/plain ]
{
Glorefs|Global references|/s|IRIS|Mgstat|Glorefs||
Gloupds|Global updates|/s|IRIS|Mgstat|Gloupds||
PhyRds|Physical DB reads|/s|IRIS|Mgstat|PhyRds||L
PhyWrs|Physical DB writes|/s|IRIS|Mgstat|PhyWrs||L
CacheHitPct|Global cache hit|%|IRIS|Mgstat|CacheHitPct||H
Rourefs|Routine references|/s|IRIS|Mgstat|Rourefs||
RouLaS|Routine loads/saves|/s|IRIS|Mgstat|RouLaS||L
WDQsz|Write daemon queue|blocks|IRIS|Mgstat|WDQsz||L
WDphase|Write daemon phase|phase|IRIS|Mgstat|WDphase||L
WIJwri|WIJ writes|/s|IRIS|Mgstat|WIJwri||
Jrnwrts|Journal writes|/s|IRIS|Mgstat|Jrnwrts||
Addblk|DB blocks added|/s|IRIS|Mgstat|Addblk||L
RemGrefs|Remote (ECP) global refs|/s|IRIS|Mgstat|RemGrefs||
PPGrefs|Process-private global refs|/s|IRIS|Mgstat|PPGrefs||
ActECP|Active ECP connections|conns|IRIS|Mgstat|ActECP||
IRISProcesses|IRIS processes|procs|IRIS|Process|PID||
CPUBusyPct|CPU busy|%|CPU|OSStat|CPUBusyPct|perfmon,sar-u,vmstat,iostat|L
CPUUserPct|CPU user|%|CPU|OSStat|CPUUserPct|perfmon,sar-u,vmstat,iostat|L
CPUSysPct|CPU system/privileged|%|CPU|OSStat|CPUSysPct|perfmon,sar-u,vmstat,iostat|L
CPUIOWaitPct|CPU I/O wait|%|CPU|OSStat|CPUIOWaitPct|sar-u,vmstat,iostat|L
CPUStealPct|CPU steal|%|CPU|OSStat|CPUStealPct|sar-u,vmstat,iostat|L
CPUMaxCorePct|Busiest core|%|CPU|OSStat|CPUMaxCorePct|perfmon,sar-u|L
RunQueue|Run queue|procs|CPU|OSStat|RunQueue|perfmon,vmstat|L
MemAvailMB|Available memory|MB|Memory|OSStat|MemAvailMB|perfmon,free|H
MemFreeMB|Free memory|MB|Memory|OSStat|MemFreeMB|free,vmstat|H
MemCommitPct|Committed bytes in use|%|Memory|OSStat|MemCommitPct|perfmon|L
PagingFilePct|Paging file usage|%|Memory|OSStat|PagingFilePct|perfmon|L
PageInPerSec|Page reads|/s|Memory|OSStat|PageInPerSec|perfmon,vmstat|L
SwapInPerSec|Swap in|KB/s|Memory|OSStat|SwapInPerSec|vmstat|L
SwapOutPerSec|Swap out|KB/s|Memory|OSStat|SwapOutPerSec|vmstat|L
ContextSwPerSec|Context switches|/s|CPU|OSStat|ContextSwPerSec|vmstat|L
NetRxKBPerSec|Network received|KB/s|Network|OSStat|NetRxKBPerSec|perfmon|
NetTxKBPerSec|Network sent|KB/s|Network|OSStat|NetTxKBPerSec|perfmon|
DiskMaxReadLatMs|Worst disk read latency|ms|Disk|OSStat|DiskMaxReadLatMs|perfmon,iostat,sar-d|L
DiskMaxWriteLatMs|Worst disk write latency|ms|Disk|OSStat|DiskMaxWriteLatMs|perfmon,iostat,sar-d|L
DiskMaxQueue|Worst disk queue|reqs|Disk|OSStat|DiskMaxQueue|perfmon,iostat,sar-d|L
DiskMaxUtilPct|Worst disk utilisation|%|Disk|OSStat|DiskMaxUtilPct|iostat,sar-d,perfmon|L
DiskTotalIOPS|Total disk IOPS|IOPS|Disk|OSStat|DiskTotalIOPS|perfmon,iostat,sar-d|
Disk.ReadLatMs|Read latency|ms|Disk device|DiskStat|ReadLatMs|perfmon,iostat,sar-d|L
Disk.WriteLatMs|Write latency|ms|Disk device|DiskStat|WriteLatMs|perfmon,iostat,sar-d|L
Disk.AwaitMs|Await|ms|Disk device|DiskStat|AwaitMs|sar-d,iostat|L
Disk.ReadsPerSec|Reads|/s|Disk device|DiskStat|ReadsPerSec|perfmon,iostat,sar-d|
Disk.WritesPerSec|Writes|/s|Disk device|DiskStat|WritesPerSec|perfmon,iostat,sar-d|
Disk.TransfersPerSec|Transfers|IOPS|Disk device|DiskStat|TransfersPerSec|perfmon,sar-d,iostat|
Disk.ReadKBPerSec|Read throughput|KB/s|Disk device|DiskStat|ReadKBPerSec|perfmon,iostat,sar-d|
Disk.WriteKBPerSec|Write throughput|KB/s|Disk device|DiskStat|WriteKBPerSec|perfmon,iostat,sar-d|
Disk.QueueLen|Queue length|reqs|Disk device|DiskStat|QueueLen|perfmon,iostat,sar-d|L
Disk.UtilPct|Utilisation|%|Disk device|DiskStat|UtilPct|iostat,sar-d,perfmon|L
}

/// Load the catalogue into pCat(code)=$lb(label,unit,category,table,column,sources,better) and pCat=$lb(codes in order)
ClassMethod Load(Output pCat) As %Status
{
	kill pCat
	if $d(^||SysPerf.Metrics) merge pCat=^||SysPerf.Metrics quit $$$OK
	set tXD=##class(%Dictionary.CompiledXData).%OpenId("SysPerf.Metrics||Catalog",0)
	quit:'$isobject(tXD) $$$ERROR($$$GeneralError,"Metric catalog missing")
	set pCat=""
	while 'tXD.Data.AtEnd {
		set tL=$zstrip(tXD.Data.ReadLine(),"<>WC") continue:tL=""
		set tCode=$p(tL,"|",1)
		set pCat(tCode)=$lb($p(tL,"|",2),$p(tL,"|",3),$p(tL,"|",4),$p(tL,"|",5),$p(tL,"|",6),$p(tL,"|",7),$p(tL,"|",8))
		set pCat=pCat_$lb(tCode)
	}
	merge ^||SysPerf.Metrics=pCat
	quit $$$OK
}

ClassMethod Label(pCode As %String) As %String
{
	do ..Load(.c)
	quit $lg($g(c(pCode)),1)
}

ClassMethod Unit(pCode As %String) As %String
{
	do ..Load(.c)
	quit $lg($g(c(pCode)),2)
}

}
