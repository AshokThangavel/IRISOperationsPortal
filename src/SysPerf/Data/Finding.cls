/// A problem / observation raised by <class>SysPerf.Analyzer</class> for a run.
Class SysPerf.Data.Finding Extends SysPerf.Data.Child [ SqlTableName = Finding ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Finding";

/// C = Critical, W = Warning, I = Info, OK = check passed
Property Severity As %String(DISPLAYLIST = ",Critical,Warning,Info,OK", VALUELIST = ",C,W,I,OK");

/// Numeric rank for sorting (3=C,2=W,1=I,0=OK)
Property SevRank As %Integer [ SqlComputeCode = {set {*}=$case({Severity},"C":3,"W":2,"I":1,:0)}, SqlComputed, SqlComputeOnChange = Severity ];

Property Category As %String(MAXLEN = 50);

/// Rule code (see SysPerf.Config.Threshold)
Property Code As %String(MAXLEN = 50);

Property Title As %String(MAXLEN = 500);

Property Detail As %String(MAXLEN = 32000);

Property Recommendation As %String(MAXLEN = 32000);

Property Evidence As %String(MAXLEN = 32000);

Property MetricValue As %Double;

Property Threshold As %String(MAXLEN = 100);

Property FirstTS As %TimeStamp;

Property LastTS As %TimeStamp;

Property Occurrences As %Integer;

/// UI tab that shows the evidence (mgstat, os, disk, process, db, config, resource ...)
Property DrillTab As %String(MAXLEN = 50);

Property Acknowledged As %Boolean [ InitialExpression = 0 ];

Property AckBy As %String(MAXLEN = 200);

Property AckTS As %TimeStamp;

Property AckNote As %String(MAXLEN = 4000);

Index SevIdx On Severity [ Type = bitmap ];

Index CodeIdx On Code [ Type = bitmap ];

Storage Default
{
<Data name="FindingDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>Severity</Value>
</Value>
<Value name="4">
<Value>SevRank</Value>
</Value>
<Value name="5">
<Value>Category</Value>
</Value>
<Value name="6">
<Value>Code</Value>
</Value>
<Value name="7">
<Value>Title</Value>
</Value>
<Value name="8">
<Value>Detail</Value>
</Value>
<Value name="9">
<Value>Recommendation</Value>
</Value>
<Value name="10">
<Value>Evidence</Value>
</Value>
<Value name="11">
<Value>MetricValue</Value>
</Value>
<Value name="12">
<Value>Threshold</Value>
</Value>
<Value name="13">
<Value>FirstTS</Value>
</Value>
<Value name="14">
<Value>LastTS</Value>
</Value>
<Value name="15">
<Value>Occurrences</Value>
</Value>
<Value name="16">
<Value>DrillTab</Value>
</Value>
<Value name="17">
<Value>Acknowledged</Value>
</Value>
<Value name="18">
<Value>AckBy</Value>
</Value>
<Value name="19">
<Value>AckTS</Value>
</Value>
<Value name="20">
<Value>AckNote</Value>
</Value>
</Data>
<DataLocation>^SysPerf.FindingD</DataLocation>
<DefaultData>FindingDefaultData</DefaultData>
<IdLocation>^SysPerf.FindingD</IdLocation>
<IndexLocation>^SysPerf.FindingI</IndexLocation>
<StreamLocation>^SysPerf.FindingS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
