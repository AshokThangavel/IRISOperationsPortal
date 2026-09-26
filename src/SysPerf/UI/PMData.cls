/// JSON provider for the PERFMON screens (read-only).
Class SysPerf.UI.PMData Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

Parameter SECURITYRESOURCE = "SysPerf_Viewer";

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	do %response.SetHeader("Cache-Control","no-store")
	do %response.SetHeader("X-Content-Type-Options","nosniff")
	if $g(%request.Data("action",1))="raw" {
		// original report, rendered in a sandboxed iframe
		set %response.ContentType="text/html"
		do %response.SetHeader("Content-Security-Policy","sandbox; default-src 'none'; style-src 'unsafe-inline'")
	}
	quit 1
}

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	set tA=$g(%request.Data("action",1)),tOut=""
	if tA="raw" do ..Raw() quit $$$OK
	try {
		if '$lf($lb("collections","coll","findings","table","dbs","trend","topglobals","requests","request","systems"),tA) { set tOut={"error":"unknown action"} }
		else { set tOut=$classmethod($classname(),"A"_tA) }
	} catch ex { set tOut={"error":(ex.DisplayString())} }
	do tOut.%ToJSON()
	quit $$$OK
}

ClassMethod P(pName, pDefault = "") As %String [ CodeMode = expression ]
{
$g(%request.Data(pName,1),pDefault)
}

