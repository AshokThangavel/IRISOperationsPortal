/// One-call installer / upgrader for SysPerf.
/// Run from the target namespace after loading and compiling the classes:
/// <example>
///  zn "SYSPERF"
///  do ##class(SysPerf.Installer).Setup()
///  // or with options
///  do ##class(SysPerf.Installer).Setup("/csp/sysperf","D:\SysPerf\Inbox\",6,1)
/// </example>
/// Creates: resources SysPerf_Viewer / SysPerf_Admin, roles SysPerfViewer / SysPerfAdmin,
/// the web application (password authentication, requires SysPerf_Viewer), the daily Task Manager
/// job, default settings, inbox/archive/error folders and the analyzer thresholds.
/// Safe to re-run (idempotent). Requires %Admin_Secure / %Admin_Manage privileges.
Class SysPerf.Installer [ Abstract ]
{

/// pWebApp: web application path. pInbox: inbox folder ("" = &lt;install&gt;/SysPerf/Inbox).
/// pTaskHour: hour of day for the load task (-1 = do not create). pVerbose: write progress.
ClassMethod Setup(pWebApp As %String = "/csp/sysperf", pInbox As %String = "", pTaskHour As %Integer = 6, pVerbose As %Boolean = 1) As %Status
{
	set tSC=$$$OK,tNS=$namespace
	try {
		// --- settings, folders, thresholds (application namespace)
		set tSet=##class(SysPerf.Config.Settings).Get()
		if pInbox'="" {
			set tSet.InboxDir=pInbox
			set tBase=##class(%File).ParentDirectoryName(##class(%File).NormalizeDirectory(pInbox))
			set tSet.ArchiveDir=##class(%File).NormalizeDirectory(tBase_"Archive"),tSet.ErrorDir=##class(%File).NormalizeDirectory(tBase_"Error")
		}
		set tSC=tSet.%Save() quit:$$$ISERR(tSC)
		set tSC=tSet.EnsureDirs() quit:$$$ISERR(tSC)
		set tSC=##class(SysPerf.Config.Threshold).Seed() quit:$$$ISERR(tSC)
		write:pVerbose "Settings: inbox=",tSet.InboxDir," archive=",tSet.ArchiveDir," error=",tSet.ErrorDir,!
		set tDBRes=..DatabaseResource(tNS)
		// --- security + web app + task (%SYS)
		set tSC=..SetupPortalRole(pVerbose) quit:$$$ISERR(tSC)
		set tSC=..SetupSYS(tNS,pWebApp,tDBRes,pTaskHour,pVerbose) quit:$$$ISERR(tSC)
		// --- SQL privileges (the UI uses dynamic SQL, which checks table privileges)
		set tSC=..GrantSQL(pVerbose)
	} catch ex { set tSC=ex.AsStatus() }
	if pVerbose {
		if $$$ISERR(tSC) { write "SETUP FAILED: ",$system.Status.GetErrorText(tSC),! }
		else { write !,"SysPerf installed. Open: http(s)://<server>:<port>",pWebApp,"/SysPerf.UI.Portal.cls",!,"Grant users the role SysPerfViewer (read) or SysPerfAdmin (upload, settings, delete).",! }
	}
	quit tSC
}

/// SELECT for viewers, full DML for admins on the SysPerf schemas
ClassMethod GrantSQL(pVerbose As %Boolean = 1) As %Status
{
	set tSC=$$$OK
	for tStmt="GRANT SELECT ON SCHEMA SysPerf_Data TO SysPerfViewer","GRANT SELECT ON SCHEMA SysPerf_Config TO SysPerfViewer","GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA SysPerf_Data TO SysPerfAdmin","GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA SysPerf_Config TO SysPerfAdmin","GRANT SELECT ON SCHEMA SysPerf_PM TO SysPerfViewer","GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA SysPerf_PM TO SysPerfAdmin" {
		set tRS=##class(%SQL.Statement).%ExecDirect(,tStmt)
		if tRS.%SQLCODE<0 { set tSC=$$$ADDSC(tSC,$$$ERROR($$$SQLError,tRS.%SQLCODE,tRS.%Message)) }
		elseif pVerbose { write tStmt,! }
	}
	quit tSC
}

/// Resource protecting the default globals database of the namespace
ClassMethod DatabaseResource(pNS As %String) As %String
{
	new $namespace
	set tDir=##class(%SYS.Namespace).GetGlobalDest(pNS)
	set tDir=$p(tDir,"^",2)
	set $namespace="%SYS"
	set tDB=##class(SYS.Database).%OpenId(tDir,,.tSC)
	quit $s($isobject(tDB):tDB.ResourceName,1:"%DB_%DEFAULT")
}

