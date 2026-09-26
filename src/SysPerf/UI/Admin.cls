/// Administration: folders and retention, analyzer thresholds, maintenance and storage statistics.
Class SysPerf.UI.Admin Extends SysPerf.UI.Base
{

Parameter NAVID = "admin";

Parameter PAGETITLE = "Admin - IRIS Operations Portal";

Parameter SECURITYRESOURCE = "SysPerf_Admin";

ClassMethod OnPost() [ ServerOnly = 1 ]
{
	set %response.Redirect="SysPerf.UI.Admin.cls"
	set tOp=..P("op")
	if tOp="settings" {
		set s=##class(SysPerf.Config.Settings).Get()
		set s.InboxDir=..P("InboxDir"),s.ArchiveDir=..P("ArchiveDir"),s.ErrorDir=..P("ErrorDir"),s.FilePattern=..P("FilePattern","*.html;*.htm")
		set s.KeepRawSections=(..P("KeepRawSections")="1"),s.BackgroundLoad=(..P("BackgroundLoad")="1")
		for tP="RetentionDays","MaxUploadMB","MinRunMinutes" { set v=..P(tP) set:v?1.N $property(s,tP)=v }
		set tSC=s.%Save()
		if $$$ISOK(tSC) set tSC=s.EnsureDirs()
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):"Settings saved.",1:$system.Status.GetErrorText(tSC)))
	} elseif tOp="thresholds" {
		set (tN,tErr)=0,tCode=""
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Code FROM SysPerf_Config.Threshold")
		while tRS.%Next() {
			set tCode=tRS.Code,tObj=##class(SysPerf.Config.Threshold).%OpenId(tCode)
			continue:'$isobject(tObj)
			set w=..P("w_"_tCode),c=..P("c_"_tCode),en=(..P("e_"_tCode)="1")
			set tChanged=0
			if w'=tObj.WarnValue,(w="")||(##class(SysPerf.Util).IsNum(w)) set tObj.WarnValue=w,tChanged=1
			if c'=tObj.CritValue,(c="")||(##class(SysPerf.Util).IsNum(c)) set tObj.CritValue=c,tChanged=1
			if en'=tObj.Enabled set tObj.Enabled=en,tChanged=1
			continue:'tChanged
			set tObj.ModifiedBy=$username,tObj.ModifiedTS=$zdt($h,3)
			if $$$ISOK(tObj.%Save()) { set tN=tN+1 } else { set tErr=tErr+1 }
		}
		do ..Flash($s(tErr:"err",1:"ok"),tN_" rule(s) updated"_$s(tErr:", "_tErr_" failed",1:"")_". Use 'Re-analyse all runs' to apply them to existing runs.")
	} elseif tOp="seed" {
		set tSC=##class(SysPerf.Config.Threshold).Seed(1)
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):"Thresholds reset to defaults.",1:$system.Status.GetErrorText(tSC)))
	} elseif tOp="purge" {
		set tSC=##class(SysPerf.Loader).PurgeOld(.tCount)
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):tCount_" old run(s) purged.",1:$system.Status.GetErrorText(tSC)))
	} elseif tOp="reanalyze" {
		job ##class(SysPerf.Loader).Reanalyze()::5
		do ..Flash($s($test:"ok",1:"err"),$s($test:"Re-analysis of all runs started in the background.",1:"Could not start the background job."))
	}
}

