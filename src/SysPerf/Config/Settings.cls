/// Application settings (singleton, ID = 1). Edit from the Admin page or with
/// <example>set s=##class(SysPerf.Config.Settings).Get() set s.InboxDir="D:\SysPerf\Inbox\" do s.%Save()</example>
Class SysPerf.Config.Settings Extends %Persistent [ SqlTableName = Settings ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Settings";

/// Singleton key (always 1)
Property SettingKey As %Integer [ InitialExpression = 1, Required ];

Index KeyIdx On SettingKey [ IdKey, Unique ];

/// Folder scanned by the scheduled task and by "Scan inbox" in the UI
Property InboxDir As %String(MAXLEN = 1000);

/// Successfully loaded files are moved here (empty = leave in inbox)
Property ArchiveDir As %String(MAXLEN = 1000);

/// Files that failed to load are moved here (empty = leave in inbox)
Property ErrorDir As %String(MAXLEN = 1000);

/// File name pattern for inbox scan (semicolon separated)
Property FilePattern As %String(MAXLEN = 200) [ InitialExpression = "*.html;*.htm" ];

/// Keep the raw text of every section (lets admins browse the original report inside the tool)
Property KeepRawSections As %Boolean [ InitialExpression = 1 ];

/// Also scan the IRIS mgr directory for daily ^SystemPerformance reports (for local instance)
Property ScanMgrDir As %Boolean [ InitialExpression = 0 ];

/// Runs older than this many days are purged by the scheduled task (0 = never)
Property RetentionDays As %Integer [ InitialExpression = 400 ];

/// Maximum upload size in MB from the UI
Property MaxUploadMB As %Integer [ InitialExpression = 512 ];

/// Load uploaded files in a background job (recommended for 24h reports)
Property BackgroundLoad As %Boolean [ InitialExpression = 1 ];

/// Minimum run length (minutes) below which analyzer flags the run as too short for capacity analysis
Property MinRunMinutes As %Integer [ InitialExpression = 60 ];

Property LastScanTS As %TimeStamp;

ClassMethod Get() As SysPerf.Config.Settings
{
	set tObj=..%OpenId(1)
	if '$isobject(tObj) {
		set tObj=..%New()
		set tMgr=$zu(12)
		set tBase=##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(tMgr)_"SysPerf")
		set tObj.InboxDir=##class(%File).NormalizeDirectory(tBase_"Inbox")
		set tObj.ArchiveDir=##class(%File).NormalizeDirectory(tBase_"Archive")
		set tObj.ErrorDir=##class(%File).NormalizeDirectory(tBase_"Error")
		do tObj.%Save()
		set tObj=..%OpenId(1)
	}
	quit tObj
}

Method %OnBeforeSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	for tDir="InboxDir","ArchiveDir","ErrorDir" {
		set tVal=$property($this,tDir)
		if tVal'="" set $property($this,tDir)=##class(%File).NormalizeDirectory(tVal)
	}
	quit $$$OK
}

/// Create configured directories if missing
Method EnsureDirs() As %Status
{
	set tSC=$$$OK
	for tDir=..InboxDir,..ArchiveDir,..ErrorDir {
		continue:tDir=""
		if '##class(%File).DirectoryExists(tDir) {
			if '##class(%File).CreateDirectoryChain(tDir) set tSC=$$$ADDSC(tSC,$$$ERROR($$$GeneralError,"Cannot create directory "_tDir))
		}
	}
	quit tSC
}

Storage Default
{
<Data name="SettingsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>InboxDir</Value>
</Value>
<Value name="3">
<Value>ArchiveDir</Value>
</Value>
<Value name="4">
<Value>ErrorDir</Value>
</Value>
<Value name="5">
<Value>FilePattern</Value>
</Value>
<Value name="6">
<Value>KeepRawSections</Value>
</Value>
<Value name="7">
<Value>ScanMgrDir</Value>
</Value>
<Value name="8">
<Value>RetentionDays</Value>
</Value>
<Value name="9">
<Value>MaxUploadMB</Value>
</Value>
<Value name="10">
<Value>BackgroundLoad</Value>
</Value>
<Value name="11">
<Value>MinRunMinutes</Value>
</Value>
<Value name="12">
<Value>LastScanTS</Value>
</Value>
</Data>
<DataLocation>^SysPerf.SettingsD</DataLocation>
<DefaultData>SettingsDefaultData</DefaultData>
<IdLocation>^SysPerf.SettingsD</IdLocation>
<IndexLocation>^SysPerf.SettingsI</IndexLocation>
<StreamLocation>^SysPerf.SettingsS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
