/// JSON data provider for the SysPerf screens (read-only). URL: SysPerf.UI.Data.cls?action=...
/// Every action validates its parameters and uses parameterised SQL.
Class SysPerf.UI.Data Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

Parameter SECURITYRESOURCE = "SysPerf_Viewer";

/// Maximum points returned per raw series (buckets keep avg and max so peaks survive)
Parameter MAXPOINTS = 1500;

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	do %response.SetHeader("Cache-Control","no-store")
	do %response.SetHeader("X-Content-Type-Options","nosniff")
	quit 1
}

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	set tOut=""
	try {
		set tAction=$g(%request.Data("action",1))
		if '$lf($lb("systems","range","series","heatmap","kpis","runs","findings","dbgrowth","run","runfindings","rseries","rstats","rtable","section","osraw","sources","compare","loadlog","metrics","hourly"),tAction) {
			set tOut={"error":"unknown action"}
		} else {
			set tOut=$classmethod($classname(),"A"_tAction)
		}
	} catch ex {
		set tOut={"error":(ex.DisplayString())}
	}
	do tOut.%ToJSON()
	quit $$$OK
}

// ================================================================ helpers

ClassMethod P(pName As %String, pDefault As %String = "") As %String [ CodeMode = expression ]
{
$g(%request.Data(pName,1),pDefault)
}

/// Push a numeric-or-null value
ClassMethod Num(pArr As %DynamicArray, pVal As %String)
{
	if pVal="" { do pArr.%Push("","null") } else { do pArr.%Push(+pVal,"number") }
}

ClassMethod SetN(pObj As %DynamicObject, pKey As %String, pVal As %String)
{
	if pVal="" { do pObj.%Set(pKey,"","null") } else { do pObj.%Set(pKey,+pVal,"number") }
}

/// Validated date "yyyy-mm-dd" or ""
ClassMethod D(pName As %String) As %String
{
	set d=..P(pName)
	quit $s(d?4N1"-"2N1"-"2N:d,1:"")
}

ClassMethod RunId() As %Integer
{
	set tId=..P("id")
	if (tId'?1.N)||'##class(SysPerf.Data.Run).%ExistsId(tId) $$$ThrowStatus($$$ERROR($$$GeneralError,"Run not found"))
	quit tId
}

/// SQL result set -> array of objects (column names as keys, numbers typed)
ClassMethod Rows(pSQL As %String, pArgs...) As %DynamicArray
{
	set tArr=[]
	set tStmt=##class(%SQL.Statement).%New()
	set tSC=tStmt.%Prepare(pSQL) $$$ThrowOnError(tSC)
	set tRS=tStmt.%Execute(pArgs...)
	if tRS.%SQLCODE<0 $$$ThrowStatus($$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message))
	set tMeta=tRS.%GetMetadata(),tN=tMeta.columns.Count()
	for i=1:1:tN { set tCol(i)=tMeta.columns.GetAt(i).colName,tType(i)=tMeta.columns.GetAt(i).ODBCType }
	while tRS.%Next() {
		set o={}
		for i=1:1:tN {
			set v=tRS.%GetData(i)
			if $lf($lb(2,3,4,5,6,7,8,-5,-6,-7),tType(i)) { do ..SetN(o,tCol(i),v) }
			else { do o.%Set(tCol(i),v) }
		}
		do tArr.%Push(o)
	}
	quit tArr
}

ClassMethod ToEnd(pTo As %String) As %String [ CodeMode = expression ]
{
$s(pTo="":"9999-12-31 00:00:00",1:$zd($zdh(pTo,3)+1,3)_" 00:00:00")
}

ClassMethod FromTS(pFrom As %String) As %String [ CodeMode = expression ]
{
$s(pFrom="":"1900-01-01 00:00:00",1:pFrom_" 00:00:00")
}

// ================================================================ dashboard actions

ClassMethod Asystems() As %DynamicObject
{
	set tArr=..Rows("SELECT %EXACT(SystemName) AS sys, MIN(Host) AS host, MIN(Instance) AS instance, COUNT(*) AS runs, MIN(StartTS) AS firstTS, MAX(StartTS) AS lastTS FROM SysPerf_Data.Run WHERE Status='OK' GROUP BY %EXACT(SystemName) ORDER BY 1")
	quit {"systems":(tArr)}
}

ClassMethod Arange() As %DynamicObject
{
	set tSys=..P("sys")
	&sql(SELECT MIN(StartTS),MAX(EndTS) INTO :tMin,:tMax FROM SysPerf_Data.Run WHERE SystemName=:tSys AND Status='OK')
	quit {"min":($g(tMin)),"max":($g(tMax))}
}

ClassMethod Ametrics() As %DynamicObject
{
	do ##class(SysPerf.Metrics).Load(.c)
	set tArr=[]
	for i=1:1:$ll(c) { set k=$li(c,i),m=c(k) do tArr.%Push({"code":(k),"label":($li(m,1)),"unit":($li(m,2)),"cat":($li(m,3)),"table":($li(m,4)),"better":($li(m,7))}) }
	quit {"metrics":(tArr)}
}

