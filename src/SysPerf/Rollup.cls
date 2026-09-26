/// Builds hourly roll-ups (count / sum / min / max / p95) of every catalogue metric for one run.
Class SysPerf.Rollup [ Abstract ]
{

ClassMethod Build(pRunId As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tRun=##class(SysPerf.Data.Run).%OpenId(pRunId,0)
		if '$isobject(tRun) set tSC=$$$ERROR($$$GeneralError,"Run "_pRunId_" not found") quit
		set tSys=tRun.SystemName
		&sql(DELETE %NOLOCK FROM SysPerf_Data.HourlyStat WHERE Run=:pRunId)
		kill ^||R
		set tSC=##class(SysPerf.Metrics).Load(.tCat) quit:$$$ISERR(tSC)
		// ---- group metrics per table (+ chosen source)
		kill tByQ
		for i=1:1:$ll(tCat) {
			set tCode=$li(tCat,i),m=tCat(tCode),tTable=$li(m,4),tCol=$li(m,5),tSrcList=$li(m,6)
			if tTable="Mgstat" { set tByQ("Mgstat","-",tCode)=tCol continue }
			if tTable="Process" continue
			set tSrc=..PickSource(pRunId,tTable,tCol,tSrcList)
			continue:tSrc=""
			set tByQ(tTable,tSrc,tCode)=tCol
		}
		set tTable=""
		for {
			set tTable=$o(tByQ(tTable)) quit:tTable=""
			set tSrc=""
			for {
				set tSrc=$o(tByQ(tTable,tSrc)) quit:tSrc=""
				set tCols="",tCode=""
				for { set tCode=$o(tByQ(tTable,tSrc,tCode)) quit:tCode=""  set tCols=tCols_","_tByQ(tTable,tSrc,tCode) }
				set tSQL="SELECT SampleTS"_$s(tTable="DiskStat":",Device",1:"")_tCols_" FROM SysPerf_Data."_tTable_" WHERE Run=?"_$s(tSrc'="-":" AND Source=?",1:"")
				set tRS=$s(tSrc'="-":##class(%SQL.Statement).%ExecDirect(,tSQL,pRunId,tSrc),1:##class(%SQL.Statement).%ExecDirect(,tSQL,pRunId))
				if tRS.%SQLCODE<0 set tSC=$$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message) quit
				while tRS.%Next() {
					set tH=$e(tRS.SampleTS,1,13)
					continue:tH=""
					set tEnt=$s(tTable="DiskStat":tRS.Device,1:"")
					set tCode=""
					for {
						set tCode=$o(tByQ(tTable,tSrc,tCode)) quit:tCode=""
						set v=tRS.%Get(tByQ(tTable,tSrc,tCode))
						continue:v=""
						do ..Acc(tCode,tEnt,tH,v)
					}
				}
			}
			quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
		// ---- IRIS process count per %SS sample
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT SampleTS,COUNT(*) N FROM SysPerf_Data.Process WHERE Run=? GROUP BY SampleNo",pRunId)
		while tRS.%Next() { set tH=$e(tRS.SampleTS,1,13) continue:tH=""  do ..Acc("IRISProcesses","",tH,tRS.N) }
		// ---- write rows
		set tCode=""
		for {
			set tCode=$o(^||R(tCode)) quit:tCode=""
			set tEnt=""
			for {
				set tEnt=$o(^||R(tCode,tEnt)) quit:tEnt=""
				set tH=""
				for {
					set tH=$o(^||R(tCode,tEnt,tH)) quit:tH=""
					set a=^||R(tCode,tEnt,tH)
					kill tVals merge tVals=^||R(tCode,tEnt,tH,"v")
					set tObj=##class(SysPerf.Data.HourlyStat).%New()
					do tObj.RunSetObjectId(pRunId)
					set tObj.SystemName=tSys,tObj.Metric=tCode,tObj.Entity=$s(tEnt=" ":"-",1:tEnt)
					set tObj.HourTS=tH_":00:00",tObj.HourDate=$zdh($e(tH,1,10),3),tObj.HourOfDay=+$e(tH,12,13)
					set tObj.DayOfWeek=$zd(tObj.HourDate,10)+1
					set tObj.Cnt=$li(a,1),tObj.SumV=$li(a,2),tObj.MinV=$li(a,3),tObj.MaxV=$li(a,4)
					set tObj.AvgV=$fn($li(a,2)/$li(a,1),"",3)
					set tObj.P95=##class(SysPerf.Util).Percentile(.tVals,$li(a,1),95)
					set tSC=tObj.%Save() quit:$$$ISERR(tSC)
				}
				quit:$$$ISERR(tSC)
			}
			quit:$$$ISERR(tSC)
		}
		kill ^||R
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

ClassMethod Acc(pCode As %String, pEnt As %String, pHour As %String, pVal As %Double) [ Private ]
{
	set:pEnt="" pEnt=" "
	set pVal=+pVal
	set a=$g(^||R(pCode,pEnt,pHour))
	if a="" { set a=$lb(1,pVal,pVal,pVal) }
	else { set $li(a,1)=$li(a,1)+1,$li(a,2)=$li(a,2)+pVal set:pVal<$li(a,3) $li(a,3)=pVal set:pVal>$li(a,4) $li(a,4)=pVal }
	set ^||R(pCode,pEnt,pHour)=a
	set ^||R(pCode,pEnt,pHour,"v",pVal)=$g(^||R(pCode,pEnt,pHour,"v",pVal))+1
}

/// First source in the priority list that has values for the column in this run
ClassMethod PickSource(pRunId As %Integer, pTable As %String, pCol As %String, pList As %String) As %String
{
	set tOut=""
	for i=1:1:$l(pList,",") {
		set tSrc=$p(pList,",",i) continue:tSrc=""
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 ID FROM SysPerf_Data."_pTable_" WHERE Run=? AND Source=? AND "_pCol_" IS NOT NULL",pRunId,tSrc)
		if tRS.%Next() set tOut=tSrc quit
	}
	quit tOut
}

}
