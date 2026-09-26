/// Streams any run table as CSV (for Excel / further analysis).
/// URL: SysPerf.UI.Export.cls?id=RUN&t=Mgstat|OSStat|DiskStat|Process|ProcessDelta|IRISJob|DatabaseFile|ConfigParam|KeyValue|ResourceStat|OSProcess|RoutineBuffer|Finding|HourlyStat
/// PERFMON:  SysPerf.UI.Export.cls?id=COLLECTION&t=PM.GlobalStat|PM.RoutineGlobal|PM.RoutineStat|PM.ProcessStat|PM.Process|PM.Finding
Class SysPerf.UI.Export Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

Parameter SECURITYRESOURCE = "SysPerf_Viewer";

Parameter TABLES = "Mgstat,OSStat,DiskStat,Process,ProcessDelta,IRISJob,DatabaseFile,ConfigParam,KeyValue,ResourceStat,OSProcess,RoutineBuffer,Finding,HourlyStat,OSSample,PM.GlobalStat,PM.RoutineGlobal,PM.RoutineStat,PM.ProcessStat,PM.Process,PM.Finding";

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	set tId=$g(%request.Data("id",1)),tT=$g(%request.Data("t",1))
	if (tId'?1.N)||'$lf($lfs(..#TABLES),tT) set %response.Status="400 Bad Request" quit 1
	set %response.ContentType="text/csv"
	do %response.SetHeader("Content-Disposition","attachment; filename=""sysperf_"_$s(tT["PM.":"perfmon",1:"run")_tId_"_"_$tr(tT,".","_")_".csv""")
	do %response.SetHeader("X-Content-Type-Options","nosniff")
	do %response.SetHeader("Cache-Control","no-store")
	quit 1
}

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	set tId=$g(%request.Data("id",1)),tT=$g(%request.Data("t",1))
	if %response.Status["400" write "bad request" quit $$$OK
	if $e(tT,1,3)="PM." { set tSQL="SELECT * FROM SysPerf_PM."_$e(tT,4,*)_" WHERE Coll=? ORDER BY ID" }
	else { set tSQL="SELECT * FROM SysPerf_Data."_$s(tT="Section":"ReportSection",1:tT)_" WHERE Run=? ORDER BY ID" }
	set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,tId)
	if tRS.%SQLCODE<0 write "error: ",tRS.%Message quit $$$OK
	set tMeta=tRS.%GetMetadata(),tN=tMeta.columns.Count(),tLine=$c(65279)
	for i=1:1:tN set tLine=tLine_$s(i>1:",",1:"")_..Q(tMeta.columns.GetAt(i).colName)
	write tLine,$c(13,10)
	while tRS.%Next() {
		set tLine=""
		for i=1:1:tN {
			set v=tRS.%GetData(i)
			if tT="OSSample",tMeta.columns.GetAt(i).colName="Vals" set v=$lts(v,";")
			if v[".",$isvalidnum(v),$l($p(v,".",2))>8 set v=+$fn(v,"",6)
			set tLine=tLine_$s(i>1:",",1:"")_..Q(v)
		}
		write tLine,$c(13,10)
	}
	quit $$$OK
}

ClassMethod Q(v As %String) As %String
{
	// neutralise spreadsheet formula injection and quote when needed
	if $e(v)?1(1"=",1"+",1"@") set v="'"_v
	quit:(v'[",")&&(v'["""")&&(v'[$c(10))&&(v'[$c(13)) v
	quit """"_$replace(v,"""","""""")_""""
}

}
