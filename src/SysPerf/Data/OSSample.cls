/// Raw OS sample: every counter of the source for one timestamp, stored as a $list
/// aligned with <class>SysPerf.Data.OSColumn</class>. Keeps 100% of the OS data
/// (e.g. all perfmon counters, per core CPU) without millions of narrow rows.
/// For iostat/sar -d the Entity is the device; for others it is empty.
Class SysPerf.Data.OSSample Extends SysPerf.Data.Child [ SqlTableName = OSSample ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.OSSample";

Property Source As %String(MAXLEN = 30);

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

Property Entity As %String(MAXLEN = 200);

Property Vals As %List;

Index RunSrcTS On (Run, Source, SampleTS);

/// Returns the value of column pColNo
Method Value(pColNo As %Integer) As %String [ CodeMode = expression ]
{
$lg(..Vals,pColNo)
}

Storage Default
{
<Data name="OSSampleDefaultData">
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
<Value>Entity</Value>
</Value>
<Value name="7">
<Value>Vals</Value>
</Value>
</Data>
<DataLocation>^SysPerf.OSSampleD</DataLocation>
<DefaultData>OSSampleDefaultData</DefaultData>
<IdLocation>^SysPerf.OSSampleD</IdLocation>
<IndexLocation>^SysPerf.OSSampleI</IndexLocation>
<StreamLocation>^SysPerf.OSSampleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
