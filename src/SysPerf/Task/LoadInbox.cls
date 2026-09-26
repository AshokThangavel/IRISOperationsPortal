/// Task Manager job: loads every new ^SystemPerformance report from the inbox folder
/// (Settings.InboxDir or the Folder property), archives processed files and purges old runs.
Class SysPerf.Task.LoadInbox Extends %SYS.Task.Definition
{

Parameter TaskName = "SysPerf - load SystemPerformance reports";

/// Folder to scan (empty = Inbox folder from SysPerf settings)
Property Folder As %String(MAXLEN = 1000);

/// Also scan the instance mgr directory for automatic daily reports of this instance
/// (files are copied, not moved, so ^SystemPerformance retention keeps working)
Property IncludeMgrDirectory As %Boolean [ InitialExpression = 0 ];

/// Purge runs older than the retention period in Settings
Property PurgeOldRuns As %Boolean [ InitialExpression = 1 ];

Method OnTask() As %Status
{
	set tSC=$$$OK
	try {
		if ..IncludeMgrDirectory do ..CopyFromMgr()
		set tSC=##class(SysPerf.Loader).LoadDirectory(..Folder,1,.tSummary,"Task")
		if ..PurgeOldRuns {
			set tSC2=##class(SysPerf.Loader).PurgeOld(.tCount)
			set tSC=$$$ADDSC(tSC,tSC2)
		}
		// fail the task (visible in Task Manager history) when a file could not be loaded
		if $$$ISOK(tSC),$p($p(tSummary,"failed ",2),$c(13),1)>0 set tSC=$$$ERROR($$$GeneralError,$p(tSummary,$c(13),1)_" - see the SysPerf load log (Load SystemPerformance Files / Load PERFMON Files)")
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Copy daily reports (*.html) produced by ^SystemPerformance in the mgr folder into the inbox once.
Method CopyFromMgr()
{
	set tSet=##class(SysPerf.Config.Settings).Get()
	do tSet.EnsureDirs()
	set tMgr=$zu(12)
	set tRS=##class(%ResultSet).%New("%File:FileSet")
	do tRS.Execute(tMgr,"*.html","DateModified",0)
	while tRS.Next() {
		continue:tRS.Get("Type")'="F"
		set tFile=tRS.Get("Name"),tName=##class(%File).GetFilename(tFile)
		continue:$d(^SysPerf.MgrCopied(tName))
		// skip files still being written (modified in the last 5 minutes)
		continue:##class(SysPerf.Util).DiffSec(tRS.Get("DateModified"),$zdt($h,3))<300
		if ##class(%File).CopyFile(tFile,tSet.InboxDir_tName) set ^SysPerf.MgrCopied(tName)=$zdt($h,3)
	}
}

}
