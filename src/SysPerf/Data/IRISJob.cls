/// One IRIS job from the PIDTAB + job summary of an irisstat -c1 sample.
/// Gives per-process physical reads / logical reads / state that %SS does not show.
Class SysPerf.Data.IRISJob Extends SysPerf.Data.Child [ SqlTableName = IRISJob ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.IRISJob";

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

Property JobNo As %Integer;

Property PID As %Integer;

/// Job type code (jobtyp)
Property JobType As %String(MAXLEN = 10);

/// Process state (RUN, EVT, SEM, HANG, READ, LOCK, GLOB...)
Property PState As %String(MAXLEN = 20);

Property PhyRd As %Double;

Property WDQBlk As %Double;

Property LogRd As %Double;

/// From the job summary table
Property Routine As %String(MAXLEN = 300);

Property Namespace As %String(MAXLEN = 100);

Property Lines As %Double;

Property Glorefs As %Double;

Property Device As %String(MAXLEN = 300);

Property Exe As %String(MAXLEN = 200);

Property ClientIP As %String(MAXLEN = 100);

/// Complete PIDTAB line (all columns)
Property RawLine As %String(MAXLEN = 2000);

Index RunSample On (Run, SampleNo);

Storage Default
{
<Data name="IRISJobDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>SampleNo</Value>
</Value>
<Value name="4">
<Value>SampleTS</Value>
</Value>
<Value name="5">
<Value>JobNo</Value>
</Value>
<Value name="6">
<Value>PID</Value>
</Value>
<Value name="7">
<Value>JobType</Value>
</Value>
<Value name="8">
<Value>PState</Value>
</Value>
<Value name="9">
<Value>PhyRd</Value>
</Value>
<Value name="10">
<Value>WDQBlk</Value>
</Value>
<Value name="11">
<Value>LogRd</Value>
</Value>
<Value name="12">
<Value>Routine</Value>
</Value>
<Value name="13">
<Value>Namespace</Value>
</Value>
<Value name="14">
<Value>Lines</Value>
</Value>
<Value name="15">
<Value>Glorefs</Value>
</Value>
<Value name="16">
<Value>Device</Value>
</Value>
<Value name="17">
<Value>Exe</Value>
</Value>
<Value name="18">
<Value>ClientIP</Value>
</Value>
<Value name="19">
<Value>RawLine</Value>
</Value>
</Data>
<DataLocation>^SysPerf.IRISJobD</DataLocation>
<DefaultData>IRISJobDefaultData</DefaultData>
<IdLocation>^SysPerf.IRISJobD</IdLocation>
<IndexLocation>^SysPerf.IRISJobI</IndexLocation>
<StreamLocation>^SysPerf.IRISJobS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
