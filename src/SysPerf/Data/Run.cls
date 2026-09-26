/// One loaded ^SystemPerformance report (one HTML file).
/// All other SysPerf.Data.* tables hang off this class through the <property>Run</property> reference.
Class SysPerf.Data.Run Extends %Persistent [ SqlTableName = Run ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Run";

/// Unique key of the run: Host:Instance:RunId  (RunId is e.g. 20260926_113112_test)
Property RunKey As %String(MAXLEN = 300) [ Required ];

/// ^SystemPerformance run id (date_time_profile)
Property RunId As %String(MAXLEN = 200);

Property Host As %String(MAXLEN = 200);

Property Instance As %String(MAXLEN = 200);

/// Host:Instance - used as the "system" filter in the UI
Property SystemName As %String(MAXLEN = 400) [ SqlComputeCode = {set {*}={Host}_":"_{Instance}}, SqlComputed, SqlComputeOnChange = (Host, Instance) ];

Property InstanceGUID As %String(MAXLEN = 100);

Property Platform As %String(DISPLAYLIST = ",Windows,Unix,Unknown", VALUELIST = ",W,U,X") [ InitialExpression = "X" ];

Property ProductVersion As %String(MAXLEN = 500);

Property IRISVersion As %String(MAXLEN = 50);

Property InstanceDirectory As %String(MAXLEN = 500);

Property SuperServerPort As %Integer;

Property Customer As %String(MAXLEN = 500);

Property LicenseOrder As %String(MAXLEN = 100);

/// Profile section
Property ProfileName As %String(MAXLEN = 200);

Property StartedBy As %String(MAXLEN = 200);

Property IntervalSec As %Integer;

Property SampleCount As %Integer;

Property PlannedDurationSec As %Integer;

Property PerfmonDefinition As %String(MAXLEN = 100);

Property LogDirectory As %String(MAXLEN = 500);

Property StartTS As %TimeStamp;

Property EndTS As %TimeStamp;

/// Date of the run start (for day/week/month grouping)
Property RunDate As %Date [ SqlComputeCode = {set {*}=$s({StartTS}="":"",1:$zdh($p({StartTS}," "),3,,,,,,,""))}, SqlComputed, SqlComputeOnChange = StartTS ];

/// Hardware / OS summary (filled from Windows info / Linux info / mgstat header)
Property OSName As %String(MAXLEN = 300);

Property OSVersion As %String(MAXLEN = 300);

Property NumCPU As %Integer;

Property CPUModel As %String(MAXLEN = 300);

Property TotalMemoryMB As %Double;

Property AvailableMemoryMB As %Double;

Property GlobalBuffersMB As %Double;

Property RoutineBuffersMB As %Double;

Property BlockSize As %Integer;

Property IsVirtual As %Boolean;

Property Hypervisor As %String(MAXLEN = 200);

Property LargePages As %Boolean;

Property BootTime As %String(MAXLEN = 100);

Property MgstatVersion As %String(MAXLEN = 50);

Property WDCycle As %String(MAXLEN = 100);

/// Sections found in the report (comma list, in document order)
Property SectionList As %String(MAXLEN = 4000);

/// Sections that failed during collection (e.g. perfmon access denied)
Property CollectionErrors As %String(MAXLEN = 4000);

/// Load bookkeeping
Property SourceFile As %String(MAXLEN = 1000);

Property FileName As %String(MAXLEN = 500);

Property FileSize As %Integer;

Property FileHash As %String(MAXLEN = 100);

Property LoadedTS As %TimeStamp [ InitialExpression = {$zdt($h,3)} ];

Property LoadedBy As %String(MAXLEN = 200) [ InitialExpression = {$username} ];

Property LoadSeconds As %Double;

Property Status As %String(DISPLAYLIST = ",Loading,Loaded,Error", VALUELIST = ",L,OK,E") [ InitialExpression = "L" ];

Property StatusText As %String(MAXLEN = 32000);

/// Analyzer output
Property HealthScore As %Integer;

Property CriticalCount As %Integer [ InitialExpression = 0 ];

Property WarningCount As %Integer [ InitialExpression = 0 ];

Property InfoCount As %Integer [ InitialExpression = 0 ];

Property AnalyzedTS As %TimeStamp;

/// Free text notes the admin can add to a run
Property Notes As %String(MAXLEN = 32000);

Index RunKeyIdx On RunKey [ Unique ];

Index HashIdx On FileHash;

Index SystemIdx On SystemName [ Type = bitmap ];

Index StartIdx On StartTS;

Index RunDateIdx On RunDate;

/// Delete a run and every child row (fast SQL deletes instead of per-object cascade)
ClassMethod Purge(pRunId As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		for tTable="Mgstat","OSStat","DiskStat","OSSample","OSColumn","Process","OSProcess","IRISJob","DatabaseFile","ConfigParam","KeyValue","ResourceStat","RoutineBuffer","Finding","HourlyStat","ReportSection","ProcessDelta" {
			set tSQL="DELETE FROM SysPerf_Data."_tTable_" WHERE Run = ?"
			set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,pRunId)
			if tRS.%SQLCODE<0 { set tSC=$$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message) quit }
		}
		quit:$$$ISERR(tSC)
		if ..%ExistsId(pRunId) { set tSC=..%DeleteId(pRunId) }
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Returns the run duration in seconds (actual, from mgstat first/last sample)
Method DurationSec() As %Integer [ CodeMode = expression ]
{
$s((..StartTS="")||(..EndTS=""):"",1:$system.SQL.Functions.DATEDIFF("s",..StartTS,..EndTS))
}

