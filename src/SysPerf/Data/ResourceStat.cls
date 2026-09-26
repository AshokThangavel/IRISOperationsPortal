/// System resource (latch) seize statistics from irisstat -c1 (cumulative since startup)
/// and irisstat -D (per interval). High Nseize/Aseize/Bseize % means contention.
Class SysPerf.Data.ResourceStat Extends SysPerf.Data.Child [ SqlTableName = ResourceStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.ResourceStat";

/// c1 = cumulative (irisstat -c1), D = interval (irisstat -D)
Property Source As %String(MAXLEN = 10);

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

Property IntervalSec As %Integer;

Property ResNo As %Integer;

Property ResName As %String(MAXLEN = 100);

Property Seize As %Double;

Property NSeize As %Double;

Property ASeize As %Double;

Property BSeize As %Double;

Property BusySet As %Double;

Property Wakeups As %Double;

Property NSeizePct As %Double;

Property ASeizePct As %Double;

Property BSeizePct As %Double;

Property BusySetPct As %Double;

Property WakeupsPct As %Double;

Property SeizePerSec As %Double;

Property NSeizePerSec As %Double;

Property ASeizePerSec As %Double;

Property BSeizePerSec As %Double;

/// Block collisions reported for this irisstat -D sample (same value on each row of the sample)
Property BlockCollisions As %Integer;

Index RunSrc On (Run, Source, SampleNo);

Storage Default
{
<Data name="ResourceStatDefaultData">
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
<Value>IntervalSec</Value>
</Value>
<Value name="7">
<Value>ResNo</Value>
</Value>
<Value name="8">
<Value>ResName</Value>
</Value>
<Value name="9">
<Value>Seize</Value>
</Value>
<Value name="10">
<Value>NSeize</Value>
</Value>
<Value name="11">
<Value>ASeize</Value>
</Value>
<Value name="12">
<Value>BSeize</Value>
</Value>
<Value name="13">
<Value>BusySet</Value>
</Value>
<Value name="14">
<Value>Wakeups</Value>
</Value>
<Value name="15">
<Value>NSeizePct</Value>
</Value>
<Value name="16">
<Value>ASeizePct</Value>
</Value>
<Value name="17">
<Value>BSeizePct</Value>
</Value>
<Value name="18">
<Value>BusySetPct</Value>
</Value>
<Value name="19">
<Value>WakeupsPct</Value>
</Value>
<Value name="20">
<Value>SeizePerSec</Value>
</Value>
<Value name="21">
<Value>NSeizePerSec</Value>
</Value>
<Value name="22">
<Value>ASeizePerSec</Value>
</Value>
<Value name="23">
<Value>BSeizePerSec</Value>
</Value>
<Value name="24">
<Value>BlockCollisions</Value>
</Value>
</Data>
<DataLocation>^SysPerf.ResourceStatD</DataLocation>
<DefaultData>ResourceStatDefaultData</DefaultData>
<IdLocation>^SysPerf.ResourceStatD</IdLocation>
<IndexLocation>^SysPerf.ResourceStatI</IndexLocation>
<StreamLocation>^SysPerf.ResourceStatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
