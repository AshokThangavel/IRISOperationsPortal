/// Per-device disk metrics for one sample (perfmon PhysicalDisk(x), iostat -x, sar -d).
Class SysPerf.Data.DiskStat Extends SysPerf.Data.Child [ SqlTableName = DiskStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.DiskStat";

Property Source As %String(MAXLEN = 30);

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

Property Device As %String(MAXLEN = 200);

Property ReadsPerSec As %Double;

Property WritesPerSec As %Double;

Property TransfersPerSec As %Double;

Property ReadKBPerSec As %Double;

Property WriteKBPerSec As %Double;

/// Average read latency in milliseconds
Property ReadLatMs As %Double;

/// Average write latency in milliseconds
Property WriteLatMs As %Double;

/// Combined await (sar -d / old iostat)
Property AwaitMs As %Double;

Property QueueLen As %Double;

Property ReadQueue As %Double;

Property WriteQueue As %Double;

Property UtilPct As %Double;

Property AvgReqKB As %Double;

Index TSIdx On SampleTS;

Index RunDev On (Run, Device, SampleTS);

Storage Default
{
<Data name="DiskStatDefaultData">
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
<Value>Device</Value>
</Value>
<Value name="7">
<Value>ReadsPerSec</Value>
</Value>
<Value name="8">
<Value>WritesPerSec</Value>
</Value>
<Value name="9">
<Value>TransfersPerSec</Value>
</Value>
<Value name="10">
<Value>ReadKBPerSec</Value>
</Value>
<Value name="11">
<Value>WriteKBPerSec</Value>
</Value>
<Value name="12">
<Value>ReadLatMs</Value>
</Value>
<Value name="13">
<Value>WriteLatMs</Value>
</Value>
<Value name="14">
<Value>AwaitMs</Value>
</Value>
<Value name="15">
<Value>QueueLen</Value>
</Value>
<Value name="16">
<Value>ReadQueue</Value>
</Value>
<Value name="17">
<Value>WriteQueue</Value>
</Value>
<Value name="18">
<Value>UtilPct</Value>
</Value>
<Value name="19">
<Value>AvgReqKB</Value>
</Value>
</Data>
<DataLocation>^SysPerf.DiskStatD</DataLocation>
<DefaultData>DiskStatDefaultData</DefaultData>
<IdLocation>^SysPerf.DiskStatD</IdLocation>
<IndexLocation>^SysPerf.DiskStatI</IndexLocation>
<StreamLocation>^SysPerf.DiskStatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