/// Hourly/daily series of one or more metrics: metrics=a,b entity= (disk device, "*" = all devices)
ClassMethod Aseries() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..FromTS(..D("from")),tTo=..ToEnd(..D("to")),tGran=..P("gran","hour"),tEnt=..P("entity","-")
	set tList=..P("metrics",..P("metric")),tOut=[]
	do ##class(SysPerf.Metrics).Load(.c)
	for i=1:1:$l(tList,",") {
		set tM=$zstrip($p(tList,",",i),"<>W") continue:tM=""
		continue:'$d(c(tM))
		if tEnt="*" {
			set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT %EXACT(Entity) E FROM SysPerf_Data.HourlyStat WHERE SystemName=? AND Metric=? AND Entity<>'-' AND HourTS>=? AND HourTS<? ORDER BY 1",tSys,tM,tFrom,tTo)
			while tRS.%Next() { do tOut.%Push(..OneSeries(tSys,tM,tRS.E,tFrom,tTo,tGran,.c)) }
		} else {
			do tOut.%Push(..OneSeries(tSys,tM,tEnt,tFrom,tTo,tGran,.c))
		}
	}
	quit {"series":(tOut),"gran":(tGran)}
}

ClassMethod OneSeries(pSys, pMetric, pEnt, pFrom, pTo, pGran, ByRef c) As %DynamicObject
{
	set tKey=$s(pGran="day":"HourDate",1:"HourTS")
	set tSQL="SELECT "_tKey_" K, SUM(SumV) S, SUM(Cnt) N, MAX(MaxV) MX, MAX(P95) P, MIN(MinV) MN FROM SysPerf_Data.HourlyStat WHERE SystemName=? AND Metric=? AND Entity=? AND HourTS>=? AND HourTS<? GROUP BY "_tKey_" ORDER BY "_tKey
	set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,pSys,pMetric,pEnt,pFrom,pTo)
	set tPts=[]
	while tRS.%Next() {
		set p=[] do p.%Push($s(pGran="day":$zd(tRS.K,3)_" 00:00:00",1:tRS.K))
		do ..Num(p,$s(tRS.N>0:$fn(tRS.S/tRS.N,"",3),1:"")),..Num(p,tRS.P),..Num(p,tRS.MX),..Num(p,tRS.MN)
		do tPts.%Push(p)
	}
	set m=$g(c(pMetric))
	quit {"metric":(pMetric),"entity":(pEnt),"label":($lg(m,1)),"unit":($lg(m,2)),"pts":(tPts)}
}

