/// JSON provider for the live (current instance) views of the portal: system dashboard counters,
/// processes, locks, databases, journals, mirror, tasks, logs, license and interoperability.
/// Read-only. Code that runs in %SYS or another namespace only calls system classes.
Class SysPerf.UI.LiveData Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

Parameter SECURITYRESOURCE = "SysPerf_Viewer";

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
		set tA=$g(%request.Data("action",1))
		if '$lf($lb("sysinfo","counters","processes","process","locks","databases","journals","mirror","tasks","log","license","interop","queues","events","items","messages","portal","apperrors","apperror"),tA) {
			set tOut={"error":"unknown action"}
		} else {
			set tOut=$classmethod($classname(),"A"_tA)
		}
	} catch ex {
		set tOut={"error":(ex.DisplayString())}
	}
	do tOut.%ToJSON()
	quit $$$OK
}

ClassMethod P(pName As %String, pDefault As %String = "") As %String [ CodeMode = expression ]
{
$g(%request.Data(pName,1),pDefault)
}

/// Run a query in namespace pNS and return rows as a %DynamicArray (max pMax rows).
/// Only system classes are used after the namespace switch.
ClassMethod SQLIn(pNS As %String, pSQL As %String, pMax As %Integer = 5000, pArgs...) As %DynamicArray
{
	new $namespace
	set tArr=[]
	set $namespace=pNS
	set tStmt=##class(%SQL.Statement).%New()
	set tSC=tStmt.%Prepare(pSQL)
	if $$$ISERR(tSC) throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	set tRS=tStmt.%Execute(pArgs...)
	if tRS.%SQLCODE<0 throw ##class(%Exception.SQL).CreateFromSQLCODE(tRS.%SQLCODE,tRS.%Message)
	set tMeta=tRS.%GetMetadata(),tN=tMeta.columns.Count()
	for i=1:1:tN set tCol(i)=tMeta.columns.GetAt(i).colName,tNum(i)=$lf($lb(2,3,4,5,6,7,8,-5,-6,-7),tMeta.columns.GetAt(i).ODBCType)
	set n=0
	while tRS.%Next() {
		set n=n+1 quit:n>pMax
		set o={}
		for i=1:1:tN {
			set v=tRS.%GetData(i)
			if tNum(i),v'="",$isvalidnum(v) { do o.%Set(tCol(i),+v,"number") } else { do o.%Set(tCol(i),v) }
		}
		do tArr.%Push(o)
	}
	quit tArr
}

/// Comma list of the properties of pClass that exist in this IRIS version (columns differ between versions)
ClassMethod Cols(pClass As %String, pList As %String) As %String
{
	set tOut=""
	for i=1:1:$l(pList,",") {
		set p=$p(pList,",",i)
		set:##class(%Dictionary.CompiledProperty).%ExistsId(pClass_"||"_p) tOut=tOut_$s(tOut="":"",1:",")_p
	}
	quit tOut
}

// ================================================================ system

