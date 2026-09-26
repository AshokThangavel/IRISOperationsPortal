/// Per process metrics: "Routine metrics per Process" + "Global metrics per Process" merged,
/// enriched with the Process List details of the same PID.
Class SysPerf.PM.ProcessStat Extends (SysPerf.PM.Child, SysPerf.PM.GlobalMetrics) [ SqlTableName = ProcessStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMPStat";

Property PID As %String(MAXLEN = 30);

Property RtnLines As %Double;

Property PctLines As %Double;

Property RtnLoads As %Double;

Property RtnFetch As %Double;

Property LinePerLoad As %Double;

Property LinesPerSec As %Double;

/// Copied from the Process List
Property UserName As %String(MAXLEN = 200);

Property Namespace As %String(MAXLEN = 100);

Property Routine As %String(MAXLEN = 500);

Property State As %String(MAXLEN = 30);

Property ClientName As %String(MAXLEN = 200);

Property ExeName As %String(MAXLEN = 200);

Property ClientIP As %String(MAXLEN = 100);

Property OSUserName As %String(MAXLEN = 200);

Property Device As %String(MAXLEN = 300);

Property JobNo As %Integer;

Property RankLines As %Integer;

Property RankRefs As %Integer;

Index PIDIdx On (PID, Coll);

Storage Default
{
<Data name="ProcessStatDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Coll</Value>
</Value>
<Value name="3">
<Value>PID</Value>
</Value>
<Value name="4">
<Value>GloSet</Value>
</Value>
<Value name="5">
<Value>GloKill</Value>
</Value>
<Value name="6">
<Value>BlkAlloc</Value>
</Value>
<Value name="7">
<Value>JrnEntry</Value>
</Value>
<Value name="8">
<Value>LinePerLoad</Value>
</Value>
<Value name="9">
<Value>LinesPerSec</Value>
</Value>
<Value name="10">
<Value>LogBlkRd</Value>
</Value>
<Value name="11">
<Value>Namespace</Value>
</Value>
<Value name="12">
<Value>PhyRdPerSec</Value>
</Value>
<Value name="13">
<Value>JrnPerSec</Value>
</Value>
<Value name="14">
<Value>ClientName</Value>
</Value>
<Value name="15">
<Value>ExeName</Value>
</Value>
<Value name="16">
<Value>ClientIP</Value>
</Value>
<Value name="17">
<Value>OSUserName</Value>
</Value>
<Value name="18">
<Value>Device</Value>
</Value>
<Value name="19">
<Value>JobNo</Value>
</Value>
<Value name="20">
<Value>RankLines</Value>
</Value>
<Value name="21">
<Value>RankRefs</Value>
</Value>
<Value name="22">
<Value>IsOther</Value>
</Value>
<Value name="23">
<Value>MissPct</Value>
</Value>
<Value name="24">
<Value>PctLines</Value>
</Value>
<Value name="25">
<Value>PctRefs</Value>
</Value>
<Value name="26">
<Value>PhyBlkRd</Value>
</Value>
<Value name="27">
<Value>PhyBlkWrt</Value>
</Value>
<Value name="28">
<Value>Rank</Value>
</Value>
<Value name="29">
<Value>RefsPerSec</Value>
</Value>
<Value name="30">
<Value>Routine</Value>
</Value>
<Value name="31">
<Value>RtnFetch</Value>
</Value>
<Value name="32">
<Value>RtnLines</Value>
</Value>
<Value name="33">
<Value>RtnLoads</Value>
</Value>
<Value name="34">
<Value>State</Value>
</Value>
<Value name="35">
<Value>TotRefs</Value>
</Value>
<Value name="36">
<Value>UpdPerSec</Value>
</Value>
<Value name="37">
<Value>UserName</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMPStatD</DataLocation>
<DefaultData>ProcessStatDefaultData</DefaultData>
<IdLocation>^SysPerf.PMPStatD</IdLocation>
<IndexLocation>^SysPerf.PMPStatI</IndexLocation>
<StreamLocation>^SysPerf.PMPStatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