/// Hour-of-day x day-of-week heatmap
ClassMethod Aheatmap() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..FromTS(..D("from")),tTo=..ToEnd(..D("to")),tM=..P("metric","Glorefs"),tStat=..P("stat","avg"),tEnt=..P("entity","-")
	set tExpr=$case(tStat,"max":"MAX(MaxV)","p95":"MAX(P95)",:"SUM(SumV)/SUM(Cnt)")
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT DayOfWeek D, HourOfDay H, "_tExpr_" V, COUNT(*) N FROM SysPerf_Data.HourlyStat WHERE SystemName=? AND Metric=? AND Entity=? AND HourTS>=? AND HourTS<? GROUP BY DayOfWeek,HourOfDay",tSys,tM,tEnt,tFrom,tTo)
	set tArr=[]
	while tRS.%Next() { set o={"dow":(+tRS.D),"hour":(+tRS.H),"n":(+tRS.N)} do ..SetN(o,"value",$fn(tRS.V,"",3)) do tArr.%Push(o) }
	quit {"cells":(tArr),"metric":(tM),"unit":(##class(SysPerf.Metrics).Unit(tM)),"label":(##class(SysPerf.Metrics).Label(tM))}
}

/// KPI tiles for a period + the previous period of equal length
ClassMethod Akpis() As %DynamicObject
{
	set tSys=..P("sys"),tF=..D("from"),tT=..D("to")
	set tFrom=..FromTS(tF),tTo=..ToEnd(tT)
	set tDays=$s((tF'="")&&(tT'=""):$zdh(tT,3)-$zdh(tF,3)+1,1:0)
	set tPFrom=$s(tDays:$zd($zdh(tF,3)-tDays,3)_" 00:00:00",1:""),tPTo=tFrom
	set tOut={},tK=[]
	for tM="CPUBusyPct","Glorefs","PhyRds","CacheHitPct","DiskMaxReadLatMs","DiskMaxWriteLatMs","MemAvailMB","Jrnwrts","Gloupds","RouLaS","WDQsz","IRISProcesses" {
		set o={"metric":(tM),"label":(##class(SysPerf.Metrics).Label(tM)),"unit":(##class(SysPerf.Metrics).Unit(tM))}
		do ..KPIVals(tSys,tM,tFrom,tTo,.a,.p,.x,.mn)
		do ..SetN(o,"avg",a),..SetN(o,"p95",p),..SetN(o,"max",x),..SetN(o,"min",mn)
		if tPFrom'="" { do ..KPIVals(tSys,tM,tPFrom,tPTo,.pa,.pp,.px,.pmn) do ..SetN(o,"prevAvg",pa),..SetN(o,"prevP95",pp) }
		do tK.%Push(o)
	}
	set tOut.kpis=tK
	&sql(SELECT COUNT(*),AVG(HealthScore),MIN(HealthScore),SUM(CriticalCount),SUM(WarningCount) INTO :tN,:tHA,:tHM,:tC,:tW FROM SysPerf_Data.Run WHERE SystemName=:tSys AND Status='OK' AND StartTS>=:tFrom AND StartTS<:tTo)
	do ..SetN(tOut,"runs",tN),..SetN(tOut,"healthAvg",$s(tHA="":"",1:$fn(tHA,"",0))),..SetN(tOut,"healthMin",tHM),..SetN(tOut,"crit",tC),..SetN(tOut,"warn",tW)
	if tPFrom'="" {
		&sql(SELECT AVG(HealthScore) INTO :tPH FROM SysPerf_Data.Run WHERE SystemName=:tSys AND Status='OK' AND StartTS>=:tPFrom AND StartTS<:tPTo)
		do ..SetN(tOut,"prevHealth",$s(tPH="":"",1:$fn(tPH,"",0)))
	}
	quit tOut
}

ClassMethod KPIVals(pSys, pM, pFrom, pTo, Output pAvg, Output pP95, Output pMax, Output pMin)
{
	set (pAvg,pP95,pMax,pMin)=""
	&sql(SELECT SUM(SumV),SUM(Cnt),MAX(P95),MAX(MaxV),MIN(MinV) INTO :tS,:tN,:tP,:tX,:tMn FROM SysPerf_Data.HourlyStat WHERE SystemName=:pSys AND Metric=:pM AND Entity='-' AND HourTS>=:pFrom AND HourTS<:pTo)
	if SQLCODE=0,tN>0 set pAvg=$fn(tS/tN,"",3),pP95=tP,pMax=tX,pMin=tMn
}

ClassMethod Aruns() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..FromTS(..D("from")),tTo=..ToEnd(..D("to"))
	set tWhere="Status='OK' AND StartTS>=? AND StartTS<?"
	if tSys'="" {
		set tArr=..Rows("SELECT ID id, RunKey, SystemName sys, RunId runId, ProfileName profile, StartTS startTS, EndTS endTS, IntervalSec intervalSec, SampleCount samples, HealthScore health, CriticalCount crit, WarningCount warn, InfoCount info, FileName fileName, LoadedTS loadedTS, CollectionErrors errors, Platform platform FROM SysPerf_Data.Run WHERE SystemName=? AND "_tWhere_" ORDER BY StartTS DESC",tSys,tFrom,tTo)
	} else {
		set tArr=..Rows("SELECT ID id, RunKey, SystemName sys, RunId runId, ProfileName profile, StartTS startTS, EndTS endTS, IntervalSec intervalSec, SampleCount samples, HealthScore health, CriticalCount crit, WarningCount warn, InfoCount info, FileName fileName, LoadedTS loadedTS, CollectionErrors errors, Platform platform FROM SysPerf_Data.Run WHERE "_tWhere_" ORDER BY StartTS DESC",tFrom,tTo)
	}
	quit {"runs":(tArr)}
}

/// Findings of all runs in the period, grouped by rule code
ClassMethod Afindings() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..FromTS(..D("from")),tTo=..ToEnd(..D("to"))
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT f.ID, f.Code, f.Severity, f.SevRank, f.Category, f.Title, f.Detail, f.Recommendation, f.Evidence, f.MetricValue, f.Threshold, f.Acknowledged, f.Run, r.StartTS FROM SysPerf_Data.Finding f JOIN SysPerf_Data.Run r ON r.ID=f.Run WHERE r.SystemName=? AND r.Status='OK' AND r.StartTS>=? AND r.StartTS<? AND f.Severity IN ('C','W','I') ORDER BY r.StartTS DESC",tSys,tFrom,tTo)
	kill g
	while tRS.%Next() {
		set tC=tRS.Code_"|"_tRS.Title
		// group by code (titles contain values - keep newest)
		set tC=tRS.Code
		if '$d(g(tC)) {
			set g(tC)=$lb(tRS.Severity,tRS.SevRank,tRS.Category,tRS.Title,tRS.Detail,tRS.Recommendation,tRS.Evidence,tRS.MetricValue,tRS.Threshold,tRS.Run,tRS.StartTS,tRS.ID,tRS.Acknowledged),g(tC,"n")=0,g(tC,"worst")=tRS.SevRank
		}
		set g(tC,"n")=g(tC,"n")+1
		if tRS.SevRank>g(tC,"worst") set g(tC,"worst")=tRS.SevRank
		set g(tC,"runs",tRS.Run)=""
	}
	set tArr=[],tC=""
	for { set tC=$o(g(tC)) quit:tC=""  set l=g(tC)
		set o={"code":(tC),"sev":($case(g(tC,"worst"),3:"C",2:"W",:"I")),"cat":($li(l,3)),"title":($li(l,4)),"detail":($li(l,5)),"rec":($li(l,6)),"evidence":($li(l,7)),"thr":($li(l,9)),"run":(+$li(l,10)),"lastTS":($li(l,11)),"id":(+$li(l,12)),"ack":(+$li(l,13)),"count":(+g(tC,"n"))}
		do ..SetN(o,"value",$li(l,8)),..SetN(o,"rank",g(tC,"worst"))
		do tArr.%Push(o)
	}
	quit {"findings":(tArr)}
}

