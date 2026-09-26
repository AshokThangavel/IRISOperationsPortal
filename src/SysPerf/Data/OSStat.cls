/// Normalised system-level OS metrics for one sample of one OS source
/// (perfmon on Windows; vmstat / sar -u / iostat avg-cpu on Unix).
/// Only the fields a source provides are filled; the rest stay NULL.
Class SysPerf.Data.OSStat Extends SysPerf.Data.Child [ SqlTableName = OSStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.OSStat";

/// perfmon | vmstat | sar-u | iostat
Property Source As %String(MAXLEN = 30);

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

/// 100 - idle
Property CPUBusyPct As %Double;

Property CPUUserPct As %Double;

Property CPUSysPct As %Double;

Property CPUIOWaitPct As %Double;

Property CPUStealPct As %Double;

Property CPUInterruptPct As %Double;

/// Highest single-core busy % in this sample (perfmon Processor(n))
Property CPUMaxCorePct As %Double;

/// Run queue (vmstat r / perfmon Processor Queue Length)
Property RunQueue As %Double;

/// Processes blocked on I/O (vmstat b)
Property ProcsBlocked As %Double;

Property ProcessCount As %Double;

Property MemFreeMB As %Double;

Property MemAvailMB As %Double;

Property MemCacheMB As %Double;

Property MemBuffMB As %Double;

Property MemCommitPct As %Double;

Property SwapUsedMB As %Double;

Property PagingFilePct As %Double;

Property PageInPerSec As %Double;

Property PageOutPerSec As %Double;

Property SwapInPerSec As %Double;

Property SwapOutPerSec As %Double;

Property BlocksInPerSec As %Double;

Property BlocksOutPerSec As %Double;

Property InterruptsPerSec As %Double;

Property ContextSwPerSec As %Double;

Property NetRxKBPerSec As %Double;

Property NetTxKBPerSec As %Double;

/// Max read latency (ms) over all disks in the sample
Property DiskMaxReadLatMs As %Double;

/// Max write latency (ms) over all disks in the sample
Property DiskMaxWriteLatMs As %Double;

Property DiskMaxQueue As %Double;

Property DiskMaxUtilPct As %Double;

Property DiskTotalIOPS As %Double;

Index TSIdx On SampleTS;

Index RunSrcTS On (Run, Source, SampleTS);

Storage Default
{
<Data name="OSStatDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>Source</Value>
</Value>
<Value name="4">
<Value>SampleNo</Value>
</Value>
<Value name="5">
<Value>SampleTS</Value>
</Value>
<Value name="6">
<Value>CPUBusyPct</Value>
</Value>
<Value name="7">
<Value>CPUUserPct</Value>
</Value>
<Value name="8">
<Value>CPUSysPct</Value>
</Value>
<Value name="9">
<Value>CPUIOWaitPct</Value>
</Value>
<Value name="10">
<Value>CPUStealPct</Value>
</Value>
<Value name="11">
<Value>CPUInterruptPct</Value>
</Value>
<Value name="12">
<Value>CPUMaxCorePct</Value>
</Value>
<Value name="13">
<Value>RunQueue</Value>
</Value>
<Value name="14">
<Value>ProcsBlocked</Value>
</Value>
<Value name="15">
<Value>ProcessCount</Value>
</Value>
<Value name="16">
<Value>MemFreeMB</Value>
</Value>
<Value name="17">
<Value>MemAvailMB</Value>
</Value>
<Value name="18">
<Value>MemCacheMB</Value>
</Value>
<Value name="19">
<Value>MemBuffMB</Value>
</Value>
<Value name="20">
<Value>MemCommitPct</Value>
</Value>
<Value name="21">
<Value>SwapUsedMB</Value>
</Value>
<Value name="22">
<Value>PagingFilePct</Value>
</Value>
<Value name="23">
<Value>PageInPerSec</Value>
</Value>
<Value name="24">
<Value>PageOutPerSec</Value>
</Value>
<Value name="25">
<Value>SwapInPerSec</Value>
</Value>
<Value name="26">
<Value>SwapOutPerSec</Value>
</Value>
<Value name="27">
<Value>BlocksInPerSec</Value>
</Value>
<Value name="28">
<Value>BlocksOutPerSec</Value>
</Value>
<Value name="29">
<Value>InterruptsPerSec</Value>
</Value>
<Value name="30">
<Value>ContextSwPerSec</Value>
</Value>
<Value name="31">
<Value>NetRxKBPerSec</Value>
</Value>
<Value name="32">
<Value>NetTxKBPerSec</Value>
</Value>
<Value name="33">
<Value>DiskMaxReadLatMs</Value>
</Value>
<Value name="34">
<Value>DiskMaxWriteLatMs</Value>
</Value>
<Value name="35">
<Value>DiskMaxQueue</Value>
</Value>
<Value name="36">
<Value>DiskMaxUtilPct</Value>
</Value>
<Value name="37">
<Value>DiskTotalIOPS</Value>
</Value>
</Data>
<DataLocation>^SysPerf.OSStatD</DataLocation>
<DefaultData>OSStatDefaultData</DefaultData>
<IdLocation>^SysPerf.OSStatD</IdLocation>
<IndexLocation>^SysPerf.OSStatI</IndexLocation>
<StreamLocation>^SysPerf.OSStatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
