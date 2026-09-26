/// One mounted database from the GFILETAB section of irisstat -c1 (one row per sample).
Class SysPerf.Data.DatabaseFile Extends SysPerf.Data.Child [ SqlTableName = DatabaseFile ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.DatabaseFile";

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

Property SFN As %Integer;

Property Directory As %String(MAXLEN = 500);

/// Database name resolved from the CPF [Databases] section
Property DBName As %String(MAXLEN = 200);

Property SysNo As %Integer;

Property BlockSizeKB As %Integer;

Property Blocks As %Double;

Property SizeMB As %Double;

Property ExpBlocks As %Double;

Property MaxBlocks As %Double;

Property MaxSizeMB As %Double;

Property Collation As %Integer;

Property Flags As %String(MAXLEN = 300);

Property ReadOnly As %Boolean;

Property Journaled As %Boolean;

Property ROReason As %String(MAXLEN = 300);

Index RunSample On (Run, SampleNo);

Index DirIdx On (Directory, Run);

Storage Default
{
<Data name="DatabaseFileDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>SampleNo</Value>
</Value>
<Value name="4">
<Value>SampleTS</Value>
</Value>
<Value name="5">
<Value>SFN</Value>
</Value>
<Value name="6">
<Value>Directory</Value>
</Value>
<Value name="7">
<Value>DBName</Value>
</Value>
<Value name="8">
<Value>SysNo</Value>
</Value>
<Value name="9">
<Value>BlockSizeKB</Value>
</Value>
<Value name="10">
<Value>Blocks</Value>
</Value>
<Value name="11">
<Value>SizeMB</Value>
</Value>
<Value name="12">
<Value>ExpBlocks</Value>
</Value>
<Value name="13">
<Value>MaxBlocks</Value>
</Value>
<Value name="14">
<Value>MaxSizeMB</Value>
</Value>
<Value name="15">
<Value>Collation</Value>
</Value>
<Value name="16">
<Value>Flags</Value>
</Value>
<Value name="17">
<Value>ReadOnly</Value>
</Value>
<Value name="18">
<Value>Journaled</Value>
</Value>
<Value name="19">
<Value>ROReason</Value>
</Value>
</Data>
<DataLocation>^SysPerf.DatabaseFileD</DataLocation>
<DefaultData>DatabaseFileDefaultData</DefaultData>
<IdLocation>^SysPerf.DatabaseFileD</IdLocation>
<IndexLocation>^SysPerf.DatabaseFileI</IndexLocation>
<StreamLocation>^SysPerf.DatabaseFileS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