ClassMethod SetupSYS(pNS As %String, pWebApp As %String, pDBRes As %String, pTaskHour As %Integer, pVerbose As %Boolean) As %Status
{
	new $namespace
	set $namespace="%SYS",tSC=$$$OK
	try {
		// resources
		for tRes="SysPerf_Viewer|SysPerf - view performance analytics","SysPerf_Admin|SysPerf - load reports, change settings, delete runs" {
			set tName=$p(tRes,"|",1)
			if '##class(Security.Resources).Exists(tName) {
				set tSC=##class(Security.Resources).Create(tName,$p(tRes,"|",2),"","") quit:$$$ISERR(tSC)
				write:pVerbose "Created resource ",tName,!
			}
		}
		quit:$$$ISERR(tSC)
		// roles (include the application database so users can read the data)
		set tDBPerm=pDBRes_":RW"
		for tRole="SysPerfViewer|SysPerf read-only users|SysPerf_Viewer:U,"_tDBPerm,"SysPerfAdmin|SysPerf administrators|SysPerf_Viewer:U,SysPerf_Admin:U,"_tDBPerm {
			set tName=$p(tRole,"|",1)
			if '##class(Security.Roles).Exists(tName) {
				set tSC=##class(Security.Roles).Create(tName,$p(tRole,"|",2),$p(tRole,"|",3)) quit:$$$ISERR(tSC)
				write:pVerbose "Created role ",tName,!
			} else {
				// merge: keep resources granted earlier (e.g. another SysPerf namespace)
				kill p set tSC=##class(Security.Roles).Get(tName,.p) quit:$$$ISERR(tSC)
				set tHave=","_$g(p("Resources"))_","
				set tNew=$g(p("Resources"))
				set tWant=$p(tRole,"|",3)
				for j=1:1:$l(tWant,",") { set tR=$p(tWant,",",j) if tHave'[(","_$p(tR,":",1)_":") set tNew=tNew_$s(tNew="":"",1:",")_tR }
				kill p set p("Resources")=tNew
				set tSC=##class(Security.Roles).Modify(tName,.p) quit:$$$ISERR(tSC)
			}
		}
		quit:$$$ISERR(tSC)
		// web application
		kill p
		set p("NameSpace")=pNS
		set p("Description")="SysPerf - IRIS performance analytics (^SystemPerformance)"
		set p("Enabled")=1
		set p("AutheEnabled")=32
		set p("Resource")="SysPerf_Viewer"
		set p("CSPZENEnabled")=1
		set p("InbndWebServicesEnabled")=0
		set p("IsNameSpaceDefault")=0
		set p("UseCookies")=2
		set p("Timeout")=3600
		// every user of the application also gets SysPerfPortal (read-only operations views, see SetupPortalRole)
		// SysPerfAdmin users additionally get SysPerfCollector (run PERFMON timed collections)
		set p("MatchRoles")=":"_pDBRes_":SysPerfPortal,SysPerfAdmin:SysPerfCollector"
		set p("ServeFiles")=0
		if ##class(Security.Applications).Exists(pWebApp) {
			set tSC=##class(Security.Applications).Modify(pWebApp,.p)
			write:pVerbose "Updated web application ",pWebApp,!
		} else {
			set tSC=##class(Security.Applications).Create(pWebApp,.p)
			write:pVerbose "Created web application ",pWebApp,!
		}
		quit:$$$ISERR(tSC)
		// task
		if pTaskHour>=0 {
			set tId=""
			&sql(SELECT ID INTO :tId FROM %SYS.Task WHERE TaskClass='SysPerf.Task.LoadInbox' AND NameSpace=:pNS)
			if SQLCODE'=0 {
				set tTask=##class(%SYS.Task).%New()
				set tTask.Name="SysPerf load reports ("_pNS_")"
				set tTask.Description="Loads ^SystemPerformance HTML reports from the SysPerf inbox, archives them and purges old runs"
				set tTask.NameSpace=pNS
				set tTask.TaskClass="SysPerf.Task.LoadInbox"
				set tTask.RunAsUser="_SYSTEM"
				set tTask.TimePeriod=0
				set tTask.TimePeriodEvery=1
				set tTask.DailyFrequency=0
				set tTask.DailyStartTime=pTaskHour*3600
				set tTask.StartDate=+$h+($p($h,",",2)>=(pTaskHour*3600))
				set tSC=tTask.%Save() quit:$$$ISERR(tSC)
				write:pVerbose "Created daily task '",tTask.Name,"' at ",pTaskHour,":00 (run as _SYSTEM - change in Task Manager if required)",!
			} else {
				write:pVerbose "Task already exists (ID ",tId,")",!
			}
			// PERFMON collection task: created SUSPENDED (weekdays 10:00, 5 minutes) - resume it in Task Manager when wanted
			set tId=""
			&sql(SELECT ID INTO :tId FROM %SYS.Task WHERE TaskClass='SysPerf.Task.PerfmonCollect' AND NameSpace=:pNS)
			if SQLCODE'=0 {
				set tTask=##class(%SYS.Task).%New()
				set tTask.Name="SysPerf PERFMON collection ("_pNS_")"
				set tTask.Description="Runs a PERFMON timed collection and loads it into SysPerf (created suspended)"
				set tTask.NameSpace=pNS
				set tTask.TaskClass="SysPerf.Task.PerfmonCollect"
				set tTask.Settings=$lb("Seconds",300)
				set tTask.RunAsUser="_SYSTEM"
				set tTask.TimePeriod=1,tTask.TimePeriodEvery=1,tTask.TimePeriodDay="23456"
				set tTask.DailyFrequency=0,tTask.DailyStartTime=10*3600
				set tTask.StartDate=+$h+1
				set tTask.Suspended=1
				set tSC=tTask.%Save() quit:$$$ISERR(tSC)
				write:pVerbose "Created SUSPENDED task '",tTask.Name,"' (weekdays 10:00, 300 s) - resume it in Task Manager to collect regularly",!
			}
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Create a dedicated namespace + database for SysPerf (run from %SYS or any namespace).
/// <example>do ##class(SysPerf.Installer).CreateNamespace("SYSPERF","D:\IRISDB\sysperf\")</example>
ClassMethod CreateNamespace(pNS As %String = "SYSPERF", pDir As %String = "") As %Status
{
	new $namespace
	set $namespace="%SYS",tSC=$$$OK
	try {
		if pDir="" set pDir=##class(%File).NormalizeDirectory($zu(12)_$zcvt(pNS,"L"))
		set pDir=##class(%File).NormalizeDirectory(pDir)
		set tRes="%DB_"_$zcvt(pNS,"U")
		if '##class(Security.Resources).Exists(tRes) set tSC=##class(Security.Resources).Create(tRes,"SysPerf database","","") quit:$$$ISERR(tSC)
		if '##class(%File).DirectoryExists(pDir) do ##class(%File).CreateDirectoryChain(pDir)
		if '##class(SYS.Database).%ExistsId(pDir) {
			set tDB=##class(SYS.Database).%New()
			set tDB.Directory=pDir,tDB.ResourceName=tRes
			set tSC=tDB.%Save() quit:$$$ISERR(tSC)
		}
		if '##class(Config.Databases).Exists(pNS) {
			kill p set p("Directory")=pDir
			set tSC=##class(Config.Databases).Create(pNS,.p) quit:$$$ISERR(tSC)
		}
		if '##class(Config.Namespaces).Exists(pNS) {
			kill p set p("Globals")=pNS,p("Routines")=pNS
			set tSC=##class(Config.Namespaces).Create(pNS,.p) quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Remove web application, task and roles (data is kept). Run from the application namespace.