ClassMethod Id() As %Integer
{
	set tId=..P("id")
	if (tId'?1.N)||'##class(SysPerf.PM.Collection).%ExistsId(tId) $$$ThrowStatus($$$ERROR($$$GeneralError,"Collection not found"))
	quit tId
}

ClassMethod Rows(pSQL, pArgs...) As %DynamicArray [ CodeMode = expression ]
{
##class(SysPerf.UI.Data).Rows(pSQL,pArgs...)
}

ClassMethod Asystems() As %DynamicObject
{
	quit {"systems":(..Rows("SELECT %EXACT(SystemName) sys, COUNT(*) n, MIN(CollectedTS) firstTS, MAX(CollectedTS) lastTS FROM SysPerf_PM.Collection WHERE Status='OK' GROUP BY %EXACT(SystemName) ORDER BY 1"))}
}

ClassMethod Acollections() As %DynamicObject
{
	set tSys=..P("sys"),tFrom=..P("from"),tTo=..P("to")
	set:tFrom'?4N1"-"2N1"-"2N tFrom="1900-01-01" set:tTo'?4N1"-"2N1"-"2N tTo="9999-12-30"
	set tTo=$zd($zdh(tTo,3)+1,3)
	set tSQL="SELECT ID id,SystemName sys,Config,Host,CollectedTS ts,DurationSec dur,TotalGloRefs,TotalPhyBlkRd,TotalJrnEntry,TotalRtnLines,ProcessCount,HealthScore health,CriticalCount crit,WarningCount warn,InfoCount info,Origin,FileName,LoadedTS FROM SysPerf_PM.Collection WHERE Status='OK' AND CollectedTS>=? AND CollectedTS<?"
	if tSys'="" quit {"rows":(..Rows(tSQL_" AND SystemName=? ORDER BY CollectedTS DESC",tFrom,tTo,tSys))}
	quit {"rows":(..Rows(tSQL_" ORDER BY CollectedTS DESC",tFrom,tTo))}
}

ClassMethod Acoll() As %DynamicObject
{
	set tId=..Id(),c=##class(SysPerf.PM.Collection).%OpenId(tId,0),o={"id":(+tId)}
	for p="CollKey","Config","Host","SystemName","CollectedTS","TableList","Origin","SourceFile","FileName","FileHash","LoadedTS","LoadedBy","StatusText","AnalyzedTS","Notes" do o.%Set(p,$property(c,p))
	for p="DurationSec","TotalGloRefs","TotalGloSets","TotalGloKills","TotalPhyBlkRd","TotalPhyBlkWrt","TotalLogBlkRd","TotalJrnEntry","TotalBlkAlloc","TotalRtnLines","TotalRtnLoads","ProcessCount","GlobalCount","RoutineCount","FileSize","LoadSeconds","HealthScore","CriticalCount","WarningCount","InfoCount" { set v=$property(c,p) if v="" { do o.%Set(p,"","null") } else { do o.%Set(p,+v,"number") } }
	set o.hasRaw=(c.RawHtml.Size>0)
	set tSys=c.SystemName,tTS=c.CollectedTS
	&sql(SELECT TOP 1 ID INTO :p FROM SysPerf_PM.Collection WHERE SystemName=:tSys AND CollectedTS<:tTS AND Status='OK' ORDER BY CollectedTS DESC)
	set o.prevId=$s(SQLCODE=0:+p,1:"")
	&sql(SELECT TOP 1 ID INTO :n FROM SysPerf_PM.Collection WHERE SystemName=:tSys AND CollectedTS>:tTS AND Status='OK' ORDER BY CollectedTS)
	set o.nextId=$s(SQLCODE=0:+n,1:"")
	quit o
}

ClassMethod Afindings() As %DynamicObject
{
	set tId=..Id(),tArr=[]
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Severity,Category,Code,Subject,Title,Detail,Recommendation,Evidence,MetricValue,Threshold,DrillTab,Acknowledged,AckBy,AckTS,AckNote FROM SysPerf_PM.Finding WHERE Coll=? ORDER BY SevRank DESC, Rank",tId)
	while tRS.%Next() {
		set o={"id":(+tRS.ID),"sev":(tRS.Severity),"cat":(tRS.Category),"code":(tRS.Code),"subject":(tRS.Subject),"title":(tRS.Title),"detail":(tRS.Detail),"rec":(tRS.Recommendation),"evidence":(tRS.Evidence),"thr":(tRS.Threshold),"drill":(tRS.DrillTab),"ack":(+tRS.Acknowledged),"ackBy":(tRS.AckBy),"ackTS":(tRS.AckTS),"ackNote":(tRS.AckNote)}
		if tRS.MetricValue'="" { do o.%Set("value",+tRS.MetricValue,"number") } else { do o.%Set("value","","null") }
		do tArr.%Push(o)
	}
	quit {"findings":(tArr)}
}

/// t = globals | rglobals | routines | procs | proclist | generic
ClassMethod Atable() As %DynamicObject
{
	set tId=..Id(),t=..P("t")
	if t="globals" quit {"rows":(..Rows("SELECT Rank,GlobalName,IsOther,TotRefs,PctRefs,RefsPerSec,GloSet,GloKill,UpdPerSec,BlkAlloc,JrnEntry,JrnPerSec,PhyBlkRd,PhyRdPerSec,PhyBlkWrt,LogBlkRd,MissPct,DBName,Directory FROM SysPerf_PM.GlobalStat WHERE Coll=? ORDER BY Rank",tId))}
	if t="rglobals" quit {"rows":(..Rows("SELECT Rank,Routine,IsOther,IsSQL,ClassName,TotRefs,PctRefs,RefsPerSec,GloSet,GloKill,BlkAlloc,JrnEntry,PhyBlkRd,PhyRdPerSec,PhyBlkWrt,LogBlkRd,MissPct,DBName,Directory FROM SysPerf_PM.RoutineGlobal WHERE Coll=? ORDER BY Rank",tId))}
	if t="routines" quit {"rows":(..Rows("SELECT Rank,Routine,IsOther,IsSQL,ClassName,RtnLines,PctLines,LinesPerSec,RtnLoads,LoadsPerSec,RtnFetch,LinePerLoad,DBName,Directory FROM SysPerf_PM.RoutineStat WHERE Coll=? ORDER BY Rank",tId))}
	if t="procs" quit {"rows":(..Rows("SELECT PID,IsOther,UserName,Namespace,Routine,State,ClientName,ExeName,ClientIP,OSUserName,TotRefs,PctRefs,RefsPerSec,GloSet,GloKill,JrnEntry,PhyBlkRd,PhyBlkWrt,LogBlkRd,RtnLines,PctLines,LinesPerSec,RtnLoads,LinePerLoad,RankRefs,RankLines FROM SysPerf_PM.ProcessStat WHERE Coll=? ORDER BY TotRefs DESC",tId))}
	if t="proclist" quit {"rows":(..Rows("SELECT JobNo,PID,DisplayPID,UserName,Device,Namespace,Routine,Commands,Globals,State,ClientName,ExeName,ClientIP,OSUserName,CPUTime,PrvGblBlkCnt,CanBeExamined,CanBeSuspended,CanBeTerminated,CanReceiveBroadcast FROM SysPerf_PM.Process WHERE Coll=? ORDER BY JobNo",tId))}
	if t="generic" {
		set tArr=[],tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT TableName,RowNo,Header,Cells FROM SysPerf_PM.GenericRow WHERE Coll=? ORDER BY TableName,RowNo",tId)
		while tRS.%Next() { set h=[],c=[] for i=1:1:$ll(tRS.Header) { do h.%Push($lg(tRS.Header,i)) } for i=1:1:$ll(tRS.Cells) { do c.%Push($lg(tRS.Cells,i)) } do tArr.%Push({"table":(tRS.TableName),"row":(tRS.RowNo),"header":(h),"cells":(c)}) }
		quit {"rows":(tArr)}
	}
	quit {"error":"unknown table"}
}

/// Activity per database (from the per-global table)
ClassMethod Adbs() As %DynamicObject
{
	set tId=..Id()
	quit {"rows":(..Rows("SELECT %EXACT(Directory) Directory,MAX(DBName) DBName,COUNT(*) Globals,SUM(TotRefs) TotRefs,SUM(GloSet) GloSet,SUM(GloKill) GloKill,SUM(PhyBlkRd) PhyBlkRd,SUM(PhyBlkWrt) PhyBlkWrt,SUM(LogBlkRd) LogBlkRd,SUM(JrnEntry) JrnEntry,SUM(BlkAlloc) BlkAlloc FROM SysPerf_PM.GlobalStat WHERE Coll=? AND IsOther=0 GROUP BY %EXACT(Directory) ORDER BY 4 DESC",tId))}
}

/// Totals per collection over time for one system
ClassMethod Atrend() As %DynamicObject
{
	set tSys=..P("sys")
	quit {"rows":(..Rows("SELECT ID id,CollectedTS ts,DurationSec dur,TotalGloRefs/DurationSec refs,TotalPhyBlkRd/DurationSec phy,TotalJrnEntry/DurationSec jrn,TotalRtnLines/DurationSec lines,(TotalGloSets+TotalGloKills)/DurationSec upd,ProcessCount procs,HealthScore health FROM SysPerf_PM.Collection WHERE Status='OK' AND SystemName=? AND DurationSec>0 ORDER BY CollectedTS",tSys))}
}

/// Top globals (by metric) across collections of a system: m=RefsPerSec|PhyRdPerSec|JrnPerSec|UpdPerSec
ClassMethod Atopglobals() As %DynamicObject
{
	set tSys=..P("sys"),m=..P("m","RefsPerSec")
	set:'$lf($lb("RefsPerSec","PhyRdPerSec","JrnPerSec","UpdPerSec"),m) m="RefsPerSec"
	set tTop=..Rows("SELECT TOP 8 %EXACT(g.GlobalName) GlobalName,SUM(g."_m_") V FROM SysPerf_PM.GlobalStat g JOIN SysPerf_PM.Collection c ON c.ID=g.Coll WHERE c.SystemName=? AND c.Status='OK' AND g.IsOther=0 GROUP BY %EXACT(g.GlobalName) ORDER BY 2 DESC",tSys)
	set tSeries=[],it=tTop.%GetIterator()
	while it.%GetNext(.k,.row) {
		set tPts=[],tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT MIN(c.CollectedTS) T,SUM(g."_m_") V FROM SysPerf_PM.GlobalStat g JOIN SysPerf_PM.Collection c ON c.ID=g.Coll WHERE c.SystemName=? AND c.Status='OK' AND g.GlobalName=? GROUP BY c.ID ORDER BY 1",tSys,row.GlobalName)
		while tRS.%Next() { set p=[] do p.%Push(tRS.T) do p.%Push(+tRS.V,"number") do tPts.%Push(p) }
		do tSeries.%Push({"name":(row.GlobalName),"pts":(tPts)})
	}
	quit {"series":(tSeries),"metric":(m)}
}

ClassMethod Arequests() As %DynamicObject
{
	quit {"rows":(..Rows("SELECT TOP 50 ID id,DurationSec,Status,Message,RequestedBy,RequestedTS,StartTS,EndTS,CollectionId,Origin FROM SysPerf_PM.CollectRequest ORDER BY ID DESC"))}
}

ClassMethod Arequest() As %DynamicObject
{
	set tId=..P("id")
	quit:tId'?1.N {"error":"bad id"}
	quit {"rows":(..Rows("SELECT ID id,DurationSec,Status,Message,RequestedBy,RequestedTS,StartTS,EndTS,CollectionId,Origin FROM SysPerf_PM.CollectRequest WHERE ID=?",tId))}
}

/// Original HTML report (stored stream), served under a sandbox CSP
ClassMethod Raw()
{
	set tId=..P("id")
	if (tId'?1.N)||'##class(SysPerf.PM.Collection).%ExistsId(tId) write "not found" quit
	set c=##class(SysPerf.PM.Collection).%OpenId(tId,0)
	do c.RawHtml.Rewind()
	while 'c.RawHtml.AtEnd { write c.RawHtml.Read(32000) }
}

}
