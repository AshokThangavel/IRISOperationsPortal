/// Generic name/value detail extracted from any section (Configuration, License, Windows info,
/// Linux info, lscpu, sysctl, irisstat header counters, journaling stats, routine stats, ...).
/// This guarantees every scalar detail of the report is queryable with SQL.
Class SysPerf.Data.KeyValue Extends SysPerf.Data.Child [ SqlTableName = KeyValue ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.KeyValue";

Property Section As %String(MAXLEN = 200) [ SqlFieldName = SectionName ];

/// Sub group inside the section (e.g. "Global Counters", "Journaling stats")
Property GroupName As %String(MAXLEN = 200);

Property SampleNo As %Integer [ InitialExpression = 0 ];

Property Name As %String(MAXLEN = 500);

Property Value As %String(MAXLEN = 32000);

/// Numeric form of Value when it is numeric (commas/units stripped)
Property NumValue As %Double;

Property Seq As %Integer;

Index RunSecName On (Run, Section, Name);

Index RunSecGrp On (Run, Section, GroupName);

Storage Default
{
<Data name="KeyValueDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>Section</Value>
</Value>
<Value name="4">
<Value>GroupName</Value>
</Value>
<Value name="5">
<Value>SampleNo</Value>
</Value>
<Value name="6">
<Value>Name</Value>
</Value>
<Value name="7">
<Value>Value</Value>
</Value>
<Value name="8">
<Value>NumValue</Value>
</Value>
<Value name="9">
<Value>Seq</Value>
</Value>
</Data>
<DataLocation>^SysPerf.KeyValueD</DataLocation>
<DefaultData>KeyValueDefaultData</DefaultData>
<IdLocation>^SysPerf.KeyValueD</IdLocation>
<IndexLocation>^SysPerf.KeyValueI</IndexLocation>
<StreamLocation>^SysPerf.KeyValueS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
