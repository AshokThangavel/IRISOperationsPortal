/// A PERFMON timed collection started from the portal or by the scheduled task.
Class SysPerf.PM.CollectRequest Extends %Persistent [ SqlTableName = CollectRequest ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMReq";

Property DurationSec As %Integer;

/// Queued | Collecting | Loading | Done | Error
Property Status As %String(MAXLEN = 20) [ InitialExpression = "Queued" ];

Property Message As %String(MAXLEN = 32000);

Property RequestedBy As %String(MAXLEN = 200) [ InitialExpression = {$username} ];

Property RequestedTS As %TimeStamp [ InitialExpression = {$zdt($h,3)} ];

Property StartTS As %TimeStamp;

Property EndTS As %TimeStamp;

Property OutputFile As %String(MAXLEN = 1000);

Property CollectionId As %Integer;

Property JobPID As %Integer;

/// Portal | Task
Property Origin As %String(MAXLEN = 20) [ InitialExpression = "Portal" ];

Index StatusIdx On Status [ Type = bitmap ];

Storage Default
{
<Data name="CollectRequestDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>DurationSec</Value>
</Value>
<Value name="3">
<Value>Status</Value>
</Value>
<Value name="4">
<Value>Message</Value>
</Value>
<Value name="5">
<Value>RequestedBy</Value>
</Value>
<Value name="6">
<Value>RequestedTS</Value>
</Value>
<Value name="7">
<Value>StartTS</Value>
</Value>
<Value name="8">
<Value>EndTS</Value>
</Value>
<Value name="9">
<Value>OutputFile</Value>
</Value>
<Value name="10">
<Value>CollectionId</Value>
</Value>
<Value name="11">
<Value>JobPID</Value>
</Value>
<Value name="12">
<Value>Origin</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMReqD</DataLocation>
<DefaultData>CollectRequestDefaultData</DefaultData>
<IdLocation>^SysPerf.PMReqD</IdLocation>
<IndexLocation>^SysPerf.PMReqI</IndexLocation>
<StreamLocation>^SysPerf.PMReqS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
