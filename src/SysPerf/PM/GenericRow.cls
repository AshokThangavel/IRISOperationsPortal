/// Any table of a PERFMON report (also tables this version does not know, e.g. network/ECP metrics).
/// Header and cells are kept as $lists so nothing in the report is lost.
Class SysPerf.PM.GenericRow Extends SysPerf.PM.Child [ SqlTableName = GenericRow ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMGen";

Property TableName As %String(MAXLEN = 200);

Property RowNo As %Integer;

Property Header As %List;

Property Cells As %List;

Index TblIdx On (Coll, TableName, RowNo);

Storage Default
{
<Data name="GenericRowDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Coll</Value>
</Value>
<Value name="3">
<Value>Rank</Value>
</Value>
<Value name="4">
<Value>IsOther</Value>
</Value>
<Value name="5">
<Value>Header</Value>
</Value>
<Value name="6">
<Value>Cells</Value>
</Value>
<Value name="7">
<Value>RowNo</Value>
</Value>
<Value name="8">
<Value>TableName</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMGenD</DataLocation>
<DefaultData>GenericRowDefaultData</DefaultData>
<IdLocation>^SysPerf.PMGenD</IdLocation>
<IndexLocation>^SysPerf.PMGenI</IndexLocation>
<StreamLocation>^SysPerf.PMGenS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
