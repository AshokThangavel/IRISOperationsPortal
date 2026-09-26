/// Audit log of every load attempt (task, upload, manual).
Class SysPerf.Data.LoadLog Extends %Persistent [ SqlTableName = LoadLog ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.LoadLog";

Property FileName As %String(MAXLEN = 500);

Property FilePath As %String(MAXLEN = 1000);

Property FileSize As %Integer;

/// Upload | Task | Manual | Reanalyze
Property Origin As %String(MAXLEN = 20);

Property StartTS As %TimeStamp [ InitialExpression = {$zdt($h,3)} ];

Property EndTS As %TimeStamp;

Property Seconds As %Double;

/// Queued | Running | OK | Skipped | Error
Property Status As %String(MAXLEN = 20);

Property Message As %String(MAXLEN = 32000);

Property RunID As %Integer;

Property RunKey As %String(MAXLEN = 300);

Property RowsLoaded As %Integer;

Property UserName As %String(MAXLEN = 200) [ InitialExpression = {$username} ];

Property JobPID As %Integer;

/// SystemPerformance | PERFMON
Property Kind As %String(MAXLEN = 30) [ InitialExpression = "SystemPerformance" ];

Index StartIdx On StartTS;

Index StatusIdx On Status [ Type = bitmap ];

Storage Default
{
<Data name="LoadLogDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>FileName</Value>
</Value>
<Value name="3">
<Value>FilePath</Value>
</Value>
<Value name="4">
<Value>FileSize</Value>
</Value>
<Value name="5">
<Value>Origin</Value>
</Value>
<Value name="6">
<Value>StartTS</Value>
</Value>
<Value name="7">
<Value>EndTS</Value>
</Value>
<Value name="8">
<Value>Seconds</Value>
</Value>
<Value name="9">
<Value>Status</Value>
</Value>
<Value name="10">
<Value>Message</Value>
</Value>
<Value name="11">
<Value>RunID</Value>
</Value>
<Value name="12">
<Value>RunKey</Value>
</Value>
<Value name="13">
<Value>RowsLoaded</Value>
</Value>
<Value name="14">
<Value>UserName</Value>
</Value>
<Value name="15">
<Value>JobPID</Value>
</Value>
<Value name="16">
<Value>Kind</Value>
</Value>
</Data>
<DataLocation>^SysPerf.LoadLogD</DataLocation>
<DefaultData>LoadLogDefaultData</DefaultData>
<IdLocation>^SysPerf.LoadLogD</IdLocation>
<IndexLocation>^SysPerf.LoadLogI</IndexLocation>
<StreamLocation>^SysPerf.LoadLogS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
