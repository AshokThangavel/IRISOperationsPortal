/// Task Manager job: run a PERFMON timed collection (e.g. every weekday at the busy hour) and load it.
Class SysPerf.Task.PerfmonCollect Extends %SYS.Task.Definition
{

Parameter TaskName = "SysPerf - PERFMON timed collection";

/// Collection length in seconds (10-3600)
Property Seconds As %Integer [ InitialExpression = 60 ];

Method OnTask() As %Status
{
	set tSC=##class(SysPerf.PM.Collector).Validate(..Seconds) quit:$$$ISERR(tSC) tSC
	set tSC=##class(SysPerf.PM.Collector).CheckIdle() quit:$$$ISERR(tSC) tSC
	set r=##class(SysPerf.PM.CollectRequest).%New()
	set r.DurationSec=..Seconds,r.Origin="Task"
	set tSC=r.%Save() quit:$$$ISERR(tSC) tSC
	quit ##class(SysPerf.PM.Collector).Run(r.%Id())
}

}