/// Database sizes (last irisstat sample of each run) over time
ClassMethod Adbgrowth() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..FromTS(..D("from")),tTo=..ToEnd(..D("to"))
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT r.StartTS T, %EXACT(d.DBName) N, %EXACT(d.Directory) Dir, d.SizeMB S FROM SysPerf_Data.DatabaseFile d JOIN SysPerf_Data.Run r ON r.ID=d.Run WHERE r.SystemName=? AND r.Status='OK' AND r.StartTS>=? AND r.StartTS<? AND d.SampleNo=(SELECT MAX(x.SampleNo) FROM SysPerf_Data.DatabaseFile x WHERE x.Run=d.Run) ORDER BY r.StartTS",tSys,tFrom,tTo)
	kill g
	while tRS.%Next() { set tN=$s(tRS.N'="":tRS.N,1:tRS.Dir) set g(tN,tRS.T)=tRS.S }
	set tArr=[],tN=""
	for { set tN=$o(g(tN)) quit:tN=""  set p=[],t="" for { set t=$o(g(tN,t)) quit:t=""  set x=[] do x.%Push(t) do ..Num(x,g(tN,t)) do p.%Push(x) } do tArr.%Push({"name":(tN),"pts":(p)}) }
	quit {"dbs":(tArr)}
}

// ================================================================ run actions

ClassMethod Arun() As %DynamicObject
{
	set tId=..RunId(),r=##class(SysPerf.Data.Run).%OpenId(tId,0)
	set o={}
	for tP="RunKey","RunId","Host","Instance","SystemName","InstanceGUID","ProductVersion","IRISVersion","InstanceDirectory","Customer","ProfileName","StartedBy","PerfmonDefinition","LogDirectory","StartTS","EndTS","OSName","OSVersion","CPUModel","Hypervisor","BootTime","MgstatVersion","WDCycle","SectionList","CollectionErrors","SourceFile","FileName","FileHash","LoadedTS","LoadedBy","StatusText","AnalyzedTS","Notes" { do o.%Set(tP,$property(r,tP)) }
	for tP="SuperServerPort","IntervalSec","SampleCount","PlannedDurationSec","NumCPU","TotalMemoryMB","AvailableMemoryMB","GlobalBuffersMB","RoutineBuffersMB","BlockSize","FileSize","LoadSeconds","HealthScore","CriticalCount","WarningCount","InfoCount" { do ..SetN(o,tP,$property(r,tP)) }
	do o.%Set("Platform",r.PlatformLogicalToDisplay(r.Platform))
	do o.%Set("IsVirtual",+r.IsVirtual,"boolean"),o.%Set("LargePages",r.LargePages)
	do ..SetN(o,"DurationSec",r.DurationSec())
	do o.%Set("id",+tId,"number")
	// previous / next run of the same system
	set tSys=r.SystemName,tS=r.StartTS
	&sql(SELECT TOP 1 ID INTO :tPrev FROM SysPerf_Data.Run WHERE SystemName=:tSys AND StartTS<:tS AND Status='OK' ORDER BY StartTS DESC)
	do ..SetN(o,"prevId",$s(SQLCODE=0:tPrev,1:""))
	&sql(SELECT TOP 1 ID INTO :tNext FROM SysPerf_Data.Run WHERE SystemName=:tSys AND StartTS>:tS AND Status='OK' ORDER BY StartTS)
	do ..SetN(o,"nextId",$s(SQLCODE=0:tNext,1:""))
	quit o
}

ClassMethod Arunfindings() As %DynamicObject
{
	set tId=..RunId()
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Severity,Category,Code,Title,Detail,Recommendation,Evidence,MetricValue,Threshold,FirstTS,LastTS,DrillTab,Acknowledged,AckBy,AckTS,AckNote FROM SysPerf_Data.Finding WHERE Run=? ORDER BY SevRank DESC, Category, ID",tId)
	set tArr=[]
	while tRS.%Next() {
		set o={"id":(+tRS.ID),"sev":(tRS.Severity),"cat":(tRS.Category),"code":(tRS.Code),"title":(tRS.Title),"detail":(tRS.Detail),"rec":(tRS.Recommendation),"evidence":(tRS.Evidence),"thr":(tRS.Threshold),"first":(tRS.FirstTS),"last":(tRS.LastTS),"drill":(tRS.DrillTab),"ack":(+tRS.Acknowledged),"ackBy":(tRS.AckBy),"ackTS":(tRS.AckTS),"ackNote":(tRS.AckNote)}
		do ..SetN(o,"value",tRS.MetricValue)
		do tArr.%Push(o)
	}
	quit {"findings":(tArr)}
}

/// Which OS sources / devices / samples exist for a run
ClassMethod Asources() As %DynamicObject
{
	set tId=..RunId(),o={}
	set o.os=..Rows("SELECT %EXACT(Source) src, COUNT(*) n FROM SysPerf_Data.OSStat WHERE Run=? GROUP BY %EXACT(Source)",tId)
	set o.disk=..Rows("SELECT %EXACT(Source) src, %EXACT(Device) dev, COUNT(*) n FROM SysPerf_Data.DiskStat WHERE Run=? GROUP BY %EXACT(Source),%EXACT(Device) ORDER BY 1,2",tId)
	set o.raw=..Rows("SELECT %EXACT(Source) src, COUNT(*) n FROM SysPerf_Data.OSColumn WHERE Run=? GROUP BY %EXACT(Source)",tId)
	set o.ss=..Rows("SELECT SampleNo s, MIN(SampleTS) ts, COUNT(*) n FROM SysPerf_Data.Process WHERE Run=? GROUP BY SampleNo ORDER BY 1",tId)
	set o.jobs=..Rows("SELECT SampleNo s, MIN(SampleTS) ts, COUNT(*) n FROM SysPerf_Data.IRISJob WHERE Run=? GROUP BY SampleNo ORDER BY 1",tId)
	set o.osproc=..Rows("SELECT SampleNo s, COUNT(*) n FROM SysPerf_Data.OSProcess WHERE Run=? GROUP BY SampleNo ORDER BY 1",tId)
	set o.dbs=..Rows("SELECT SampleNo s, MIN(SampleTS) ts, COUNT(*) n FROM SysPerf_Data.DatabaseFile WHERE Run=? GROUP BY SampleNo ORDER BY 1",tId)
	set o.res=..Rows("SELECT %EXACT(Source) src, SampleNo s, MIN(SampleTS) ts, COUNT(*) n FROM SysPerf_Data.ResourceStat WHERE Run=? GROUP BY %EXACT(Source),SampleNo ORDER BY 1,2",tId)
	set o.sections=..Rows("SELECT %EXACT(Name) name, MIN(Seq) seq, COUNT(*) samples, SUM(LineCount) lines, MAX(%EXACT(ParseMode)) mode FROM SysPerf_Data.ReportSection WHERE Run=? GROUP BY %EXACT(Name) ORDER BY 2",tId)
	quit o
}

/// Raw per-sample series from Mgstat / OSStat / DiskStat (downsampled to MAXPOINTS buckets)
/// t=Mgstat|OSStat|DiskStat cols=a,b src= dev= (dev="*" -> one series per device for the first column)
ClassMethod Arseries() As %DynamicObject
{
	set tId=..RunId(),tT=..P("t","Mgstat"),tCols=..P("cols"),tSrc=..P("src"),tDev=..P("dev")
	if '$lf($lb("Mgstat","OSStat","DiskStat"),tT) quit {"error":"bad table"}
	// whitelist the columns against the class definition
	set tOK="",tCls="SysPerf.Data."_tT
	for i=1:1:$l(tCols,",") {
		set c=$zstrip($p(tCols,",",i),"<>W") continue:c=""
		continue:c'?1A.AN
		if ##class(%Dictionary.CompiledProperty).%ExistsId(tCls_"||"_c) set tOK=tOK_$lb(c)
	}
	quit:tOK="" {"series":[]}
	if tT="OSStat",tSrc="" set tSrc=##class(SysPerf.Rollup).PickSource(tId,"OSStat",$li(tOK,1),"perfmon,sar-u,vmstat,iostat,free,sar-d")
	set tOut=[]
	if tT="DiskStat",tDev="*" {
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT DISTINCT %EXACT(Device) D FROM SysPerf_Data.DiskStat WHERE Run=? AND Source=? ORDER BY 1",tId,tSrc)
		while tRS.%Next() { do tOut.%Push(..RawSeries(tId,tT,$li(tOK,1),tSrc,tRS.D,tRS.D)) }
	} else {
		for i=1:1:$ll(tOK) do tOut.%Push(..RawSeries(tId,tT,$li(tOK,i),tSrc,tDev,$li(tOK,i)))
	}
	quit {"series":(tOut)}
}

ClassMethod RawSeries(pRun, pT, pCol, pSrc, pDev, pName) As %DynamicObject
{
	set tSQL="SELECT SampleTS T, "_pCol_" V FROM SysPerf_Data."_pT_" WHERE Run=?"
	set tArgs=1,tArgs(1)=pRun
	if pT'="Mgstat",pSrc'="" set tSQL=tSQL_" AND Source=?",tArgs($i(tArgs))=pSrc
	if pT="DiskStat",pDev'="" set tSQL=tSQL_" AND Device=?",tArgs($i(tArgs))=pDev
	set tSQL=tSQL_" ORDER BY SampleTS"
	set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,tArgs...)
	set n=0
	while tRS.%Next() { continue:tRS.T=""  set n=n+1,t(n)=tRS.T,v(n)=tRS.V }
	set tPts=[],tBand=[],tB=$s(n>..#MAXPOINTS:n\..#MAXPOINTS+1,1:1)
	for i=1:tB:n {
		set (s,c)=0,mx="",mn="",e=i+tB-1 set:e>n e=n
		for j=i:1:e { continue:v(j)=""  set s=s+v(j),c=c+1 set:(mx="")||(v(j)>mx) mx=v(j) set:(mn="")||(v(j)<mn) mn=v(j) }
		set p=[] do p.%Push(t(i)) do ..Num(p,$s(c:$fn(s/c,"",3),1:"")) do tPts.%Push(p)
		if tB>1 { set b=[] do b.%Push(t(i)) do ..Num(b,mn),..Num(b,mx) do tBand.%Push(b) }
	}
	quit {"name":(pName),"col":(pCol),"pts":(tPts),"band":(tBand),"bucket":(tB),"n":(n)}
}

/// avg / min / max / p95 of every numeric column of a run table
ClassMethod Arstats() As %DynamicObject
{
	set tId=..RunId(),tT=..P("t","Mgstat"),tSrc=..P("src")
	if '$lf($lb("Mgstat","OSStat","DiskStat"),tT) quit {"error":"bad table"}
	set tCls=##class(%Dictionary.CompiledClass).%OpenId("SysPerf.Data."_tT,0),tArr=[]
	for i=1:1:tCls.Properties.Count() {
		set tP=tCls.Properties.GetAt(i)
		continue:tP.Type'="%Library.Double"
		set tW=$s(tT'="Mgstat"&&(tSrc'=""):"Source='"_$replace(tSrc,"'","''")_"'",1:"")
		do ##class(SysPerf.Analyzer).Stat(tId,tT,tP.Name,tW,.s)
		continue:'s("cnt")
		set o={"col":(tP.Name),"n":(s("cnt")),"maxTS":(s("maxTS")),"desc":($p(tP.Description,$c(13),1))}
		do ..SetN(o,"avg",s("avg")),..SetN(o,"min",s("min")),..SetN(o,"max",s("max")),..SetN(o,"p95",s("p95"))
		do tArr.%Push(o)
	}
	quit {"stats":(tArr)}
}

