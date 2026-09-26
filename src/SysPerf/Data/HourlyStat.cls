/// Hourly roll-up of a metric (computed at load). Drives the day / week / month / custom views
/// without scanning millions of raw samples.
Class SysPerf.Data.HourlyStat Extends SysPerf.Data.Child [ SqlTableName = HourlyStat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.HourlyStat";

Property SystemName As %String(MAXLEN = 400);

/// yyyy-mm-dd hh:00:00
Property HourTS As %TimeStamp;

Property HourDate As %Date;

/// 0-23
Property HourOfDay As %Integer;

/// 1=Sunday .. 7=Saturday
Property DayOfWeek As %Integer;

Property Metric As %String(MAXLEN = 100);

/// device for disk metrics, "-" for system level metrics
Property Entity As %String(MAXLEN = 200) [ InitialExpression = "-" ];

Property Cnt As %Integer;

Property SumV As %Double;

Property MinV As %Double;

Property MaxV As %Double;

Property P95 As %Double;

Property AvgV As %Double;

Index SysMetricHour On (SystemName, Metric, HourTS);

Index DateIdx On HourDate;

Storage Default
{
<Data name="HourlyStatDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>SystemName</Value>
</Value>
<Value name="4">
<Value>HourTS</Value>
</Value>
<Value name="5">
<Value>HourDate</Value>
</Value>
<Value name="6">
<Value>HourOfDay</Value>
</Value>
<Value name="7">
<Value>DayOfWeek</Value>
</Value>
<Value name="8">
<Value>Metric</Value>
</Value>
<Value name="9">
<Value>Entity</Value>
</Value>
<Value name="10">
<Value>Cnt</Value>
</Value>
<Value name="11">
<Value>SumV</Value>
</Value>
<Value name="12">
<Value>MinV</Value>
</Value>
<Value name="13">
<Value>MaxV</Value>
</Value>
<Value name="14">
<Value>P95</Value>
</Value>
<Value name="15">
<Value>AvgV</Value>
</Value>
</Data>
<DataLocation>^SysPerf.HourlyStatD</DataLocation>
<DefaultData>HourlyStatDefaultData</DefaultData>
<IdLocation>^SysPerf.HourlyStatD</IdLocation>
<IndexLocation>^SysPerf.HourlyStatI</IndexLocation>
<StreamLocation>^SysPerf.HourlyStatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
