/// "Global metrics per Routine" row: global activity caused by each routine.
Class SysPerf.PM.RoutineGlobal Extends (SysPerf.PM.Child, SysPerf.PM.GlobalMetrics) [ SqlTableName = RoutineGlobal ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMRGlo";

Property Routine As %String(MAXLEN = 500);

Property Directory As %String(MAXLEN = 500);

Property DBName As %String(MAXLEN = 200);

/// Cached SQL query routine (%sqlcq.*)
Property IsSQL As %Boolean;

Property ClassName As %String(MAXLEN = 500);

Index RtnIdx On (Routine, Coll);

Storage Default
{
<Data name="RoutineGlobalDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Coll</Value>
</Value>
<Value name="3">
<Value>PctRefs</Value>
</Value>
<Value name="4">
<Value>Directory</Value>
</Value>
<Value name="5">
<Value>DBName</Value>
</Value>
<Value name="6">
<Value>BlkAlloc</Value>
</Value>
<Value name="7">
<Value>ClassName</Value>
</Value>
<Value name="8">
<Value>PhyBlkRd</Value>
</Value>
<Value name="9">
<Value>PhyBlkWrt</Value>
</Value>
<Value name="10">
<Value>LogBlkRd</Value>
</Value>
<Value name="11">
<Value>RefsPerSec</Value>
</Value>
<Value name="12">
<Value>PhyRdPerSec</Value>
</Value>
<Value name="13">
<Value>JrnPerSec</Value>
</Value>
<Value name="14">
<Value>UpdPerSec</Value>
</Value>
<Value name="15">
<Value>MissPct</Value>
</Value>
<Value name="16">
<Value>GloKill</Value>
</Value>
<Value name="17">
<Value>GloSet</Value>
</Value>
<Value name="18">
<Value>IsOther</Value>
</Value>
<Value name="19">
<Value>IsSQL</Value>
</Value>
<Value name="20">
<Value>JrnEntry</Value>
</Value>
<Value name="21">
<Value>Rank</Value>
</Value>
<Value name="22">
<Value>Routine</Value>
</Value>
<Value name="23">
<Value>TotRefs</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMRGloD</DataLocation>
<DefaultData>RoutineGlobalDefaultData</DefaultData>
<IdLocation>^SysPerf.PMRGloD</IdLocation>
<IndexLocation>^SysPerf.PMRGloI</IndexLocation>
<StreamLocation>^SysPerf.PMRGloS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
