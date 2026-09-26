/// One PERFMON Timed Collection report (file) or one collection started from the portal.
Class SysPerf.PM.Collection Extends %Persistent [ SqlTableName = Collection ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.PMColl";

/// SYSTEM:CONFIG:yyyy-mm-dd hh:mm:ss
Property CollKey As %String(MAXLEN = 400) [ Required ];

/// IRIS configuration (instance) name
Property Config As %String(MAXLEN = 200);

/// Host ("System" in the report header)
Property Host As %String(MAXLEN = 200);

Property SystemName As %String(MAXLEN = 400) [ SqlComputeCode = {set {*}={Host}_":"_{Config}}, SqlComputed, SqlComputeOnChange = (Host, Config) ];

Property CollectedTS As %TimeStamp;

Property CollDate As %Date [ SqlComputeCode = {set {*}=$s({CollectedTS}="":"",1:$zdh($p({CollectedTS}," "),3,,,,,,,""))}, SqlComputed, SqlComputeOnChange = CollectedTS ];

Property DurationSec As %Integer;

/// Tables present (comma list)
Property TableList As %String(MAXLEN = 2000);

/// Totals from the per-global table (incl. "Other")
Property TotalGloRefs As %Double;

Property TotalGloSets As %Double;

Property TotalGloKills As %Double;

Property TotalPhyBlkRd As %Double;

Property TotalPhyBlkWrt As %Double;

Property TotalLogBlkRd As %Double;

Property TotalJrnEntry As %Double;

Property TotalBlkAlloc As %Double;

Property TotalRtnLines As %Double;

Property TotalRtnLoads As %Double;

Property ProcessCount As %Integer;

Property GlobalCount As %Integer;

Property RoutineCount As %Integer;

/// Upload | Task | Manual | Timed
Property Origin As %String(MAXLEN = 20);

Property SourceFile As %String(MAXLEN = 1000);

Property FileName As %String(MAXLEN = 500);

Property FileSize As %Integer;

Property FileHash As %String(MAXLEN = 100);

Property RawHtml As %Stream.GlobalCharacter;

Property LoadedTS As %TimeStamp [ InitialExpression = {$zdt($h,3)} ];

Property LoadedBy As %String(MAXLEN = 200) [ InitialExpression = {$username} ];

Property LoadSeconds As %Double;

Property Status As %String(DISPLAYLIST = ",Loading,Loaded,Error", VALUELIST = ",L,OK,E") [ InitialExpression = "L" ];

Property StatusText As %String(MAXLEN = 32000);

Property HealthScore As %Integer;

Property CriticalCount As %Integer [ InitialExpression = 0 ];

Property WarningCount As %Integer [ InitialExpression = 0 ];

Property InfoCount As %Integer [ InitialExpression = 0 ];

Property AnalyzedTS As %TimeStamp;

Property Notes As %String(MAXLEN = 32000);

Index KeyIdx On CollKey [ Unique ];

Index HashIdx On FileHash;

Index SysIdx On SystemName [ Type = bitmap ];

Index TSIdx On CollectedTS;

ClassMethod Purge(pId As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		for tT="GlobalStat","RoutineGlobal","RoutineStat","ProcessStat","Process","GenericRow","Finding" {
			set tRS=##class(%SQL.Statement).%ExecDirect(,"DELETE FROM SysPerf_PM."_tT_" WHERE Coll = ?",pId)
			if tRS.%SQLCODE<0 { set tSC=$$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message) quit }
		}
		quit:$$$ISERR(tSC)
		if ..%ExistsId(pId) set tSC=..%DeleteId(pId)
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

Storage Default
{
<Data name="CollectionDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CollKey</Value>
</Value>
<Value name="3">
<Value>Config</Value>
</Value>
<Value name="4">
<Value>Host</Value>
</Value>
<Value name="5">
<Value>SystemName</Value>
</Value>
<Value name="6">
<Value>CollectedTS</Value>
</Value>
<Value name="7">
<Value>CollDate</Value>
</Value>
<Value name="8">
<Value>DurationSec</Value>
</Value>
<Value name="9">
<Value>TableList</Value>
</Value>
<Value name="10">
<Value>TotalGloRefs</Value>
</Value>
<Value name="11">
<Value>TotalGloSets</Value>
</Value>
<Value name="12">
<Value>TotalGloKills</Value>
</Value>
<Value name="13">
<Value>TotalPhyBlkRd</Value>
</Value>
<Value name="14">
<Value>TotalPhyBlkWrt</Value>
</Value>
<Value name="15">
<Value>TotalLogBlkRd</Value>
</Value>
<Value name="16">
<Value>TotalJrnEntry</Value>
</Value>
<Value name="17">
<Value>TotalBlkAlloc</Value>
</Value>
<Value name="18">
<Value>TotalRtnLines</Value>
</Value>
<Value name="19">
<Value>TotalRtnLoads</Value>
</Value>
<Value name="20">
<Value>ProcessCount</Value>
</Value>
<Value name="21">
<Value>GlobalCount</Value>
</Value>
<Value name="22">
<Value>RoutineCount</Value>
</Value>
<Value name="23">
<Value>Origin</Value>
</Value>
<Value name="24">
<Value>SourceFile</Value>
</Value>
<Value name="25">
<Value>FileName</Value>
</Value>
<Value name="26">
<Value>FileSize</Value>
</Value>
<Value name="27">
<Value>FileHash</Value>
</Value>
<Value name="28">
<Value>RawHtml</Value>
</Value>
<Value name="29">
<Value>LoadedTS</Value>
</Value>
<Value name="30">
<Value>LoadedBy</Value>
</Value>
<Value name="31">
<Value>LoadSeconds</Value>
</Value>
<Value name="32">
<Value>Status</Value>
</Value>
<Value name="33">
<Value>StatusText</Value>
</Value>
<Value name="34">
<Value>HealthScore</Value>
</Value>
<Value name="35">
<Value>CriticalCount</Value>
</Value>
<Value name="36">
<Value>WarningCount</Value>
</Value>
<Value name="37">
<Value>InfoCount</Value>
</Value>
<Value name="38">
<Value>AnalyzedTS</Value>
</Value>
<Value name="39">
<Value>Notes</Value>
</Value>
</Data>
<DataLocation>^SysPerf.PMCollD</DataLocation>
<DefaultData>CollectionDefaultData</DefaultData>
<IdLocation>^SysPerf.PMCollD</IdLocation>
<IndexLocation>^SysPerf.PMCollI</IndexLocation>
<StreamLocation>^SysPerf.PMCollS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
