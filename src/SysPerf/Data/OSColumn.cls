/// Column definition of a raw OS time series (perfmon counter path, vmstat/iostat/sar column).
/// Values live in <class>SysPerf.Data.OSSample</class>.Vals at position ColNo.
Class SysPerf.Data.OSColumn Extends SysPerf.Data.Child [ SqlTableName = OSColumn ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.OSColumn";

Property Source As %String(MAXLEN = 30);

Property ColNo As %Integer;

/// Full column name (e.g. \\HOST\PhysicalDisk(0 C:)\Avg. Disk sec/Read or r_await)
Property Name As %String(MAXLEN = 500);

/// perfmon object / iostat section (e.g. PhysicalDisk, Processor, Memory, device)
Property ObjectName As %String(MAXLEN = 200);

/// perfmon instance / device / cpu (e.g. 0 C:, _Total, sda, all)
Property InstanceName As %String(MAXLEN = 200);

/// counter / column (e.g. Avg. Disk sec/Read, r_await)
Property Counter As %String(MAXLEN = 200);

Index RunSrcCol On (Run, Source, ColNo) [ Unique ];

Storage Default
{
<Data name="OSColumnDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>Source</Value>
</Value>
<Value name="4">
<Value>ColNo</Value>
</Value>
<Value name="5">
<Value>Name</Value>
</Value>
<Value name="6">
<Value>ObjectName</Value>
</Value>
<Value name="7">
<Value>InstanceName</Value>
</Value>
<Value name="8">
<Value>Counter</Value>
</Value>
</Data>
<DataLocation>^SysPerf.OSColumnD</DataLocation>
<DefaultData>OSColumnDefaultData</DefaultData>
<IdLocation>^SysPerf.OSColumnD</IdLocation>
<IndexLocation>^SysPerf.OSColumnI</IndexLocation>
<StreamLocation>^SysPerf.OSColumnS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