/// Generic run-scoped tables for the run tabs
ClassMethod Artable() As %DynamicObject
{
	set tId=..RunId(),tK=..P("k"),s=..P("s"),tSrc=..P("src")
	set:s'?1.N s=""
	if tK="process" quit {"rows":(..Rows("SELECT PID,IsCurrent,Namespace,Routine,CPU,Glob,Priority,UserLocation,Device,IsSystem FROM SysPerf_Data.Process WHERE Run=? AND SampleNo=? ORDER BY PID",tId,+s))}
	if tK="pdelta" quit {"rows":(..Rows("SELECT PID,Namespace,Routine,UserLocation,Device,CPUDelta,GlobDelta,CPUPerSec,GlobPerSec,GlobSharePct,Seconds,FirstSample,LastSample FROM SysPerf_Data.ProcessDelta WHERE Run=? ORDER BY GlobDelta DESC",tId))}
	if tK="jobs" quit {"rows":(..Rows("SELECT JobNo,PID,JobType,PState,PhyRd,LogRd,WDQBlk,Routine,Namespace,Lines,Glorefs,Device,Exe,ClientIP,RawLine FROM SysPerf_Data.IRISJob WHERE Run=? AND SampleNo=? ORDER BY JobNo",tId,+s))}
	if tK="res" quit {"rows":(..Rows("SELECT ResNo,ResName,Seize,NSeize,ASeize,BSeize,BusySet,Wakeups,NSeizePct,ASeizePct,BSeizePct,BusySetPct,WakeupsPct,SeizePerSec,NSeizePerSec,ASeizePerSec,BSeizePerSec,BlockCollisions,IntervalSec,SampleTS FROM SysPerf_Data.ResourceStat WHERE Run=? AND Source=? AND SampleNo=? ORDER BY ResNo",tId,tSrc,+s))}
	if tK="resall" quit {"rows":(..Rows("SELECT ResName,SampleNo,SampleTS,Seize,SeizePerSec,NSeizePct,ASeizePct,BSeizePct,BlockCollisions FROM SysPerf_Data.ResourceStat WHERE Run=? AND Source='D' ORDER BY SampleNo,ResNo",tId))}
	if tK="db" quit {"rows":(..Rows("SELECT SFN,DBName,Directory,SizeMB,Blocks,BlockSizeKB,MaxSizeMB,ExpBlocks,ReadOnly,Journaled,Flags,ROReason,Collation,SampleTS FROM SysPerf_Data.DatabaseFile WHERE Run=? AND SampleNo=? ORDER BY SFN",tId,+s))}
	if tK="cpf" quit {"rows":(..Rows("SELECT %EXACT(SectionName) AS ""Section"",Name,Value,LineNo FROM SysPerf_Data.ConfigParam WHERE Run=? ORDER BY LineNo",tId))}
	if tK="kv" quit {"rows":(..Rows("SELECT %EXACT(SectionName) AS ""Section"",GroupName,SampleNo,Name,Value,NumValue FROM SysPerf_Data.KeyValue WHERE Run=? ORDER BY Seq",tId))}
	if tK="osproc" quit {"rows":(..Rows("SELECT PID,PPID,ImageName,UserName,SessionName,MemKB,CPUTime,CPUSeconds,Status,Priority,IsIRIS,Command,WindowTitle FROM SysPerf_Data.OSProcess WHERE Run=? AND SampleNo=? ORDER BY MemKB DESC",tId,+s))}
	if tK="rtnbuf" quit {"rows":(..Rows("SELECT RoutineName,SizeBytes,InUse,Old,BufType,SFN,SysNo,Hash,Buf FROM SysPerf_Data.RoutineBuffer WHERE Run=? ORDER BY RoutineName",tId))}
	if tK="oscols" quit {"rows":(..Rows("SELECT %EXACT(Source) Source,ColNo,Name,ObjectName,InstanceName,Counter FROM SysPerf_Data.OSColumn WHERE Run=? ORDER BY Source,ColNo",tId))}
	if tK="disks" quit {"rows":(..Rows("SELECT %EXACT(Device) Device,COUNT(*) Samples,AVG(ReadsPerSec) ReadsPerSec,AVG(WritesPerSec) WritesPerSec,AVG(TransfersPerSec) IOPS,AVG(ReadKBPerSec) ReadKBPerSec,AVG(WriteKBPerSec) WriteKBPerSec,AVG(ReadLatMs) ReadLatMs,MAX(ReadLatMs) MaxReadLatMs,AVG(WriteLatMs) WriteLatMs,MAX(WriteLatMs) MaxWriteLatMs,AVG(AwaitMs) AwaitMs,AVG(QueueLen) QueueLen,MAX(QueueLen) MaxQueue,AVG(UtilPct) UtilPct,MAX(UtilPct) MaxUtilPct FROM SysPerf_Data.DiskStat WHERE Run=? AND Source=? GROUP BY %EXACT(Device) ORDER BY 1",tId,tSrc))}
	if tK="mgstat" quit {"rows":(..Rows("SELECT * FROM SysPerf_Data.Mgstat WHERE Run=? ORDER BY SampleNo",tId))}
	quit {"error":"unknown table"}
}