Storage Default
{
<Data name="RunDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>RunKey</Value>
</Value>
<Value name="3">
<Value>RunId</Value>
</Value>
<Value name="4">
<Value>Host</Value>
</Value>
<Value name="5">
<Value>Instance</Value>
</Value>
<Value name="6">
<Value>SystemName</Value>
</Value>
<Value name="7">
<Value>InstanceGUID</Value>
</Value>
<Value name="8">
<Value>Platform</Value>
</Value>
<Value name="9">
<Value>ProductVersion</Value>
</Value>
<Value name="10">
<Value>IRISVersion</Value>
</Value>
<Value name="11">
<Value>InstanceDirectory</Value>
</Value>
<Value name="12">
<Value>SuperServerPort</Value>
</Value>
<Value name="13">
<Value>Customer</Value>
</Value>
<Value name="14">
<Value>LicenseOrder</Value>
</Value>
<Value name="15">
<Value>ProfileName</Value>
</Value>
<Value name="16">
<Value>StartedBy</Value>
</Value>
<Value name="17">
<Value>IntervalSec</Value>
</Value>
<Value name="18">
<Value>SampleCount</Value>
</Value>
<Value name="19">
<Value>PlannedDurationSec</Value>
</Value>
<Value name="20">
<Value>PerfmonDefinition</Value>
</Value>
<Value name="21">
<Value>LogDirectory</Value>
</Value>
<Value name="22">
<Value>StartTS</Value>
</Value>
<Value name="23">
<Value>EndTS</Value>
</Value>
<Value name="24">
<Value>RunDate</Value>
</Value>
<Value name="25">
<Value>OSName</Value>
</Value>
<Value name="26">
<Value>OSVersion</Value>
</Value>
<Value name="27">
<Value>NumCPU</Value>
</Value>
<Value name="28">
<Value>CPUModel</Value>
</Value>
<Value name="29">
<Value>TotalMemoryMB</Value>
</Value>
<Value name="30">
<Value>AvailableMemoryMB</Value>
</Value>
<Value name="31">
<Value>GlobalBuffersMB</Value>
</Value>
<Value name="32">
<Value>RoutineBuffersMB</Value>
</Value>
<Value name="33">
<Value>BlockSize</Value>
</Value>
<Value name="34">
<Value>IsVirtual</Value>
</Value>
<Value name="35">
<Value>Hypervisor</Value>
</Value>
<Value name="36">
<Value>LargePages</Value>
</Value>
<Value name="37">
<Value>BootTime</Value>
</Value>
<Value name="38">
<Value>MgstatVersion</Value>
</Value>
<Value name="39">
<Value>WDCycle</Value>
</Value>
<Value name="40">
<Value>SectionList</Value>
</Value>
<Value name="41">
<Value>CollectionErrors</Value>
</Value>
<Value name="42">
<Value>SourceFile</Value>
</Value>
<Value name="43">
<Value>FileName</Value>
</Value>
<Value name="44">
<Value>FileSize</Value>
</Value>
<Value name="45">
<Value>FileHash</Value>
</Value>
<Value name="46">
<Value>LoadedTS</Value>
</Value>
<Value name="47">
<Value>LoadedBy</Value>
</Value>
<Value name="48">
<Value>LoadSeconds</Value>
</Value>
<Value name="49">
<Value>Status</Value>
</Value>
<Value name="50">
<Value>StatusText</Value>
</Value>
<Value name="51">
<Value>HealthScore</Value>
</Value>
<Value name="52">
<Value>CriticalCount</Value>
</Value>
<Value name="53">
<Value>WarningCount</Value>
</Value>
<Value name="54">
<Value>InfoCount</Value>
</Value>
<Value name="55">
<Value>AnalyzedTS</Value>
</Value>
<Value name="56">
<Value>Notes</Value>
</Value>
</Data>
<DataLocation>^SysPerf.RunD</DataLocation>
<DefaultData>RunDefaultData</DefaultData>
<IdLocation>^SysPerf.RunD</IdLocation>
<IndexLocation>^SysPerf.RunI</IndexLocation>
<StreamLocation>^SysPerf.RunS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
