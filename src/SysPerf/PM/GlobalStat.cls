/// "Global metrics per Global" row.
Class SysPerf.PM.GlobalStat Extends (SysPerf.PM.Child, SysPerf.PM.GlobalMetrics) [ SqlTableName = GlobalStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMGlo";

Property GlobalName As %String(MAXLEN = 500);

Property Directory As %String(MAXLEN = 500);

/// Last folder of the directory (database name on most systems)
Property DBName As %String(MAXLEN = 200);

Index NameIdx On (GlobalName, Coll);

Storage Default
{
<Data name="GlobalStatDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Coll</Value>
</Value>
<Value name="3">
<Value>GlobalName</Value>
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
<Value>JrnEntry</Value>
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
<Value>PctRefs</Value>
</Value>
<Value name="20">
<Value>Rank</Value>
</Value>
<Value name="21">
<Value>TotRefs</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMGloD</DataLocation>
<DefaultData>GlobalStatDefaultData</DefaultData>
<IdLocation>^SysPerf.PMGloD</IdLocation>
<IndexLocation>^SysPerf.PMGloI</IndexLocation>
<StreamLocation>^SysPerf.PMGloS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