/// Task Manager entries for the load task (read in %SYS)
ClassMethod TaskRows(Output pRows) [ ServerOnly = 1 ]
{
	kill pRows set pRows=0
	new $namespace
	try {
		set tNS=$namespace
		set $namespace="%SYS"
		set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Name,Suspended,LastFinished,NextScheduledDate,NextScheduledTime,DisplayStatus,NameSpace FROM %SYS.Task WHERE TaskClass='SysPerf.Task.LoadInbox'")
		if tRS.%SQLCODE<0 set pRows("err")=tRS.%Message quit
		while tRS.%Next() { set pRows($i(pRows))=$lb(tRS.ID,tRS.Name_" ["_tRS.NameSpace_"]",tRS.Suspended,tRS.LastFinished,tRS.NextScheduledDate_" "_tRS.NextScheduledTime,tRS.DisplayStatus) }
	} catch ex { set pRows("err")=ex.DisplayString() }
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set s=##class(SysPerf.Config.Settings).Get(),tCsrf=..H(..CSRF())
	&html<<h1>Administration</h1><p class="sub">Folders, retention, analyzer thresholds and maintenance.</p>
<div class="grid g2">
<div class="card"><h2>Settings</h2>
<form method="post"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="settings">
<div class="grid" style="gap:10px">
 <label class="small">Inbox folder<input type="text" name="InboxDir" value="#(..H(s.InboxDir))#" style="width:100%"></label>
 <label class="small">Archive folder (loaded files)<input type="text" name="ArchiveDir" value="#(..H(s.ArchiveDir))#" style="width:100%"></label>
 <label class="small">Error folder (failed files)<input type="text" name="ErrorDir" value="#(..H(s.ErrorDir))#" style="width:100%"></label>
 <label class="small">File pattern<input type="text" name="FilePattern" value="#(..H(s.FilePattern))#"></label>
 <div class="flex">
  <label class="small">Retention days (0 = keep)<input type="number" min="0" name="RetentionDays" value="#(s.RetentionDays)#"></label>
  <label class="small">Max upload MB<input type="number" min="1" name="MaxUploadMB" value="#(s.MaxUploadMB)#"></label>
  <label class="small">Min run minutes for capacity analysis<input type="number" min="1" name="MinRunMinutes" value="#(s.MinRunMinutes)#"></label>
 </div>
 <label class="small"><input type="checkbox" name="KeepRawSections" value="1" #($s(s.KeepRawSections:"checked",1:""))#> Keep raw report text (Report text tab)</label>
 <label class="small"><input type="checkbox" name="BackgroundLoad" value="1" #($s(s.BackgroundLoad:"checked",1:""))#> Load uploads in a background job</label>
 <div><button class="btn primary" type="submit">Save settings</button></div>
</div></form></div>
<div class="card"><h2>Maintenance</h2>
 <div class="flex">
  <form method="post"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="reanalyze"><button class="btn" type="submit">Re-analyse all runs</button></form>
  <form method="post" onsubmit="return confirm('Delete runs older than the retention period?')"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="purge"><button class="btn danger" type="submit">Purge old runs now</button></form>
  <form method="post" onsubmit="return confirm('Reset every threshold to its default value?')"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="seed"><button class="btn" type="submit">Reset thresholds</button></form>
 </div>
 <div class="sep"></div>
 <h3>Scheduled task</h3>>
	do ..TaskRows(.tTasks)
	set tAny=0
	for i=1:1:$g(tTasks) {
		set tAny=1,t=tTasks(i)
		write "<dl class='kv'><dt>Task</dt><dd>",..H($li(t,2))," (ID ",$li(t,1),")",$s($li(t,3):" – <b>suspended</b>",1:""),"</dd><dt>Last finished</dt><dd>",..H($li(t,4)),"</dd><dt>Next run</dt><dd>",..H($li(t,5)),"</dd><dt>Status</dt><dd>",..H($li(t,6)),"</dd></dl>"
	}
	if $g(tTasks("err"))'="" write "<p class='small muted'>Task details need read access to the IRISSYS database (%DB_IRISSYS:R). Check the task <b>SysPerf load reports</b> in Management Portal &gt; System Operation &gt; Task Manager.</p>"
	if 'tAny,$g(tTasks("err"))="" write "<p class='small'>No task found. Run <span class='mono'>do ##class(SysPerf.Installer).Setup()</span> or create one in Task Manager with class <span class='mono'>SysPerf.Task.LoadInbox</span>.</p>"
	write "<div class='sep'></div><h3>Storage</h3><table class='t'><thead><tr><th>Table</th><th class='num'>Rows</th></tr></thead><tbody>"
	for tT="Run","Mgstat","OSStat","DiskStat","OSSample","Process","IRISJob","DatabaseFile","ConfigParam","KeyValue","ResourceStat","OSProcess","ReportSection","HourlyStat","Finding","LoadLog" {
		set tR=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) N FROM SysPerf_Data."_tT)
		do tR.%Next()
		write "<tr><td>",tT,"</td><td class='num'>",$fn(tR.N,","),"</td></tr>"
	}
	write "</tbody></table></div></div>"
	&html<<div class="card section"><div class="card-h"><h2>Analyzer thresholds</h2><span class="muted small">H = higher is worse, L = lower is worse, B = configuration check (enable / disable only)</span></div>
<form method="post"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="thresholds">
<div class="tbl-wrap"><table class="t"><thead><tr><th class="nosort">On</th><th class="nosort">Code</th><th class="nosort">Category</th><th class="nosort">Description</th><th class="nosort">Dir</th><th class="nosort">Unit</th><th class="nosort num">Warning</th><th class="nosort num">Critical</th><th class="nosort">Modified</th></tr></thead><tbody>>
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT Code,Category,Description,Direction,Unit,WarnValue,CritValue,Enabled,ModifiedBy,ModifiedTS FROM SysPerf_Config.Threshold ORDER BY Category,Code")
	while tRS.%Next() {
		set c=..H(tRS.Code)
		write "<tr><td><input type='checkbox' name='e_",c,"' value='1'",$s(tRS.Enabled:" checked",1:"")," aria-label='Enable ",c,"'></td><td class='mono'>",c,"</td><td>",..H(tRS.Category),"</td><td>",..H(tRS.Description),"</td><td>",tRS.Direction,"</td><td>",..H(tRS.Unit),"</td>"
		if tRS.Direction="B" { write "<td></td><td></td>" }
		else { write "<td class='num'><input type='text' name='w_",c,"' value='",..H(tRS.WarnValue),"' size='7' aria-label='Warning ",c,"'></td><td class='num'><input type='text' name='c_",c,"' value='",..H(tRS.CritValue),"' size='7' aria-label='Critical ",c,"'></td>" }
		write "<td class='small muted'>",..H(tRS.ModifiedBy)," ",..H(tRS.ModifiedTS),"</td></tr>",!
	}
	&html<</tbody></table></div><div style="margin-top:10px"><button class="btn primary" type="submit">Save thresholds</button></div></form></div>
<div class="card section"><h2>Access</h2><p class="small">Roles created by the installer: <b>SysPerfViewer</b> (read-only dashboards) and <b>SysPerfAdmin</b> (upload, acknowledge findings, settings, delete). Assign them in Management Portal &gt; System Administration &gt; Security &gt; Users.</p></div>
>
	quit $$$OK
}

}