/// Instance identity + dashboard status indicators
ClassMethod Asysinfo() As %DynamicObject
{
	new $namespace
	set o={}
	set o.instance=##class(%SYS.System).GetInstanceName(),o.host=$system.INetInfo.LocalHostName(),o.version=$zv,o.versionNumber=$system.Version.GetNumber()
	set o.installDir=$system.Util.InstallDirectory(),o.mgrDir=$zu(12),o.os=$system.Version.GetOS(),o.namespace=$namespace,o.user=$username
	set $namespace="%SYS"
	try {
		set d=##class(SYS.Stats.Dashboard).Sample()
		for p="SystemUpTime","LastBackup","DatabaseSpace","JournalStatus","JournalSpace","JournalEntries","LockTable","WriteDaemon","ECPAppServer","ECPDataServer","ShadowServer","ShadowSource","LicenseType","ApplicationErrors","SeriousAlerts","CSPSessions","Processes","LicenseCurrent","LicenseLimit","LicenseCurrentPct","LicenseHigh","LicenseHighPct","CacheEfficiency" { do o.%Set(p,$property(d,p)) }
	} catch ex { set o.dashboardError=ex.DisplayString() }
	try {
		set o.journalState=##class(%SYS.Journal.System).GetStateString(),o.journalFile=##class(%SYS.Journal.System).GetCurrentFileName()
		set o.mirrorMember=+$SYSTEM.Mirror.IsMember()
		if o.mirrorMember set o.mirrorName=$SYSTEM.Mirror.MirrorName(),o.mirrorStatus=$SYSTEM.Mirror.GetStatus(),o.mirrorType=$SYSTEM.Mirror.GetMemberType()
	} catch ex { set o.journalError=ex.DisplayString() }
	try {
		set o.licenseCustomer=$system.License.KeyCustomerName(),o.licenseExpires=$s($system.License.KeyExpirationDate()?1.N:$zd($system.License.KeyExpirationDate(),3),1:$system.License.KeyExpirationDate())
		set o.licenseLimit=$system.License.GetUserLimit(),o.licenseUsed=$system.License.LUConsumed(),o.licenseMax=$system.License.LUMaxConsumed()
	} catch ex {}
	quit o
}

/// Cumulative counters; the browser computes rates from two samples
ClassMethod Acounters() As %DynamicObject
{
	new $namespace
	set o={"ms":($zh*1000\1),"ts":($zdt($h,3))}
	set $namespace="%SYS"
	set g=##class(SYS.Stats.Global).Sample()
	set o.gloRefs=g.RefLocal+g.RefRemote+g.RefPrivate,o.gloRefsRemote=g.RefRemote,o.gloUpdates=g.RefUpdateLocal+g.RefUpdateRemote+g.RefUpdatePrivate
	set o.logicalReads=g.LogicalBlocks,o.physReads=g.PhysBlockReads,o.physWrites=g.PhysBlockWrites
	set o.jrnEntries=g.JrnEntries,o.jrnBlocks=g.JrnBlocks,o.wdQueue=g.WDQueueSize,o.wijWrites=g.WIJWrites
	set r=##class(SYS.Stats.Routine).Sample()
	set o.rtnLines=r.RtnLines,o.rtnCalls=r.RtnCallsLocal+r.RtnCallsRemote,o.rtnFetch=r.RtnFetchLocal+r.RtnFetchRemote,o.rtnNotCached=r.RtnNotCached
	set d=##class(SYS.Stats.Dashboard).Sample()
	set o.processes=d.Processes,o.cspSessions=d.CSPSessions,o.licenseCurrent=d.LicenseCurrent,o.licenseLimit=d.LicenseLimit
	quit o
}