ClassMethod Uninstall(pWebApp As %String = "/csp/sysperf") As %Status
{
	set tNS=$namespace
	new $namespace
	set $namespace="%SYS",tSC=$$$OK
	if ##class(Security.Applications).Exists(pWebApp) set tSC=$$$ADDSC(tSC,##class(Security.Applications).Delete(pWebApp))
	&sql(DECLARE C1 CURSOR FOR SELECT ID INTO :tId FROM %SYS.Task WHERE TaskClass IN ('SysPerf.Task.LoadInbox','SysPerf.Task.PerfmonCollect') AND NameSpace=:tNS)
	&sql(OPEN C1)
	for { &sql(FETCH C1) quit:SQLCODE  do ##class(%SYS.Task).%DeleteId(tId) }
	&sql(CLOSE C1)
	for tRole="SysPerfViewer","SysPerfAdmin","SysPerfPortal","SysPerfCollector" if ##class(Security.Roles).Exists(tRole) set tSC=$$$ADDSC(tSC,##class(Security.Roles).Delete(tRole))
	quit tSC
}

/// Role SysPerfPortal: what the portal's operations and interoperability views need.
/// It is added to every user of the web application (MatchRoles) and only used by the portal code.
///   %DB_IRISSYS:R      read system classes / tables in %SYS (processes, locks, databases, tasks ...)
///   %Admin_Operate:U   system statistics, lock table, journal and mirror status, PERFMON
///   R on the globals and routine databases of every interoperability namespace (production status,
///   queues, event log), plus SQL SELECT/EXECUTE grants on the tables used.
/// Run again after creating new interoperability namespaces:  do ##class(SysPerf.Installer).SetupPortalRole()
ClassMethod SetupPortalRole(pVerbose As %Boolean = 1) As %Status
{
	set tSC=$$$OK
	try {
		do ##class(SysPerf.UI.LiveData).InteropNamespaces(.tNS)
		do ##class(%SYS.Namespace).ListAll(.tAll)
		new $namespace
		set $namespace="%SYS"
		set tRes="%DB_IRISSYS:R,%Admin_Operate:U"
		set ns=""
		for {
			// every namespace: its globals database (application error log ^ERRORS);
			// interoperability namespaces also their routine database
			set ns=$o(tAll(ns)) quit:ns=""
			continue:$e(ns,1,2)="^^"
			kill p set tSC=##class(Config.Namespaces).Get(ns,.p) if $$$ISERR(tSC) set tSC=$$$OK continue
			for tDB=$g(p("Globals")),$s($d(tNS(ns)):$g(p("Routines")),1:"") {
				continue:tDB=""
				kill d set tSC=##class(Config.Databases).Get(tDB,.d) if $$$ISERR(tSC) set tSC=$$$OK continue
				set db=##class(SYS.Database).%OpenId(d("Directory"))
				continue:'$isobject(db)
				set r=db.ResourceName
				set:(r'="")&&((","_tRes_",")'[(","_r_":")) tRes=tRes_","_r_":R"
			}
			quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
		// HealthShare / IRIS for Health library databases
		for r="%DB_HSLIB","%DB_HSSYS","%DB_HSCUSTOM","%DB_HSAUDIT" {
			if ##class(Security.Resources).Exists(r),(","_tRes_",")'[(","_r_":") set tRes=tRes_","_r_":R"
		}
		if '##class(Security.Roles).Exists("SysPerfPortal") {
			set tSC=##class(Security.Roles).Create("SysPerfPortal","SysPerf portal: read-only operations and interoperability views",tRes) quit:$$$ISERR(tSC)
			write:pVerbose "Created role SysPerfPortal (",tRes,")",!
		} else {
			kill p set p("Resources")=tRes
			set tSC=##class(Security.Roles).Modify("SysPerfPortal",.p) quit:$$$ISERR(tSC)
			write:pVerbose "Updated role SysPerfPortal (",tRes,")",!
		}
		// PERFMON needs Read/Write on IRISSYS - only for administrators (added through MatchRoles SysPerfAdmin:SysPerfCollector)
		set tColl="%DB_IRISSYS:RW,%Admin_Operate:U"
		if '##class(Security.Roles).Exists("SysPerfCollector") {
			set tSC=##class(Security.Roles).Create("SysPerfCollector","SysPerf: run PERFMON timed collections",tColl) quit:$$$ISERR(tSC)
			write:pVerbose "Created role SysPerfCollector (",tColl,")",!
		} else { kill p set p("Resources")=tColl set tSC=##class(Security.Roles).Modify("SysPerfCollector",.p) quit:$$$ISERR(tSC) }
		// SQL privileges in %SYS
		for tStmt="GRANT SELECT ON %SYS.ProcessQuery TO SysPerfPortal","GRANT SELECT ON %SYS.Task TO SysPerfPortal","GRANT SELECT ON %SYS_Task.History TO SysPerfPortal",
			"GRANT EXECUTE ON SYS.Database_FreeSpace TO SysPerfPortal","GRANT EXECUTE ON %SYS.LockQuery_List TO SysPerfPortal","GRANT EXECUTE ON %SYS_Journal.File_ByTimeReverseOrder TO SysPerfPortal" {
			set tRS=##class(%SQL.Statement).%ExecDirect(,tStmt)
			write:pVerbose&&(tRS.%SQLCODE<0) "  %SYS: ",tStmt," -> ",tRS.%SQLCODE," ",tRS.%Message,!
		}
		// SQL privileges in the interoperability namespaces
		set ns=""
		for {
			set ns=$o(tNS(ns)) quit:ns=""
			set $namespace=ns
			for tStmt="GRANT SELECT ON SCHEMA Ens_Util TO SysPerfPortal","GRANT SELECT ON SCHEMA Ens_Config TO SysPerfPortal","GRANT SELECT ON Ens.MessageHeader TO SysPerfPortal","GRANT EXECUTE ON Ens.Queue_Enumerate TO SysPerfPortal" {
				set tRS=##class(%SQL.Statement).%ExecDirect(,tStmt)
				write:pVerbose&&(tRS.%SQLCODE<0) "  ",ns,": ",tStmt," -> ",tRS.%SQLCODE," ",tRS.%Message,!
			}
			set $namespace="%SYS"
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

}
