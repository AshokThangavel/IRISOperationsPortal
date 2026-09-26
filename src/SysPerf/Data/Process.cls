/// One IRIS process from a %SS (^%SS system status) sample.
Class SysPerf.Data.Process Extends SysPerf.Data.Child [ SqlTableName = Process ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Process";

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

Property PID As %Integer;

/// Process running ^%SS (marked with * in the output)
Property IsCurrent As %Boolean [ InitialExpression = 0 ];

Property Device As %String(MAXLEN = 500);

Property Namespace As %String(MAXLEN = 100);

Property Routine As %String(MAXLEN = 300);

/// Commands/lines executed (cumulative)
Property CPU As %Double;

/// Global references (cumulative)
Property Glob As %Double;

Property Priority As %Integer;

Property UserLocation As %String(MAXLEN = 300);

/// System daemon (no namespace, e.g. WRTDMN, JRNDMN)
Property IsSystem As %Boolean [ InitialExpression = 0 ];

Index RunSample On (Run, SampleNo);

Index PIDIdx On (Run, PID);

Storage Default
{
<Data name="ProcessDefaultData">
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
<Value>PID</Value>
</Value>
<Value name="6">
<Value>IsCurrent</Value>
</Value>
<Value name="7">
<Value>Device</Value>
</Value>
<Value name="8">
<Value>Namespace</Value>
</Value>
<Value name="9">
<Value>Routine</Value>
</Value>
<Value name="10">
<Value>CPU</Value>
</Value>
<Value name="11">
<Value>Glob</Value>
</Value>
<Value name="12">
<Value>Priority</Value>
</Value>
<Value name="13">
<Value>UserLocation</Value>
</Value>
<Value name="14">
<Value>IsSystem</Value>
</Value>
</Data>
<DataLocation>^SysPerf.ProcessD</DataLocation>
<DefaultData>ProcessDefaultData</DefaultData>
<IdLocation>^SysPerf.ProcessD</IdLocation>
<IndexLocation>^SysPerf.ProcessI</IndexLocation>
<StreamLocation>^SysPerf.ProcessS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