ClassMethod Aprocesses() As %DynamicObject
{
	// only columns that exist in this IRIS version (e.g. StartTimeUTC is not in older releases)
	set tCols=..Cols("%SYS.ProcessQuery","Pid,JobNumber,NameSpace,Routine,UserName,State,JobType,ClientIPAddress,ClientExecutableName,ClientNodeName,CurrentDevice,GlobalReferences,GlobalUpdates,GlobalDiskReads,LinesExecuted,CommandsExecuted,MemoryUsed,MemoryAllocated,CPUTime,InTransaction,Priority,LastGlobalReference,CSPSessionID,OSUserName,StartTimeUTC")
	set tRows=..SQLIn("%SYS","SELECT "_tCols_" FROM %SYS.ProcessQuery"_$s(tCols["GlobalReferences":" ORDER BY GlobalReferences DESC",1:""),10000)
	quit {"rows":(tRows)}
}

ClassMethod Aprocess() As %DynamicObject
{
	set tPid=..P("pid")
	quit:tPid'?1.N {"error":"bad pid"}
	set tRows=..SQLIn("%SYS","SELECT * FROM %SYS.ProcessQuery WHERE Pid=?",1,tPid)
	quit {"rows":(tRows)}
}

ClassMethod Alocks() As %DynamicObject
{
	set tRows=..SQLIn("%SYS","SELECT * FROM %SYS.LockQuery_List()",20000)
	quit {"rows":(tRows)}
}

ClassMethod Adatabases() As %DynamicObject
{
	new $namespace
	set tRows=..SQLIn("%SYS","SELECT * FROM SYS.Database_FreeSpace('*')",5000)
	// journal state / mount info per database
	set $namespace="%SYS"
	set it=tRows.%GetIterator()
	while it.%GetNext(.k,.row) {
		try {
			set db=##class(SYS.Database).%OpenId(row.Directory,,.tSC)
			if $isobject(db) { set row.Journal=db.GlobalJournalState,row.Mounted=db.Mounted,row.BlockSize=db.BlockSize,row.Resource=db.ResourceName,row.Mirrored=db.Mirrored,row.Encrypted=db.EncryptedDB }
		} catch {}
	}
	quit {"rows":(tRows)}
}

ClassMethod Ajournals() As %DynamicObject
{
	new $namespace
	set o={}
	set $namespace="%SYS"
	set o.state=##class(%SYS.Journal.System).GetStateString(),o.current=##class(%SYS.Journal.System).GetCurrentFileName()
	set o.primary=##class(%SYS.Journal.System).GetPrimaryDirectory(),o.alternate=##class(%SYS.Journal.System).GetAlternateDirectory()
	try { if $$$ISOK(##class(%File).GetDirectorySpace(o.primary,.tFree,.tTot,1)) set o.primaryFreeMB=+tFree,o.primaryTotalMB=+tTot } catch {}
	try { if $$$ISOK(##class(%File).GetDirectorySpace(o.alternate,.tFree,.tTot,1)) set o.alternateFreeMB=+tFree,o.alternateTotalMB=+tTot } catch {}
	set o.frozen=+##class(%SYS.Journal.System).IsFrozen(),o.paused=+##class(%SYS.Journal.System).IsPaused(),o.ioError=+##class(%SYS.Journal.System).IsGettingIOError()
	set tStmt=##class(%SQL.Statement).%New()
	set tSC=tStmt.%Prepare("SELECT TOP 200 * FROM %SYS_Journal.File_ByTimeReverseOrder()")
	set tFiles=[]
	if $$$ISOK(tSC) {
		set tRS=tStmt.%Execute(),tMeta=tRS.%GetMetadata(),tN=tMeta.columns.Count()
		while tRS.%Next() { set f={} for i=1:1:tN { do f.%Set(tMeta.columns.GetAt(i).colName,tRS.%GetData(i)) } do tFiles.%Push(f) }
	}
	set o.files=tFiles
	quit o
}

ClassMethod Amirror() As %DynamicObject
{
	new $namespace
	set o={}
	set $namespace="%SYS"
	set o.member=+$SYSTEM.Mirror.IsMember()
	if o.member {
		set o.name=$SYSTEM.Mirror.MirrorName(),o.status=$SYSTEM.Mirror.GetStatus(),o.type=$SYSTEM.Mirror.GetMemberType()
		set o.isPrimary=+$SYSTEM.Mirror.IsPrimary(),o.isBackup=+$SYSTEM.Mirror.IsBackup(),o.isAsync=+$SYSTEM.Mirror.IsAsyncMember()
		try { set o.memberStatus=$SYSTEM.Mirror.GetMemberStatus() } catch {}
		set tMembers=[]
		try {
			set tRS=##class(%ResultSet).%New("SYS.Mirror:MemberStatusList")
			if $$$ISOK(tRS.Execute(o.name)) { while tRS.Next() { set m={} for i=1:1:tRS.GetColumnCount() { do m.%Set(tRS.GetColumnName(i),tRS.GetData(i)) } do tMembers.%Push(m) } }
		} catch {}
		set o.members=tMembers
	}
	quit o
}

ClassMethod Atasks() As %DynamicObject
{
	set o={}
	set o.tasks=..SQLIn("%SYS","SELECT ID,"_..Cols("%SYS.Task","Name,NameSpace,TaskClass,Suspended,DisplayRun,DisplayInterval,DisplayStarted,DisplayFinished,DisplayNextScheduled,DisplayStatus,DisplayErrorDate,Error,RunAsUser,Description")_" FROM %SYS.Task ORDER BY Name",2000)
	set o.history=..SQLIn("%SYS","SELECT TOP 300 ID,"_..Cols("%SYS.Task.History","Name,NameSpace,DisplayStarted,DisplayFinished,DisplayStatus,Status,Error,Username")_" FROM %SYS_Task.History ORDER BY ID DESC",300)
	quit o
}

/// Tail of messages.log / alerts.log. f=messages|alerts, lines=N, min=severity 0-3
ClassMethod Alog() As %DynamicObject
{
	set tWhich=..P("f","messages"),tMax=+..P("lines",1000),tMin=+..P("min",0)
	set:tMax<1 tMax=1000 set:tMax>20000 tMax=20000
	set tFile=$zu(12)_$s(tWhich="alerts":"alerts.log",1:"messages.log")
	set o={"file":(tFile)},tArr=[]
	if '##class(%File).Exists(tFile) set o.lines=tArr quit o
	set tStream=##class(%Stream.FileCharacter).%New()
	do tStream.LinkToFile(tFile)
	set tSize=tStream.Size,tBytes=tMax*220
	if tSize>tBytes do tStream.MoveTo(tSize-tBytes) do tStream.ReadLine()
	kill l set n=0
	while 'tStream.AtEnd { set x=tStream.ReadLine() continue:x=""  set n=n+1,l(n)=x }
	set tFrom=$s(n>tMax:n-tMax+1,1:1)
	for i=n:-1:tFrom {
		set x=l(i)
		// 09/26/26-15:23:12:123 (1234) 1 [Utility.Event] text
		set tSev=$p($p(x,") ",2)," ",1)
		set tSev=$s(tSev?1N:+tSev,1:0)
		continue:tSev<tMin
		do tArr.%Push({"ts":($p(x," ",1)),"pid":($p($p(x,"(",2),")",1)),"sev":(tSev),"src":($p($p(x,"[",2),"]",1)),"text":($s(x["] ":$p(x,"] ",2,*),1:x))})
	}
	set o.lines=tArr,o.size=tSize
	quit o
}

ClassMethod Alicense() As %DynamicObject
{
	new $namespace
	set o={}
	set $namespace="%SYS"
	try {
		set o.customer=$system.License.KeyCustomerName(),o.order=$system.License.KeyOrderNumber(),o.product=$system.License.KeyProduct(),o.type=$system.License.KeyLicenseType()
		set o.expires=$system.License.KeyExpirationDate() if o.expires?1.N set o.expires=$zd(o.expires,3)
		set o.units=$system.License.KeyLicenseUnits(),o.cores=$system.License.KeyCoresLicensed(),o.limit=$system.License.GetUserLimit()
		set o.consumed=$system.License.LUConsumed(),o.available=$system.License.LUAvailable(),o.maxConsumed=$system.License.LUMaxConsumed(),o.minAvailable=$system.License.LUMinAvailable()
		set o.cspUsers=$system.License.CSPUsers(),o.maxCspUsers=$system.License.MaxCSPUsers()
	} catch ex { set o.error=ex.DisplayString() }
	set tUsers=[]
	try {
		set tRS=##class(%ResultSet).%New("%SYSTEM.License:UserListAll")
		if $$$ISOK(tRS.Execute()) { while tRS.Next() { continue:tRS.GetData(1)="free"  set u={} for i=1:1:tRS.GetColumnCount() { do u.%Set(tRS.GetColumnName(i),tRS.GetData(i)) } do tUsers.%Push(u) } }
	} catch {}
	set o.users=tUsers
	quit o
}

// ================================================================ interoperability

/// Interoperability namespaces the user can read
ClassMethod InteropNamespaces(Output pList)
{
	kill pList
	do ##class(%SYS.Namespace).ListAll(.tAll)
	set ns=""
	for {
		set ns=$o(tAll(ns)) quit:ns=""
		continue:(ns="%SYS")||(ns="%ALL")
		continue:$e(ns,1,2)="^^"
		try { continue:'##class(%Library.EnsembleMgr).IsEnsembleNamespace(ns) } catch { continue }
		set pList(ns)=""
	}
}

/// Production status per namespace + queue / error totals
ClassMethod Ainterop() As %DynamicObject
{
	do ..InteropNamespaces(.tNS)
	set tArr=[],ns=""
	for {
		set ns=$o(tNS(ns)) quit:ns=""
		set o={"namespace":(ns)}
		try { do ..ProdStatus(ns,o) } catch ex { set o.error=ex.DisplayString() }
		do tArr.%Push(o)
	}
	quit {"namespaces":(tArr)}
}

ClassMethod ProdStatus(pNS As %String, o As %DynamicObject)
{
	new $namespace
	set $namespace=pNS
	set tSC=##class(Ens.Director).GetProductionStatus(.tName,.tState)
	set o.production=$g(tName),o.state=$g(tState),o.stateText=$case($g(tState),1:"Running",2:"Stopped",3:"Suspended",4:"Troubled",5:"Network stopped",:"Unknown")
	set tQ=0,tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT * FROM Ens.Queue_Enumerate()")
	while tRS.%Next() { set tQ=tQ+tRS.%GetData(2) }
	set o.queued=tQ
	// Ens timestamps are stored in UTC
	set tCut=$system.SQL.Functions.DATEADD("hh",-24,$zdt($ztimestamp,3))
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Type,COUNT(*) FROM Ens_Util.Log WHERE TimeLogged>=? AND Type IN (2,3,6) GROUP BY Type",tCut)
	set o.errors24h=0,o.warnings24h=0,o.alerts24h=0
	while tRS.%Next() { set t=tRS.%GetData(1),c=tRS.%GetData(2) set:t=2 o.errors24h=c set:t=3 o.warnings24h=c set:t=6 o.alerts24h=c }
	// message headers created in the last hour (walk newest IDs, capped)
	set tN=0,tErr=0,id="",tCap=200000,tScan=0,tCutoff=$system.SQL.Functions.DATEADD("hh",-1,$zdt($ztimestamp,3))
	for {
		set id=$o(^Ens.MessageHeaderD(id),-1) quit:id=""
		set tScan=tScan+1 quit:tScan>tCap
		set tTC=##class(Ens.MessageHeader).TimeCreatedGetStored(id)
		quit:tTC<tCutoff
		set tN=tN+1 set:##class(Ens.MessageHeader).IsErrorGetStored(id) tErr=tErr+1
	}
	set o.messagesLastHour=tN,o.errorMessagesLastHour=tErr,o.messagesCapped=(tScan>tCap)
}

/// Queue counts. ns= (empty = all interop namespaces)
ClassMethod Aqueues() As %DynamicObject
{
	set tOne=..P("ns")
	do ..InteropNamespaces(.tNS)
	set tArr=[],ns=""
	for {
		set ns=$o(tNS(ns)) quit:ns=""
		continue:(tOne'="")&&(ns'=tOne)
		try {
			set tRows=..SQLIn(ns,"SELECT * FROM Ens.Queue_Enumerate()",5000)
			set it=tRows.%GetIterator() while it.%GetNext(.k,.r) { set r.Namespace=ns do tArr.%Push(r) }
		} catch ex { do tArr.%Push({"Namespace":(ns),"Name":"(error)","error":(ex.DisplayString())}) }
	}
	quit {"rows":(tArr)}
}

/// Event log (errors / warnings / alerts). ns=, types=2,3,6, hours=24, max=500
ClassMethod Aevents() As %DynamicObject
{
	set tOne=..P("ns"),tTypes=..P("types","2,3,6"),tHours=+..P("hours",24),tMax=+..P("max",500)
	set:tMax>5000 tMax=5000 set:tHours<1 tHours=24
	set tIn="" for i=1:1:$l(tTypes,",") { set t=$p(tTypes,",",i) set:t?1N tIn=tIn_$s(tIn="":"",1:",")_t }
	set:tIn="" tIn="2,3,6"
	set tCut=$system.SQL.Functions.DATEADD("hh",-tHours,$zdt($ztimestamp,3))
	do ..InteropNamespaces(.tNS)
	set tArr=[],ns=""
	for {
		set ns=$o(tNS(ns)) quit:ns=""
		continue:(tOne'="")&&(ns'=tOne)
		try {
			set tRows=..SQLIn(ns,"SELECT TOP "_tMax_" ID,TimeLogged,Type,ConfigName,SourceClass,SourceMethod,SessionId,Text FROM Ens_Util.Log WHERE TimeLogged>=? AND Type IN ("_tIn_") ORDER BY ID DESC",tMax,tCut)
			set it=tRows.%GetIterator() while it.%GetNext(.k,.r) { set r.Namespace=ns set r.TypeText=$case(r.Type,1:"Assert",2:"Error",3:"Warning",4:"Info",5:"Trace",6:"Alert",:r.Type) do tArr.%Push(r) }
		} catch ex { do tArr.%Push({"Namespace":(ns),"Text":("(cannot read: "_ex.DisplayString()_")")}) }
	}
	quit {"rows":(tArr)}
}

/// Production items of a namespace with queue counts and 24h error counts
ClassMethod Aitems() As %DynamicObject
{
	set ns=..P("ns")
	do ..InteropNamespaces(.tNS)
	quit:'$d(tNS(ns)) {"error":"not an interoperability namespace"}
	set o={} do ..ProdStatus(ns,o)
	set tItems=..SQLIn(ns,"SELECT i.Name,i.ClassName,i.Category,i.Enabled,i.PoolSize,i.Comment FROM Ens_Config.Item i WHERE i.Production->Name=? ORDER BY i.Name",2000,o.production)
	set tQ=..SQLIn(ns,"SELECT * FROM Ens.Queue_Enumerate()",5000)
	set tErr=..SQLIn(ns,"SELECT %EXACT(ConfigName) ConfigName,Type,COUNT(*) N,MAX(TimeLogged) LastTime FROM Ens_Util.Log WHERE TimeLogged>=? AND Type IN (2,3) GROUP BY %EXACT(ConfigName),Type",5000,$system.SQL.Functions.DATEADD("hh",-24,$zdt($ztimestamp,3)))
	quit {"production":(o),"items":(tItems),"queues":(tQ),"errors":(tErr)}
}

/// Portal home summary (small, fast)
ClassMethod Aportal() As %DynamicObject
{
	set o={}
	set o.sys=..Asysinfo()
	&sql(SELECT TOP 1 ID,SystemName,StartTS,HealthScore,CriticalCount,WarningCount INTO :id,:sys,:ts,:hs,:c,:w FROM SysPerf_Data.Run WHERE Status='OK' ORDER BY StartTS DESC)
	if SQLCODE=0 set o.lastRun={"id":(id),"sys":(sys),"start":(ts),"health":(hs),"crit":(c),"warn":(w)}
	&sql(SELECT TOP 1 ID,SystemName,CollectedTS,HealthScore,CriticalCount,WarningCount INTO :id,:sys,:ts,:hs,:c,:w FROM SysPerf_PM.Collection WHERE Status='OK' ORDER BY CollectedTS DESC)
	if SQLCODE=0 set o.lastPM={"id":(id),"sys":(sys),"ts":(ts),"health":(hs),"crit":(c),"warn":(w)}
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_Data.Run WHERE Status='OK')
	set o.runs=n
	&sql(SELECT COUNT(*) INTO :n FROM SysPerf_PM.Collection WHERE Status='OK')
	set o.collections=n
	quit o
}

// ================================================================ application error log (^ERRORS, SYS.ApplicationError)

/// Application errors of all namespaces. days=7 (0 = all), ns= (one namespace), max=3000
ClassMethod Aapperrors() As %DynamicObject
{
	new $namespace
	set tOne=..P("ns"),tDays=+..P("days",7),tMax=+..P("max",3000)
	set:tMax<1 tMax=3000 set:tMax>20000 tMax=20000
	set tCut=$s(tDays>0:+$h-tDays+1,1:0)
	set tRows=[],tDates=[],tNotes=[],n=0
	set $namespace="%SYS"
	set tNS=##class(%ResultSet).%New("SYS.ApplicationError:NamespaceList")
	do tNS.Execute()
	while tNS.Next() {
		set ns=tNS.GetData(1)
		continue:(tOne'="")&&(ns'=tOne)
		try {
			set tDL=##class(%ResultSet).%New("SYS.ApplicationError:DateList")
			do tDL.Execute(ns)
			kill tD
			while tDL.Next() { set d=tDL.GetData(1),h=$zdh(d,1,,,,,,,"") continue:h=""  continue:h<tCut  set tD(h)=$lb(d,tDL.GetData(2)) }
			set h=""
			for {
				set h=$o(tD(h),-1) quit:h=""
				set d=$lg(tD(h),1)
				do tDates.%Push({"namespace":(ns),"date":($zd(h,3)),"count":(+$lg(tD(h),2))})
				continue:n>=tMax
				set tEL=##class(%ResultSet).%New("SYS.ApplicationError:ErrorList")
				do tEL.Execute(ns,d)
				while tEL.Next() {
					set n=n+1 quit:n>tMax
					do tRows.%Push({"namespace":(ns),"date":($zd(h,3)),"dateKey":(d),"num":(+tEL.GetData(1)),"error":(tEL.GetData(2)),"time":(tEL.GetData(3)),"pid":(tEL.GetData(5)),"user":(tEL.GetData(6)),"line":(tEL.GetData(7))})
				}
			}
		} catch ex {
			do tNotes.%Push(ns_": "_$s(ex.Name["PROTECT":"no read access to this namespace's database (re-run SetupPortalRole)",1:ex.DisplayString()))
		}
	}
	quit {"rows":(tRows),"dates":(tDates),"notes":(tNotes),"capped":(n>tMax)}
}

/// Detail (stack, variables, objects, devices) of one application error. ns=, date=mm/dd/yyyy, num=
ClassMethod Aapperror() As %DynamicObject
{
	new $namespace
	set ns=..P("ns"),d=..P("date"),e=..P("num")
	quit:(ns="")||(d'?2N1"/"2N1"/"4N)||(e'?1.N) {"error":"bad parameters"}
	set $namespace="%SYS"
	set tRows=[]
	for t=0,1,2,3 {
		set tR=##class(%ResultSet).%New("SYS.ApplicationError:ErrorDetail")
		do tR.Execute(ns,d,e,t)
		set n=0
		while tR.Next() {
			set n=n+1 quit:n>5000
			do tRows.%Push({"section":($case(t,0:"Process state and variables",1:"Objects",2:"Stack",3:"Devices",:t)),"name":($s(t=0:tR.GetData(1),1:tR.GetData(2))),"value":($s(t=0:tR.GetData(2),1:tR.GetData(3))),"extra":($s(t=0:tR.GetData(3),1:tR.GetData(4)))})
		}
	}
	quit {"rows":(tRows)}
}

}
