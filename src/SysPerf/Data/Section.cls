/// Raw text of every section / sample of the report (HTML stripped). Lets the admin see
/// exactly what the report contained, including sections this tool does not interpret.
Class SysPerf.Data.Section Extends SysPerf.Data.Child [ SqlTableName = ReportSection ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Section";

Property Seq As %Integer;

Property Name As %String(MAXLEN = 200);

Property SampleNo As %Integer [ InitialExpression = 0 ];

Property SampleCount As %Integer;

Property LineCount As %Integer;

/// Parsed = interpreted into typed tables, Raw = stored as text only
Property ParseMode As %String(MAXLEN = 20);

Property Content As %Stream.GlobalCharacter;

Index RunName On (Run, Name, SampleNo);

Storage Default
{
<Data name="SectionDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>Seq</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>SampleNo</Value>
</Value>
<Value name="6">
<Value>SampleCount</Value>
</Value>
<Value name="7">
<Value>LineCount</Value>
</Value>
<Value name="8">
<Value>ParseMode</Value>
</Value>
<Value name="9">
<Value>Content</Value>
</Value>
</Data>
<DataLocation>^SysPerf.SectionD</DataLocation>
<DefaultData>SectionDefaultData</DefaultData>
<IdLocation>^SysPerf.SectionD</IdLocation>
<IndexLocation>^SysPerf.SectionI</IndexLocation>
<StreamLocation>^SysPerf.SectionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
