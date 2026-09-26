/// OS process list sample (Windows tasklist -V or Unix ps -elfy).
Class SysPerf.Data.OSProcess Extends SysPerf.Data.Child [ SqlTableName = OSProcess ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.OSProcess";

/// tasklist | ps
Property Source As %String(MAXLEN = 20);

Property SampleNo As %Integer;

Property ImageName As %String(MAXLEN = 300);

Property PID As %Integer;

Property PPID As %Integer;

Property UserName As %String(MAXLEN = 200);

Property SessionName As %String(MAXLEN = 100);

Property MemKB As %Double;

Property CPUTime As %String(MAXLEN = 30);

Property CPUSeconds As %Double;

Property Status As %String(MAXLEN = 50);

Property Priority As %String(MAXLEN = 20);

Property Command As %String(MAXLEN = 2000);

Property WindowTitle As %String(MAXLEN = 500);

/// IRIS process (irisdb / iris.exe / irisstat ...)
Property IsIRIS As %Boolean [ InitialExpression = 0 ];

Index RunSample On (Run, SampleNo);

Storage Default
{
<Data name="OSProcessDefaultData">
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
<Value>ImageName</Value>
</Value>
<Value name="6">
<Value>PID</Value>
</Value>
<Value name="7">
<Value>PPID</Value>
</Value>
<Value name="8">
<Value>UserName</Value>
</Value>
<Value name="9">
<Value>SessionName</Value>
</Value>
<Value name="10">
<Value>MemKB</Value>
</Value>
<Value name="11">
<Value>CPUTime</Value>
</Value>
<Value name="12">
<Value>CPUSeconds</Value>
</Value>
<Value name="13">
<Value>Status</Value>
</Value>
<Value name="14">
<Value>Priority</Value>
</Value>
<Value name="15">
<Value>Command</Value>
</Value>
<Value name="16">
<Value>WindowTitle</Value>
</Value>
<Value name="17">
<Value>IsIRIS</Value>
</Value>
</Data>
<DataLocation>^SysPerf.OSProcessD</DataLocation>
<DefaultData>OSProcessDefaultData</DefaultData>
<IdLocation>^SysPerf.OSProcessD</IdLocation>
<IndexLocation>^SysPerf.OSProcessI</IndexLocation>
<StreamLocation>^SysPerf.OSProcessS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