/// Raw text of one section / sample
ClassMethod Asection() As %DynamicObject
{
	set tId=..RunId(),tName=..P("name"),s=+..P("s")
	&sql(SELECT ID INTO :tSec FROM SysPerf_Data.ReportSection WHERE Run=:tId AND Name=:tName AND SampleNo=:s)
	if SQLCODE'=0 quit {"text":"","error":"Section not stored (raw sections disabled or name unknown)"}
	set tObj=##class(SysPerf.Data.Section).%OpenId(tSec,0),tTxt=""
	do tObj.Content.Rewind()
	set tMax=3000000
	while 'tObj.Content.AtEnd,$l(tTxt)<tMax { set tTxt=tTxt_tObj.Content.Read(32000) }
	quit {"text":(tTxt),"lines":(tObj.LineCount),"samples":(tObj.SampleCount),"truncated":($l(tTxt)>=tMax)}
}

/// Series from raw OS samples (any perfmon counter / vmstat / iostat / sar column). cols=colNo,colNo ent=device
ClassMethod Aosraw() As %DynamicObject
{
	set tId=..RunId(),tSrc=..P("src"),tCols=..P("cols"),tEnt=..P("ent")
	set tOut=[]
	for i=1:1:$l(tCols,",") {
		set c=$p(tCols,",",i) continue:c'?1.N
		&sql(SELECT Name INTO :tName FROM SysPerf_Data.OSColumn WHERE Run=:tId AND Source=:tSrc AND ColNo=:c)
		continue:SQLCODE'=0
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT SampleTS T, Vals FROM SysPerf_Data.OSSample WHERE Run=? AND Source=? AND (Entity=? OR ?='') ORDER BY SampleTS",tId,tSrc,tEnt,tEnt)
		kill t,v set n=0
		while tRS.%Next() { set n=n+1,t(n)=tRS.T,v(n)=$lg(tRS.Vals,c) }
		set tPts=[],tB=$s(n>..#MAXPOINTS:n\..#MAXPOINTS+1,1:1)
		for k=1:tB:n {
			set (s,cnt)=0,e=k+tB-1 set:e>n e=n
			for j=k:1:e { continue:v(j)=""  set s=s+v(j),cnt=cnt+1 }
			set p=[] do p.%Push(t(k)) do ..Num(p,$s(cnt:$fn(s/cnt,"",4),1:"")) do tPts.%Push(p)
		}
		do tOut.%Push({"name":(tName),"col":(+c),"pts":(tPts)})
	}
	quit {"series":(tOut)}
}

/// Side by side comparison of two runs: key metric stats, findings diff, CPF diff
ClassMethod Acompare() As %DynamicObject
{
	set a=..P("a"),b=..P("b")
	if (a'?1.N)||(b'?1.N)||'##class(SysPerf.Data.Run).%ExistsId(a)||'##class(SysPerf.Data.Run).%ExistsId(b) quit {"error":"Select two runs"}
	set tOut={},tM=[]
	do ##class(SysPerf.Metrics).Load(.c)
	for i=1:1:$ll(c) {
		set k=$li(c,i),m=c(k)
		continue:$li(m,4)="DiskStat"
		continue:$li(m,4)="Process"
		set o={"metric":(k),"label":($li(m,1)),"unit":($li(m,2)),"cat":($li(m,3)),"better":($li(m,7)),"table":($li(m,4)),"col":($li(m,5))}
		for tR=a,b {
			set tSrc=$s($li(m,4)="OSStat":##class(SysPerf.Rollup).PickSource(tR,"OSStat",$li(m,5),$li(m,6)),1:"")
			if ($li(m,4)="OSStat")&&(tSrc="") { set s("avg")="",s("p95")="",s("max")="" }
			else { do ##class(SysPerf.Analyzer).Stat(tR,$li(m,4),$li(m,5),$s(tSrc'="":"Source='"_tSrc_"'",1:""),.s) }
			set tP=$s(tR=a:"a",1:"b")
			do ..SetN(o,tP_"Avg",s("avg")),..SetN(o,tP_"P95",s("p95")),..SetN(o,tP_"Max",s("max"))
		}
		continue:(o.aAvg="")&&(o.bAvg="")
		do tM.%Push(o)
	}
	set tOut.metrics=tM
	// findings diff by code
	kill f
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Run,Code,Severity,Title FROM SysPerf_Data.Finding WHERE Run IN (?,?) AND Severity IN ('C','W','I')",a,b)
	while tRS.%Next() { set f(tRS.Code,$s(tRS.Run=a:"a",1:"b"))=$lb(tRS.Severity,tRS.Title) }
	set tF=[],k=""
	for { set k=$o(f(k)) quit:k=""  set x={"code":(k),"a":($lg($g(f(k,"a")),1)),"b":($lg($g(f(k,"b")),1)),"titleA":($lg($g(f(k,"a")),2)),"titleB":($lg($g(f(k,"b")),2))} set x.status=$s('$d(f(k,"a")):"new",'$d(f(k,"b")):"resolved",$lg(f(k,"a"),1)'=$lg(f(k,"b"),1):"changed",1:"same") do tF.%Push(x) }
	set tOut.findings=tF
	// CPF diff
	kill p
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Run,%EXACT(SectionName) S,Name,Value FROM SysPerf_Data.ConfigParam WHERE Run IN (?,?)",a,b)
	while tRS.%Next() { set p(tRS.S_"|"_tRS.Name,$s(tRS.Run=a:"a",1:"b"))=tRS.Value }
	set tD=[],k=""
	for { set k=$o(p(k)) quit:k=""  set va=$g(p(k,"a"),$c(0)),vb=$g(p(k,"b"),$c(0)) continue:va=vb
		do tD.%Push({"section":($p(k,"|",1)),"name":($p(k,"|",2,*)),"a":($s(va=$c(0):"(absent)",1:va)),"b":($s(vb=$c(0):"(absent)",1:vb))}) }
	set tOut.cpf=tD
	set tOut.runA=..RunBrief(a),tOut.runB=..RunBrief(b)
	quit tOut
}

ClassMethod RunBrief(pId) As %DynamicObject
{
	set r=##class(SysPerf.Data.Run).%OpenId(pId,0)
	set o={"id":(+pId),"sys":(r.SystemName),"runId":(r.RunId),"start":(r.StartTS),"end":(r.EndTS),"profile":(r.ProfileName),"version":(r.IRISVersion),"cpus":(r.NumCPU),"memMB":(r.TotalMemoryMB),"gbMB":(r.GlobalBuffersMB)}
	do ..SetN(o,"health",r.HealthScore),..SetN(o,"dur",r.DurationSec())
	quit o
}

ClassMethod Aloadlog() As %DynamicObject
{
	do ##class(SysPerf.Loader).CloseStale()
	set tId=..P("id")
	if tId?1.N quit {"rows":(..Rows("SELECT ID id,FileName,Origin,StartTS,EndTS,Seconds,Status,Message,RunID,RunKey,RowsLoaded,UserName,FileSize,Kind FROM SysPerf_Data.LoadLog WHERE ID=?",tId))}
	set tKind=..P("kind")
	if tKind="PERFMON" quit {"rows":(..Rows("SELECT TOP 200 ID id,FileName,Origin,StartTS,EndTS,Seconds,Status,Message,RunID,RunKey,RowsLoaded,UserName,FileSize,Kind FROM SysPerf_Data.LoadLog WHERE Kind='PERFMON' ORDER BY ID DESC"))}
	if tKind'="" quit {"rows":(..Rows("SELECT TOP 200 ID id,FileName,Origin,StartTS,EndTS,Seconds,Status,Message,RunID,RunKey,RowsLoaded,UserName,FileSize,Kind FROM SysPerf_Data.LoadLog WHERE Kind IS NULL OR Kind<>'PERFMON' ORDER BY ID DESC"))}
	quit {"rows":(..Rows("SELECT TOP 200 ID id,FileName,Origin,StartTS,EndTS,Seconds,Status,Message,RunID,RunKey,RowsLoaded,UserName,FileSize,Kind FROM SysPerf_Data.LoadLog ORDER BY ID DESC"))}
}

/// Raw hourly rows (export)
ClassMethod Ahourly() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..FromTS(..D("from")),tTo=..ToEnd(..D("to"))
	quit {"rows":(..Rows("SELECT HourTS,%EXACT(Metric) Metric,%EXACT(Entity) Entity,Cnt,AvgV,MinV,MaxV,P95,Run FROM SysPerf_Data.HourlyStat WHERE SystemName=? AND HourTS>=? AND HourTS<? ORDER BY HourTS,Metric,Entity",tSys,tFrom,tTo))}
}

}
