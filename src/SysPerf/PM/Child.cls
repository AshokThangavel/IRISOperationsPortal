/// Abstract superclass of every table that belongs to a PERFMON collection.
Class SysPerf.PM.Child Extends %Persistent [ Abstract, NoExtent ]
{

Property Coll As SysPerf.PM.Collection [ Required ];

/// Position in the report table (1 = highest)
Property Rank As %Integer;

/// The "Other" aggregate row of the report
Property IsOther As %Boolean [ InitialExpression = 0 ];

Index CollIdx On Coll [ Type = bitmap ];

}
