/// One line of the CPF (iris.cpf) captured in the report: [Section] Name=Value.
Class SysPerf.Data.ConfigParam Extends SysPerf.Data.Child [ SqlTableName = ConfigParam ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.ConfigParam";

Property Section As %String(MAXLEN = 200) [ SqlFieldName = SectionName ];

Property Name As %String(MAXLEN = 500);

Property Value As %String(MAXLEN = 32000);

Property LineNo As %Integer;

Index RunSecName On (Run, Section, Name);

Storage Default
{
<Data name="ConfigParamDefaultData">
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
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Value</Value>
</Value>
<Value name="6">
<Value>LineNo</Value>
</Value>
</Data>
<DataLocation>^SysPerf.ConfigParamD</DataLocation>
<DefaultData>ConfigParamDefaultData</DefaultData>
<IdLocation>^SysPerf.ConfigParamD</IdLocation>
<IndexLocation>^SysPerf.ConfigParamI</IndexLocation>
<StreamLocation>^SysPerf.ConfigParamS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
