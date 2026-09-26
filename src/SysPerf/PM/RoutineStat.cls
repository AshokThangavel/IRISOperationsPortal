/// "Routine metrics per Routine" row.
Class SysPerf.PM.RoutineStat Extends SysPerf.PM.Child [ SqlTableName = RoutineStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMRtn";

Property Routine As %String(MAXLEN = 500);

Property Directory As %String(MAXLEN = 500);

Property DBName As %String(MAXLEN = 200);

/// Lines executed
Property RtnLines As %Double;

Property PctLines As %Double;

/// Routine loads (calls that loaded the routine into the process)
Property RtnLoads As %Double;

/// Routine fetches from disk/remote
Property RtnFetch As %Double;

Property LinePerLoad As %Double;

Property LinesPerSec As %Double;

Property LoadsPerSec As %Double;

Property IsSQL As %Boolean;

Property ClassName As %String(MAXLEN = 500);

Index RtnIdx On (Routine, Coll);

Storage Default
{
<Data name="RoutineStatDefaultData">
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
<Value>Directory</Value>
</Value>
<Value name="5">
<Value>DBName</Value>
</Value>
<Value name="6">
<Value>RtnLines</Value>
</Value>
<Value name="7">
<Value>PctLines</Value>
</Value>
<Value name="8">
<Value>RtnLoads</Value>
</Value>
<Value name="9">
<Value>RtnFetch</Value>
</Value>
<Value name="10">
<Value>LinePerLoad</Value>
</Value>
<Value name="11">
<Value>LinesPerSec</Value>
</Value>
<Value name="12">
<Value>LoadsPerSec</Value>
</Value>
<Value name="13">
<Value>IsSQL</Value>
</Value>
<Value name="14">
<Value>ClassName</Value>
</Value>
<Value name="15">
<Value>IsOther</Value>
</Value>
<Value name="16">
<Value>Routine</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMRtnD</DataLocation>
<DefaultData>RoutineStatDefaultData</DefaultData>
<IdLocation>^SysPerf.PMRtnD</IdLocation>
<IndexLocation>^SysPerf.PMRtnI</IndexLocation>
<StreamLocation>^SysPerf.PMRtnS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
