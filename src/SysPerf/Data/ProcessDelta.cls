/// Per-process activity between the first and last %SS sample of a run
/// (computed at load time) - used to find the busiest IRIS processes.
Class SysPerf.Data.ProcessDelta Extends SysPerf.Data.Child [ SqlTableName = ProcessDelta ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.ProcessDelta";

Property PID As %Integer;

Property Namespace As %String(MAXLEN = 100);

Property Routine As %String(MAXLEN = 300);

Property UserLocation As %String(MAXLEN = 300);

Property Device As %String(MAXLEN = 500);

Property FirstSample As %Integer;

Property LastSample As %Integer;

Property Seconds As %Double;

Property CPUDelta As %Double;

Property GlobDelta As %Double;

Property CPUPerSec As %Double;

Property GlobPerSec As %Double;

/// % of all global references done by processes in this run window
Property GlobSharePct As %Double;

Index RunIdx2 On (Run, GlobDelta);

Storage Default
{
<Data name="ProcessDeltaDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>PID</Value>
</Value>
<Value name="4">
<Value>Namespace</Value>
</Value>
<Value name="5">
<Value>Routine</Value>
</Value>
<Value name="6">
<Value>UserLocation</Value>
</Value>
<Value name="7">
<Value>Device</Value>
</Value>
<Value name="8">
<Value>FirstSample</Value>
</Value>
<Value name="9">
<Value>LastSample</Value>
</Value>
<Value name="10">
<Value>Seconds</Value>
</Value>
<Value name="11">
<Value>CPUDelta</Value>
</Value>
<Value name="12">
<Value>GlobDelta</Value>
</Value>
<Value name="13">
<Value>CPUPerSec</Value>
</Value>
<Value name="14">
<Value>GlobPerSec</Value>
</Value>
<Value name="15">
<Value>GlobSharePct</Value>
</Value>
</Data>
<DataLocation>^SysPerf.ProcessDeltaD</DataLocation>
<DefaultData>ProcessDeltaDefaultData</DefaultData>
<IdLocation>^SysPerf.ProcessDeltaD</IdLocation>
<IndexLocation>^SysPerf.ProcessDeltaI</IndexLocation>
<StreamLocation>^SysPerf.ProcessDeltaS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
