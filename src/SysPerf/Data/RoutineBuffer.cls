/// Routine buffer in use (irisstat -R).
Class SysPerf.Data.RoutineBuffer Extends SysPerf.Data.Child [ SqlTableName = RoutineBuffer ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.RoutineBuffer";

Property SampleNo As %Integer;

Property Hash As %Integer;

Property Buf As %Integer;

Property SizeBytes As %Integer;

Property SysNo As %Integer;

Property SFN As %Integer;

Property InUse As %Integer;

Property Old As %Integer;

Property BufType As %String(MAXLEN = 10);

Property RoutineName As %String(MAXLEN = 300);

Storage Default
{
<Data name="RoutineBufferDefaultData">
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
<Value>Hash</Value>
</Value>
<Value name="5">
<Value>Buf</Value>
</Value>
<Value name="6">
<Value>SizeBytes</Value>
</Value>
<Value name="7">
<Value>SysNo</Value>
</Value>
<Value name="8">
<Value>SFN</Value>
</Value>
<Value name="9">
<Value>InUse</Value>
</Value>
<Value name="10">
<Value>Old</Value>
</Value>
<Value name="11">
<Value>BufType</Value>
</Value>
<Value name="12">
<Value>RoutineName</Value>
</Value>
</Data>
<DataLocation>^SysPerf.RoutineBufferD</DataLocation>
<DefaultData>RoutineBufferDefaultData</DefaultData>
<IdLocation>^SysPerf.RoutineBufferD</IdLocation>
<IndexLocation>^SysPerf.RoutineBufferI</IndexLocation>
<StreamLocation>^SysPerf.RoutineBufferS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
