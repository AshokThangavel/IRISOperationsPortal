/// Problem / observation raised by <class>SysPerf.PM.Analyzer</class> for a PERFMON collection.
Class SysPerf.PM.Finding Extends SysPerf.PM.Child [ SqlTableName = Finding ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMFind";

Property Severity As %String(DISPLAYLIST = ",Critical,Warning,Info,OK", VALUELIST = ",C,W,I,OK");

Property SevRank As %Integer [ SqlComputeCode = {set {*}=$case({Severity},"C":3,"W":2,"I":1,:0)}, SqlComputed, SqlComputeOnChange = Severity ];

Property Category As %String(MAXLEN = 50);

Property Code As %String(MAXLEN = 50);

/// Object the finding is about (global, routine, PID, database)
Property Subject As %String(MAXLEN = 500);

Property Title As %String(MAXLEN = 500);

Property Detail As %String(MAXLEN = 32000);

Property Recommendation As %String(MAXLEN = 32000);

Property Evidence As %String(MAXLEN = 32000);

Property MetricValue As %Double;

Property Threshold As %String(MAXLEN = 100);

Property DrillTab As %String(MAXLEN = 50);

Property Acknowledged As %Boolean [ InitialExpression = 0 ];

Property AckBy As %String(MAXLEN = 200);

Property AckTS As %TimeStamp;

Property AckNote As %String(MAXLEN = 4000);

Index SevIdx On Severity [ Type = bitmap ];

Storage Default
{
<Data name="FindingDefaultData">
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
<Value>Category</Value>
</Value>
<Value name="6">
<Value>Code</Value>
</Value>
<Value name="7">
<Value>Subject</Value>
</Value>
<Value name="8">
<Value>Title</Value>
</Value>
<Value name="9">
<Value>Detail</Value>
</Value>
<Value name="10">
<Value>Recommendation</Value>
</Value>
<Value name="11">
<Value>Evidence</Value>
</Value>
<Value name="12">
<Value>MetricValue</Value>
</Value>
<Value name="13">
<Value>Threshold</Value>
</Value>
<Value name="14">
<Value>DrillTab</Value>
</Value>
<Value name="15">
<Value>Acknowledged</Value>
</Value>
<Value name="16">
<Value>AckBy</Value>
</Value>
<Value name="17">
<Value>AckTS</Value>
</Value>
<Value name="18">
<Value>AckNote</Value>
</Value>
<Value name="19">
<Value>SevRank</Value>
</Value>
<Value name="20">
<Value>Severity</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMFindD</DataLocation>
<DefaultData>FindingDefaultData</DefaultData>
<IdLocation>^SysPerf.PMFindD</IdLocation>
<IndexLocation>^SysPerf.PMFindI</IndexLocation>
<StreamLocation>^SysPerf.PMFindS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
