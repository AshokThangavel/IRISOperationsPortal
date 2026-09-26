/// Unit tests for SysPerf. Run with:
/// <example>
///  set ^UnitTestRoot="/path/to/sysperf/"   // folder that contains samples/win_sample.html and samples/linux_sample.html
///  do ##class(%UnitTest.Manager).RunTest("",,"/nodelete/noload/norecursive")   // or:
///  do ##class(SysPerf.Test.Core).Run("/path/to/sysperf/samples/")
/// </example>
Class SysPerf.Test.Core Extends %UnitTest.TestCase
{

/// Folder with the sample reports (set by Run())
Property SampleDir As %String [ InitialExpression = {$g(^SysPerf.Test("dir"))} ];

ClassMethod Run(pSampleDir As %String) As %Status
{
	set ^SysPerf.Test("dir")=##class(%File).NormalizeDirectory(pSampleDir)
	set:$g(^UnitTestRoot)="" ^UnitTestRoot=^SysPerf.Test("dir")
	quit ##class(%UnitTest.Manager).DebugRunTestCase("","SysPerf.Test.Core","","")
}

Method TestUtilTimestamps()
{
	do $$$AssertEquals(##class(SysPerf.Util).TS("09/26/2026","11:31:27"),"2026-09-26 11:31:27","mm/dd/yyyy")
	do $$$AssertEquals(##class(SysPerf.Util).TS("09/26/26","09:07:44 PM"),"2026-09-26 21:07:44","2-digit year + PM")
	do $$$AssertEquals(##class(SysPerf.Util).TS("Sep 26 2026","12:05:00 AM"),"2026-09-26 00:05:00","month name + 12 AM")
	do $$$AssertEquals(##class(SysPerf.Util).TS("2026-09-26","10:00:00.123"),"2026-09-26 10:00:00","ISO + millis")
	do $$$AssertEquals(##class(SysPerf.Util).TS("26/09/2026","10:00:00"),"2026-09-26 10:00:00","dd/mm auto-detect")
	do $$$AssertEquals(##class(SysPerf.Util).AddSec("2026-09-26 23:59:50",20),"2026-09-27 00:00:10","day rollover")
	do $$$AssertEquals(##class(SysPerf.Util).DiffSec("2026-09-26 23:59:50","2026-09-27 00:00:10"),20,"diff across midnight")
}

Method TestUtilParsing()
{
	do $$$AssertEquals(##class(SysPerf.Util).Num("65,535 MB"),65535,"thousand separator + unit")
	do $$$AssertEquals(##class(SysPerf.Util).Num("12.5%"),12.5,"percent")
	do $$$AssertEquals(##class(SysPerf.Util).Num("abc"),"","non numeric")
	do $$$AssertEquals($lts(##class(SysPerf.Util).QuotedCSV("""a"",""b,c"",""d""""e""")),"a,b,c,d""e","quoted CSV")
	do $$$AssertEquals($ll(##class(SysPerf.Util).Words("  a"_$c(9)_" b   c ")),3,"words with tabs")
	do $$$AssertEquals(##class(SysPerf.Util).Unescape("a &lt;b&gt; &amp; &#65;"),"a <b> & A","entities")
	do $$$AssertEquals(##class(SysPerf.Util).Volume("C:\InterSystems\mgr\"),"c:","windows volume")
	do $$$AssertEquals(##class(SysPerf.Util).Volume("/data/iris/db/"),"/data","unix volume")
	do $$$AssertEquals(##class(SysPerf.Util).TimeToSec("1:02:03"),3723,"cpu time")
	set a(1)=1,a(2)=1,a(3)=1,a(10)=1
	do $$$AssertEquals(##class(SysPerf.Util).Percentile(.a,4,95),10,"p95")
	set x=##class(SysPerf.Parser.IRIS).LB("$lb(""x"",,3,""a""""b"")")
	do $$$AssertEquals($lg(x,1)_"|"_$lg(x,2)_"|"_$lg(x,3)_"|"_$lg(x,4)_"|"_$ll(x),"x||3|a""b|4","safe $lb parser")
}

Method TestWindowsReport()
{
	set tFile=..SampleDir_"win_sample.html"
	if '##class(%File).Exists(tFile) do $$$AssertSkipped("win_sample.html not found in "_..SampleDir) quit
	set tSC=##class(SysPerf.Loader).LoadFile(tFile,.tId,"Test",1)
	do $$$AssertStatusOK(tSC,"load Windows report")
	quit:$$$ISERR(tSC)
	set r=##class(SysPerf.Data.Run).%OpenId(tId)
	do $$$AssertEquals(r.Host,"AFUHIBTSVW001","host")
	do $$$AssertEquals(r.Instance,"IRISHEALTHUAT","instance")
	do $$$AssertEquals(r.Platform,"W","platform")
	do $$$AssertEquals(r.NumCPU,16,"cpus")
	do $$$AssertEquals(r.GlobalBuffersMB,16383,"global buffers")
	do $$$AssertEquals(r.BlockSize,8192,"block size")
	do $$$AssertEquals(r.TotalMemoryMB,65535,"RAM")
	do $$$AssertTrue(r.CollectionErrors["Access is denied","perfmon error detected")
	do $$$AssertEquals(..Count("Mgstat",tId),30,"30 mgstat samples")
	do $$$AssertEquals(..Count("Process",tId),91,"91 %SS rows")
	do $$$AssertEquals(..Count("IRISJob",tId),92,"92 PIDTAB rows")
	do $$$AssertEquals(..Count("DatabaseFile",tId),68,"17 databases x 4 samples")
	do $$$AssertEquals(..Count("ConfigParam",tId),1557,"CPF lines")
	do $$$AssertEquals(..Count("RoutineBuffer",tId),591,"routine buffers")
	do $$$AssertEquals(..Count("OSProcess",tId),882,"tasklist rows")
	do $$$AssertTrue(..Count("Finding",tId)>20,"findings produced")
	&sql(SELECT CPU,Routine INTO :cpu,:rtn FROM SysPerf_Data.Process WHERE Run=:tId AND SampleNo=1 AND PID=15872)
	do $$$AssertEquals(cpu_"|"_rtn,"35526|MONITOR","%SS routine/CPU split")
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_Data.Finding WHERE Run=:tId AND Code='CFG_JRN_SAME_VOL' AND Severity='W')
	do $$$AssertEquals(n,1,"journal on same volume detected")
	// duplicate detection
	set tSC=##class(SysPerf.Loader).LoadFile(tFile,.tId2,"Test",0)
	do $$$AssertEquals(tId2,tId,"identical file is skipped")
}

Method TestLinuxReport()
{
	set tFile=..SampleDir_"linux_sample.html"
	if '##class(%File).Exists(tFile) do $$$AssertSkipped("linux_sample.html not found") quit
	set tSC=##class(SysPerf.Loader).LoadFile(tFile,.tId,"Test",1)
	do $$$AssertStatusOK(tSC,"load Linux report")
	quit:$$$ISERR(tSC)
	set r=##class(SysPerf.Data.Run).%OpenId(tId)
	do $$$AssertEquals(r.Platform,"U","platform")
	do $$$AssertTrue(..Count("OSStat",tId)>50,"vmstat/sar/iostat/free rows")
	do $$$AssertTrue(..Count("DiskStat",tId)>50,"iostat / sar -d rows")
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_Data.KeyValue WHERE Run=:tId AND SectionName='sysctl' AND Name='vm.swappiness')
	do $$$AssertEquals(n,1,"sysctl parsed")
	do $$$AssertTrue(..Count("HourlyStat",tId)>10,"hourly roll-up built")
}

Method TestThresholds()
{
	do ##class(SysPerf.Config.Threshold).Seed()
	do $$$AssertEquals(##class(SysPerf.Config.Threshold).Classify("CPU_BUSY_AVG",90,.t),"C","crit high")
	do $$$AssertEquals(##class(SysPerf.Config.Threshold).Classify("CPU_BUSY_AVG",75,.t),"W","warn high")
	do $$$AssertEquals(##class(SysPerf.Config.Threshold).Classify("CPU_BUSY_AVG",10,.t),"","ok")
	do $$$AssertEquals(##class(SysPerf.Config.Threshold).Classify("GB_CACHE_HIT",90,.t),"C","crit low")
}

Method Count(pTable As %String, pRun As %Integer) As %Integer
{
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) N FROM SysPerf_Data."_pTable_" WHERE Run=?",pRun)
	do tRS.%Next()
	quit tRS.N
}

Method TestPerfmonParser()
{
	set f=..SampleDir_"perfmon_sample.html"
	if '##class(%File).Exists(f) do $$$AssertSkipped("perfmon_sample.html not found") quit
	do $$$AssertTrue(##class(SysPerf.PM.Parser).IsPerfmon(f),"detected as PERFMON")
	do $$$AssertNotTrue(##class(SysPerf.PM.Parser).IsPerfmon(..SampleDir_"win_sample.html"),"SystemPerformance not detected as PERFMON")
	do $$$AssertStatusOK(##class(SysPerf.PM.Parser).Parse(f),"parse")
	do $$$AssertEquals($g(^||PM("config")),"I4HDB01PROD","configuration")
	do $$$AssertEquals($g(^||PM("host")),"afphibdsvr001","host")
	do $$$AssertEquals($g(^||PM("dur")),30,"duration")
	do $$$AssertEquals($g(^||PM("ts")),"2026-05-05 12:17:32","collection timestamp")
	do $$$AssertEquals($g(^||PM("t")),6,"six tables")
	set n="" for i=1:1:6 set n=n_$g(^||PM("t",i,"n"))_","
	do $$$AssertEquals(n,"101,201,201,139,139,262,","rows per table")
	kill ^||PM
}

Method TestPerfmonLoadAnalyze()
{
	set f=..SampleDir_"perfmon_sample.html"
	if '##class(%File).Exists(f) do $$$AssertSkipped("perfmon_sample.html not found") quit
	do $$$AssertStatusOK(##class(SysPerf.PM.Loader).LoadFile(f,.id,"Test",1),"load (forced)")
	set c=##class(SysPerf.PM.Collection).%OpenId(id)
	do $$$AssertEquals(c.Status,"OK","status")
	do $$$AssertEquals(c.GlobalCount>90,1,"globals stored")
	do $$$AssertEquals(c.ProcessCount,262,"process list stored")
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_PM.GlobalStat WHERE Coll=:id)
	do $$$AssertEquals(n,101,"GlobalStat rows")
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_PM.RoutineStat WHERE Coll=:id)
	do $$$AssertEquals(n,201,"RoutineStat rows")
	&sql(SELECT TOP 1 GlobalName INTO :g FROM SysPerf_PM.GlobalStat WHERE Coll=:id AND IsOther=0 ORDER BY PhyBlkRd DESC)
	do $$$AssertEquals(g,"HIB.RAWDATA.OriginalData2026D","top physical-read global")
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_PM.Finding WHERE Coll=:id AND Code='PM_GLOBAL_PHYRD' AND Severity='C')
	do $$$AssertTrue(n>0,"critical physical-read finding")
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_PM.Finding WHERE Coll=:id AND (Recommendation IS NULL OR Recommendation='') AND Severity IN ('C','W'))
	do $$$AssertEquals(n,0,"every critical/warning finding has a recommendation")
	do $$$AssertTrue((c.HealthScore>=0)&&(c.HealthScore<100),"health score computed")
	// duplicate detection
	do $$$AssertStatusOK(##class(SysPerf.PM.Loader).LoadFile(f,.id2,"Test"),"reload")
	do $$$AssertEquals(id2,id,"identical file skipped")
	// generic loader dispatch
	do $$$AssertStatusOK(##class(SysPerf.Loader).LoadFile(f,.id3,"Test"),"dispatch through SysPerf.Loader")
	do $$$AssertEquals(id3,id,"dispatch returns the collection")
}

Method TestPerfmonCollectorValidation()
{
	do $$$AssertStatusNotOK(##class(SysPerf.PM.Collector).Validate(5),"below minimum")
	do $$$AssertStatusNotOK(##class(SysPerf.PM.Collector).Validate(4000),"above maximum")
	do $$$AssertStatusNotOK(##class(SysPerf.PM.Collector).Validate("1e2"),"not an integer")
	do $$$AssertStatusOK(##class(SysPerf.PM.Collector).Validate(60),"valid")
}

Method TestPerfmonProcessValues()
{
	set x="Yes" do $$$AssertTrue(##class(SysPerf.PM.Loader).ProcVal("CanBeExamined",.x)&&(x=1),"Yes -> 1")
	set x="10.148.83.60" do $$$AssertNotTrue(##class(SysPerf.PM.Loader).ProcVal("CanBeExamined",.x),"IP is not a boolean")
	set x="%SYS" do $$$AssertNotTrue(##class(SysPerf.PM.Loader).ProcVal("Commands",.x),"namespace is not a number")
	set x="1,234" do $$$AssertTrue(##class(SysPerf.PM.Loader).ProcVal("Globals",.x)&&(x=1234),"thousand separator")
	do $$$AssertEquals(##class(SysPerf.PM.Loader).ProcCol("IP Address"),"ClientIP","header mapping")
	do $$$AssertEquals(##class(SysPerf.PM.Loader).ProcCol("Can Be Examined"),"CanBeExamined","header mapping with spaces")
	do $$$AssertEquals(##class(SysPerf.PM.Loader).ProcCol("ElapsedTime"),"","unknown header goes to Extra")
}

}
