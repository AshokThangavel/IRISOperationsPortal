/// "Process List" row of a PERFMON report (every IRIS job at collection time).
Class SysPerf.PM.Process Extends SysPerf.PM.Child [ SqlTableName = Process ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMProc";

Property JobNo As %Integer;

Property PID As %String(MAXLEN = 30);

Property DisplayPID As %String(MAXLEN = 30);

Property UserName As %String(MAXLEN = 200);

Property Device As %String(MAXLEN = 300);

Property Namespace As %String(MAXLEN = 100);

Property Routine As %String(MAXLEN = 500);

/// Commands executed (cumulative since process start)
Property Commands As %Double;

/// Global references (cumulative since process start)
Property Globals As %Double;

Property State As %String(MAXLEN = 30);

Property ClientName As %String(MAXLEN = 200);

Property ExeName As %String(MAXLEN = 200);

Property ClientIP As %String(MAXLEN = 100);

Property CanBeExamined As %Boolean;

Property CanBeSuspended As %Boolean;

Property CanBeTerminated As %Boolean;

Property CanReceiveBroadcast As %Boolean;

Property PrvGblBlkCnt As %Double;

Property OSUserName As %String(MAXLEN = 200);

Property CPUTime As %Double;

/// Columns not known to this class: name -> value
Property Extra As array Of %String(MAXLEN = 500);

Index PIDIdx On (PID, Coll);

Storage Default
{
<Data name="Extra">
<Attribute>Extra</Attribute>
<Structure>subnode</Structure>
<Subscript>"Extra"</Subscript>
</Data>
<Data name="ProcessDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Coll</Value>
</Value>
<Value name="3">
<Value>JobNo</Value>
</Value>
<Value name="4">
<Value>IsOther</Value>
</Value>
<Value name="5">
<Value>DisplayPID</Value>
</Value>
<Value name="6">
<Value>UserName</Value>
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
<Value>Commands</Value>
</Value>
<Value name="11">
<Value>Globals</Value>
</Value>
<Value name="12">
<Value>State</Value>
</Value>
<Value name="13">
<Value>ClientName</Value>
</Value>
<Value name="14">
<Value>ExeName</Value>
</Value>
<Value name="15">
<Value>ClientIP</Value>
</Value>
<Value name="16">
<Value>CanBeExamined</Value>
</Value>
<Value name="17">
<Value>CanBeSuspended</Value>
</Value>
<Value name="18">
<Value>CanBeTerminated</Value>
</Value>
<Value name="19">
<Value>CanReceiveBroadcast</Value>
</Value>
<Value name="20">
<Value>PrvGblBlkCnt</Value>
</Value>
<Value name="21">
<Value>OSUserName</Value>
</Value>
<Value name="22">
<Value>CPUTime</Value>
</Value>
<Value name="23">
<Value>PID</Value>
</Value>
<Value name="24">
<Value>Rank</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMProcD</DataLocation>
<DefaultData>ProcessDefaultData</DefaultData>
<IdLocation>^SysPerf.PMProcD</IdLocation>
<IndexLocation>^SysPerf.PMProcI</IndexLocation>
<StreamLocation>^SysPerf.PMProcS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
