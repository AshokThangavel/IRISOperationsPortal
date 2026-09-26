/// Parsers for the InterSystems IRIS sections of a ^SystemPerformance report.
Class SysPerf.Parser.IRIS [ Abstract ]
{

/// Known mgstat columns that map 1:1 to SysPerf.Data.Mgstat properties
Parameter MGSTATCOLS = "Glorefs,RemGrefs,GRratio,PhyRds,Rdratio,Gloupds,RemGupds,Rourefs,RemRrefs,RouLaS,RemRLaS,PhyWrs,WDQsz,WDtmpq,WDphase,WIJwri,RouCMs,Jrnwrts,GblSz,pGblNsz,pGblAsz,ObjSz,pObjNsz,pObjAsz,BDBSz,pBDBNsz,pBDBAsz,ActECP,Addblk,PrgBufL,PrgSrvR,BytSnt,BytRcd,WDpass,IJUcnt,IJULock,PPGrefs,PPGupds";

// ---------------------------------------------------------------- Debug snapshot

/// Parse the "Debug snapshot" HTML comment (pBarray(...) lines). Gives exact run parameters and
/// the list of collectors that failed (e.g. perfmon "Access is denied").
ClassMethod Debug(ctx As SysPerf.Parser.Context) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run,tErrs=""
	for n=1:1:+$g(^||SP("debug")) {
		set tL=^||SP("debug",n)
		continue:$e(tL,1,8)'="pBarray("
		set tKey=$p($p(tL,")=",1),"(",2,*),tVal=$p(tL,")=",2,*)
		set tSub2=$tr($p(tKey,",",2),""""),tSub3=$tr($p(tKey,",",3),""""),tSub4=$tr($p(tKey,",",4),"""")
		if tSub2="general",tSub3="" {
			set tL2=..LB(tVal)
			set:tRun.Instance="" tRun.Instance=$lg(tL2,1)
			set:tRun.Host="" tRun.Host=$lg(tL2,2)
			set:tRun.Customer="" tRun.Customer=$lg(tL2,3)
			set:tRun.ProductVersion="" tRun.ProductVersion=$lg(tL2,5)
			set tOS=$lg(tL2,6)
			set tRun.Platform=$s(tOS["Windows":"W",tOS'="":"U",1:tRun.Platform)
		} elseif tSub2="profile",tSub3="" {
			set tL2=..LB(tVal)
			set:tRun.ProfileName="" tRun.ProfileName=$lg(tL2,1)
			set tRun.IntervalSec=$lg(tL2,4),tRun.SampleCount=$lg(tL2,5)
			if tRun.IntervalSec,tRun.SampleCount set tRun.PlannedDurationSec=tRun.IntervalSec*tRun.SampleCount
			set:$lg(tL2,6)'="" tRun.StartTS=$zdt($lg(tL2,6),3)
			set:$lg(tL2,9)'="" tRun.PerfmonDefinition=$lg(tL2,9)
			set:$lg(tL2,10)'="" tRun.StartedBy=$lg(tL2,10)
		} elseif tSub2="end",tSub3="" {
			set tH=$tr(tVal,"""")
			if tH?1.N1","1.N set tRun.EndTS=$zdt(tH,3)
		} elseif tSub2="logdir" {
			set tRun.LogDirectory=$tr(tVal,"""")
		} elseif tSub4="err" {
			// handled with the parent entry
		} elseif (tSub2="os")||(tSub2="cache"),tSub3=+tSub3,tSub4="" {
			set tL2=..LB(tVal)
			if $lg(tL2,3)="error" {
				set tMsg=$zstrip($tr($lg(tL2,4),"^"," "),"<=>W")
				set tErrs=tErrs_$s(tErrs="":"",1:"; ")_$lg(tL2,1)_": "_tMsg
			}
		}
	}
	set:tErrs'="" tRun.CollectionErrors=tErrs
	quit tSC
}

/// Parse a $lb(...) literal from the debug snapshot WITHOUT executing it (safe).
ClassMethod LB(pText As %String) As %List
{
	set t=$zstrip(pText,"<>W")
	quit:$e(t,1,4)'="$lb(" ""
	set t=$e(t,5,*-1),tOut="",i=1,tLen=$l(t)
	for {
		quit:i>(tLen+1)
		if $e(t,i)="""" {
			set tVal="",i=i+1
			for {
				quit:i>tLen
				set c=$e(t,i)
				if c="""" { if $e(t,i+1)="""" { set tVal=tVal_"""",i=i+2 continue } set i=i+1 quit }
				set tVal=tVal_c,i=i+1
			}
			set tOut=tOut_$lb(tVal)
			set i=$f(t,",",i) set:'i i=tLen+2
		} else {
			set e=$f(t,",",i)
			set tVal=$s(e:$e(t,i,e-2),1:$e(t,i,*))
			if tVal="" { set tOut=tOut_$lb() } else { set tOut=tOut_$lb(tVal) }
			set i=$s(e:e,1:tLen+2)
		}
	}
	quit tOut
}

// ---------------------------------------------------------------- Configuration / Profile

ClassMethod Configuration(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n)
		continue:$zstrip(tL,"<>W")=""
		if tL[" on machine " {
			set tRun.Instance=$zstrip($p(tL," on machine ",1),"<>W"),tRun.Host=$zstrip($p(tL," on machine ",2),"<>W")
			set tSC=ctx.KV("Configuration","Instance",tRun.Instance) quit:$$$ISERR(tSC)
			set tSC=ctx.KV("Configuration","Machine",tRun.Host) quit:$$$ISERR(tSC)
			continue
		}
		set tName=$zstrip($p(tL,":",1),"<>W"),tVal=$zstrip($p(tL,":",2,*),"<>W")
		if tName["Document Version" set tName="Document Version"
		set tSC=ctx.KV("Configuration",tName,tVal) quit:$$$ISERR(tSC)
		if tName="GUID" set tRun.InstanceGUID=tVal
		if tName="Customer" set tRun.Customer=tVal
		if tName="License" set tRun.LicenseOrder=tVal
		if tName="Product Version String" set tRun.ProductVersion=tVal
	}
	if tRun.ProductVersion'="" {
		set tRun.Platform=$s(tRun.ProductVersion["Windows":"W",1:"U")
		// "... 2026.1 (Build 235U) ..." -> 2026.1.235U
		set tPos=$locate(tRun.ProductVersion,"\d{4}\.\d+(\.\d+)? \(Build [0-9A-Za-z_]+\)",,,tMatch)
		if tPos set tRun.IRISVersion=$p(tMatch," ",1)_"."_$tr($p(tMatch,"Build ",2),")")
	}
	quit tSC
}

ClassMethod Profile(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run
	for n=1:1:ctx.N(pSec,0) {
		set tL=$zstrip(ctx.L(pSec,0,n),"<>W")
		continue:tL=""
		if tL["Profile run" {
			set tRun.ProfileName=$p(tL,"""",2)
			if tL["started by user" set tRun.StartedBy=$p(tL,"""",4)
			set tTime=$p($p(tL," at ",2)," on ",1),tDate=$p($p(tL," on ",$l(tL," on ")),".",1)
			set tTS=##class(SysPerf.Util).TS(tDate,tTime)
			set:tTS'="" tRun.StartTS=tTS
			set tSC=ctx.KV("Profile","Profile",tRun.ProfileName) quit:$$$ISERR(tSC)
			set tSC=ctx.KV("Profile","Started by",tRun.StartedBy) quit:$$$ISERR(tSC)
			set tSC=ctx.KV("Profile","Start",tRun.StartTS) quit:$$$ISERR(tSC)
		} elseif tL["intervals of" {
			set tSC=ctx.KV("Profile","Collection",tL) quit:$$$ISERR(tSC)
		} elseif tL["perfmon counter definition" {
			set tRun.PerfmonDefinition=$p(tL,"""",2)
			set tSC=ctx.KV("Profile","Perfmon definition",tRun.PerfmonDefinition) quit:$$$ISERR(tSC)
		} elseif $e(tL,1,13)="In directory " {
			set tRun.LogDirectory=$e($p(tL,"In directory ",2),1,*-1)
			set tSC=ctx.KV("Profile","Directory",tRun.LogDirectory) quit:$$$ISERR(tSC)
		} else {
			set tSC=ctx.KV("Profile","Line "_n,tL) quit:$$$ISERR(tSC)
		}
	}
	quit tSC
}

/// "IRIS ALL" (iris all / ccontrol all) instance list
ClassMethod InstanceList(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n),w=##class(SysPerf.Util).Words(tL)
		continue:$ll(w)<4
		continue:($lg(w,1)="Instance")||($e($lg(w,1))="-")
		// status name version port dir...  (status can be up/dn/"up," etc.)
		set tStatus=$lg(w,1),tName=$lg(w,2),tVer=$lg(w,3),tPort=$lg(w,4)
		if tPort'?1.N {
			// no status column
			set tStatus="",tName=$lg(w,1),tVer=$lg(w,2),tPort=$lg(w,3)
		}
		set tName=$tr(tName,">*","")
		continue:(tPort'?1.N)
		set tDir=$zstrip($p(tL,"  "_tPort_"  ",2,*),"<>W") set:tDir="" tDir=$zstrip($p(tL,tPort,2,*),"<>W")
		set tSC=ctx.KV("Instances",tName,"status="_tStatus_"; version="_tVer_"; port="_tPort_"; dir="_tDir) quit:$$$ISERR(tSC)
		if $zcvt(tName,"U")=$zcvt(tRun.Instance,"U") {
			set tRun.InstanceDirectory=tDir,tRun.SuperServerPort=tPort
			if tRun.IRISVersion="" set tRun.IRISVersion=tVer
		}
	}
	quit tSC
}

ClassMethod License(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n),t=$zstrip(tL,"<>W")
		continue:t=""
		if t["=" {
			set tSC=ctx.KV("License",$p(t,"=",1),$p(t,"=",2,*))
		} elseif $p(t," ",1)?.1"-"1.N {
			set tSC=ctx.KV("License",$zstrip($p(t," ",2,*),"<=>W"),$p(t," ",1))
		} else {
			set tSC=ctx.KV("License",t,"yes")
		}
		quit:$$$ISERR(tSC)
	}
	quit tSC
}

/// CPF file: [Section] then Name=Value
ClassMethod CPF(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tSection=""
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n),t=$zstrip(tL,"<>W")
		continue:t=""
		if $e(t)="[",$e(t,*)="]" { set tSection=$e(t,2,*-1) continue }
		continue:t'["="
		set tObj=##class(SysPerf.Data.ConfigParam).%New()
		do tObj.RunSetObjectId(ctx.RunId)
		set tObj.Section=tSection,tObj.Name=$e($p(t,"=",1),1,500),tObj.Value=$p(t,"=",2,*),tObj.LineNo=n
		set tSC=tObj.%Save() quit:$$$ISERR(tSC)
		if tSection="Databases" {
			set tDir=##class(SysPerf.Util).NormDir($p($p(t,"=",2,*),",",1))
			set:tDir'="" ctx.DBMap(tDir)=tObj.Name
		}
	}
	quit tSC
}

// ---------------------------------------------------------------- mgstat

ClassMethod Mgstat(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run
	try {
		set tCols="",tMap="",tNo=0,tFirst="",tPrev="",tKnown=$lfs(..#MGSTATCOLS)
		for i=1:1:$ll(tKnown) set tKnownU($zcvt($li(tKnown,i),"U"))=$li(tKnown,i)
		for n=1:1:ctx.N(pSec,0) {
			set tL=ctx.L(pSec,0,n),t=$zstrip(tL,"<>W")
			continue:t=""
			if t["MGSTATv" {
				// file,MGSTATv2.9a,wdcycle=..,globalbuffers=16383MB:..,routinebuffers=1019MB:..,numberofcpus=16:..,productversion=...
				set tRun.MgstatVersion=$p($p(t,"MGSTATv",2),",",1)
				for j=1:1:$l(t,",") {
					set tPair=$p(t,",",j),tK=$zstrip($p(tPair,"=",1),"<>W"),tV=$p(tPair,"=",2,*)
					continue:tPair'["="
					if tK="productversion" set tV=$p(t,"productversion=",2,*) set j=$l(t,",")
					set tSC=ctx.KV("mgstat header",tK,tV) quit:$$$ISERR(tSC)
					if tK="globalbuffers" set tRun.GlobalBuffersMB=+$p(tV,"MB",1)
					if tK="routinebuffers" set tRun.RoutineBuffersMB=+$p(tV,"MB",1)
					if tK="numberofcpus" set tRun.NumCPU=+tV
					if tK="wdcycle" set tRun.WDCycle=tV
				}
				quit:$$$ISERR(tSC)
				continue
			}
			if $e(t,1,5)="Date," {
				set tCols=##class(SysPerf.Util).CSV(t)
				for j=3:1:$ll(tCols) {
					set tC=$li(tCols,j),tU=$zcvt(tC,"U")
					set tMap(j)=$s($d(tKnownU(tU)):tKnownU(tU),1:"#"_tC)
				}
				continue
			}
			continue:tCols=""
			continue:t'?1.2N1"/"1.2N1"/"2.4N1","1.E
			set tV=##class(SysPerf.Util).CSV(t)
			set tTS=##class(SysPerf.Util).TS($li(tV,1),$li(tV,2))
			continue:tTS=""
			set tObj=##class(SysPerf.Data.Mgstat).%New()
			do tObj.RunSetObjectId(ctx.RunId)
			set tObj.SampleNo=$i(tNo),tObj.SampleTS=tTS
			for j=3:1:$ll(tV) {
				continue:'$d(tMap(j))
				set tVal=$lg(tV,j)
				if $e(tMap(j))="#" { do tObj.Extra.SetAt(tVal,$e(tMap(j),2,*)) continue }
				set $property(tObj,tMap(j))=$s(tVal="":"",1:+tVal)
			}
			if tObj.Glorefs>0 {
				set tHit=100*(1-(tObj.PhyRds/tObj.Glorefs))
				set tObj.CacheHitPct=$s(tHit<0:0,tHit>100:100,1:$fn(tHit,"",3))
			}
			set tSC=tObj.%Save() quit:$$$ISERR(tSC)
			set:tFirst="" tFirst=tTS
			if tNo=2,tPrev'="" set ctx.Interval=##class(SysPerf.Util).DiffSec(tPrev,tTS)
			set tPrev=tTS
		}
		quit:$$$ISERR(tSC)
		if tFirst'="" {
			set:ctx.Interval="" ctx.Interval=tRun.IntervalSec
			set tRun.StartTS=$s(tRun.StartTS="":##class(SysPerf.Util).AddSec(tFirst,-ctx.Interval),1:tRun.StartTS)
			set tRun.EndTS=tPrev
			set:ctx.Interval tRun.IntervalSec=ctx.Interval
			set tRun.SampleCount=tNo
			set ctx.BaseDate=$p(tFirst," ",1)
		}
		set ctx.Rows=ctx.Rows+tNo
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

// ---------------------------------------------------------------- %SS

ClassMethod SS(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tSamples=ctx.Samples(pSec)
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k),tMax=ctx.N(pSec,s),tHdr=0,tTS=""
			for n=1:1:tMax {
				set tL=ctx.L(pSec,s,n)
				if tL["System Status:" {
					// InterSystems IRIS System Status: 11:31 am 26 Sep 2026
					set t=$zstrip($p(tL,"System Status:",2),"<=>W")
					set tTS=##class(SysPerf.Util).TS($p(t," ",4)_" "_$p(t," ",3)_" "_$p(t," ",5),$p(t," ",1)_" "_$p(t," ",2))
				}
				if tL["Process",tL["Namespace",tL["Routine" { set tHdr=n quit }
			}
			continue:'tHdr
			set h=ctx.L(pSec,s,tHdr)
			set tDev=$f(h,"Device")-6,tNs=$f(h,"Namespace")-9,tRtn=$f(h,"Routine")-7,tComma=$f(h,"CPU,Glob")-5
			set tPr=$f(h," Pr ")-3,tUser=$f(h,"User/Location")-13
			set:tUser<1 tUser=tPr+3
			// collect records
			kill tRec set r=0
			for n=tHdr+1:1:tMax {
				set tL=ctx.L(pSec,s,n)
				if tL?1.N1" user,".E {
					set tSC=ctx.KV("%SS","Summary",$zstrip(tL,"<>W"),s) quit:$$$ISERR(tSC)
					set tSC=ctx.KV("%SS","User processes",+tL,s) quit:$$$ISERR(tSC)
					set tSC=ctx.KV("%SS","System processes",+$p(tL,", ",2),s) quit:$$$ISERR(tSC)
					quit
				}
				continue:$zstrip(tL,"<>W")=""
				set tLead=$zstrip($e(tL,1,tDev-1),"<>W")
				if tLead?1.N.1"*" { set r=r+1,tRec(r)=1,tRec(r,1)=tL continue }
				if r set tRec(r)=tRec(r)+1,tRec(r,tRec(r))=tL
			}
			quit:$$$ISERR(tSC)
			for r=1:1:r {
				set tObj=##class(SysPerf.Data.Process).%New()
				do tObj.RunSetObjectId(ctx.RunId)
				set tObj.SampleNo=s,tObj.SampleTS=tTS
				set L1=tRec(r,1),tLead=$zstrip($e(L1,1,tDev-1),"<>W")
				set tObj.PID=+tLead,tObj.IsCurrent=(tLead["*")
				set tStart=1
				set L2=$g(tRec(r,2))
				if ($e(L1,tNs-1)'=" ")&&($e(L1,tNs)'=" ")&&($e(L1,tComma)'=",")&&(L2'="")&&($e(L2,1,tNs-1)?." ")&&($e(L2,tNs)'=" ") {
					set tObj.Device=$zstrip($e(L1,tDev,*),"<>W"),tStart=2
				} else {
					set tObj.Device=$zstrip($e(L1,tDev,tNs-1),"<>W")
				}
				set F=tRec(r,tStart)
				set tObj.Namespace=$zstrip($e(F,tNs,tRtn-1),"<>W")
				set tRoutine="",tCPULine=""
				if $e(F,tComma)="," {
					set tCPULine=F
				} else {
					set tRoutine=$zstrip($e(F,tRtn,*),"<>W")
					for j=tStart+1:1:tRec(r) if $e(tRec(r,j),tComma)="," set tCPULine=tRec(r,j) quit
				}
				if tCPULine'="" {
					set tLeft=$e(tCPULine,tRtn,tComma-1)
					if tRoutine'="" {
						set tObj.CPU=+$zstrip(tLeft,"<>W")
					} elseif ($zstrip(tLeft,"<>W")'[" ")&&($zstrip($e(tLeft,16,*),"<>W")?1.N) {
						set tRoutine=$zstrip($e(tLeft,1,15),"<>W"),tObj.CPU=+$zstrip($e(tLeft,16,*),"<>W")
					} else {
						set tW=##class(SysPerf.Util).Words(tLeft)
						set tObj.CPU=+$lg(tW,$ll(tW))
						set tRoutine=$zstrip($e(tLeft,1,$l(tLeft)-$l($lg(tW,$ll(tW)))),"<>W")
					}
					set tObj.Glob=+$e(tCPULine,tComma+1,*)
					set tObj.Priority=+$zstrip($e(tCPULine,tPr,tUser-1),"<>W")
					set tObj.UserLocation=$zstrip($e(tCPULine,tUser,*),"<>W")
				}
				set tObj.Routine=tRoutine
				set tObj.IsSystem=(tObj.Namespace="")
				set tSC=tObj.%Save() quit:$$$ISERR(tSC)
				set ctx.Rows=ctx.Rows+1
			}
			quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
		set tSC=..ProcessDeltas(ctx)
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Compute per-process CPU / global reference deltas between first and last %SS sample
ClassMethod ProcessDeltas(ctx As SysPerf.Parser.Context) As %Status
{
	set tSC=$$$OK
	set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT PID,SampleNo,SampleTS,CPU,Glob,Namespace,Routine,UserLocation,Device FROM SysPerf_Data.Process WHERE Run=? ORDER BY PID,SampleNo",ctx.RunId)
	kill p
	while tRS.%Next() {
		set tPID=tRS.PID
		if '$d(p(tPID)) set p(tPID)=$lb(tRS.SampleNo,tRS.SampleTS,tRS.CPU,tRS.Glob)
		set p(tPID,"last")=$lb(tRS.SampleNo,tRS.SampleTS,tRS.CPU,tRS.Glob,tRS.Namespace,tRS.Routine,tRS.UserLocation,tRS.Device)
	}
	set tTotal=0,tPID=""
	for { set tPID=$o(p(tPID)) quit:tPID=""  set d=$lg(p(tPID,"last"),4)-$lg(p(tPID),4) set:d>0 tTotal=tTotal+d }
	set tRunSec=##class(SysPerf.Util).DiffSec(ctx.Run.StartTS,ctx.Run.EndTS)
	set tMaxS=0,tPID="" for { set tPID=$o(p(tPID)) quit:tPID=""  set:$lg(p(tPID,"last"),1)>tMaxS tMaxS=$lg(p(tPID,"last"),1) }
	set tPID=""
	for {
		set tPID=$o(p(tPID)) quit:tPID=""
		set f=p(tPID),l=p(tPID,"last")
		continue:$lg(l,1)=$lg(f,1)
		set tObj=##class(SysPerf.Data.ProcessDelta).%New()
		do tObj.RunSetObjectId(ctx.RunId)
		set tObj.PID=tPID,tObj.Namespace=$lg(l,5),tObj.Routine=$lg(l,6),tObj.UserLocation=$lg(l,7),tObj.Device=$lg(l,8)
		set tObj.FirstSample=$lg(f,1),tObj.LastSample=$lg(l,1)
		set tSec=##class(SysPerf.Util).DiffSec($lg(f,2),$lg(l,2))
		if (tSec<60)&&(tMaxS>1)&&(tRunSec>0) set tSec=tRunSec*($lg(l,1)-$lg(f,1))/(tMaxS-1)
		set tObj.Seconds=tSec
		set tObj.CPUDelta=$lg(l,3)-$lg(f,3),tObj.GlobDelta=$lg(l,4)-$lg(f,4)
		if tSec>0 set tObj.CPUPerSec=$fn(tObj.CPUDelta/tSec,"",2),tObj.GlobPerSec=$fn(tObj.GlobDelta/tSec,"",2)
		if tTotal>0,tObj.GlobDelta>0 set tObj.GlobSharePct=$fn(tObj.GlobDelta*100/tTotal,"",2)
		set tSC=tObj.%Save() quit:$$$ISERR(tSC)
	}
	quit tSC
}

// ---------------------------------------------------------------- irisstat common

/// Parse "NAME: value, NAME2: value2" header lines of an irisstat sample into KeyValue
ClassMethod HeaderPairs(ctx As SysPerf.Parser.Context, pSection As %String, pLine As %String, pSample As %Integer, ByRef pVars) As %Status
{
	set tSC=$$$OK
	for j=1:1:$l(pLine,", ") {
		set tP=$p(pLine,", ",j)
		continue:tP'[":"
		set tK=$zstrip($p(tP,":",1),"<>W"),tV=$zstrip($p(tP,":",2,*),"<>W")
		continue:(tK="")||($l(tK)>60)
		set pVars(tK)=tV
		set tSC=ctx.KV(pSection,tK,tV,pSample,"Header") quit:$$$ISERR(tSC)
	}
	quit tSC
}

/// Resource stats table rows " 1 - Routine  1438  0 ..." into array res(ResNo)
ClassMethod ResRow(pLine As %String, Output pNo As %Integer, Output pName As %String) As %List
{
	set t=$zstrip(pLine,"<>W"),pNo=+t,pName=""
	quit:$p(t," - ",1)'?1.N ""
	set tRest=$zstrip($p(t," - ",2,*),"<>W"),w=##class(SysPerf.Util).Words(tRest)
	set pName=$lg(w,1)
	quit $li(w,2,*)
}

// ---------------------------------------------------------------- irisstat -c1

ClassMethod IrisstatC1(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run,tSecName="irisstat -c1"
	try {
		// arguments line (sample 0)
		for n=1:1:ctx.N(pSec,0) set tSC=ctx.KV(tSecName,"Arguments",$p(ctx.L(pSec,0,n),":",2,*))
		set tSamples=ctx.Samples(pSec)
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k)
			continue:s=0
			set tSC=..C1Sample(ctx,pSec,s) quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

ClassMethod C1Sample(ctx As SysPerf.Parser.Context, pSec As %Integer, s As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run,tSecName="irisstat -c1"
	set tTS=ctx.IrisstatTime(pSec,s),tMax=ctx.N(pSec,s)
	set tMode="hdr",tGroup="",tJobHdr="",tPidHdr=""
	kill tJobs,tRes,tVars
	set tGroupsKV=$lb("Rtn Statistics","Journaling stats","JOB Server Statistics","WIJ Expansion Statistics","General Use Async I/O Statistics","Integrity Check Async I/O Statistics","Mirroring Async I/O Statistics","Write Daemon Async I/O Statistics","WIJ Write Async I/O Statistics","Prefetch Async I/O Statistics","Backup Async I/O Statistics")
	set n=0
	while n<tMax {
		set n=n+1,tL=ctx.L(pSec,s,n),t=$zstrip(tL,"<>W")
		// ---- section switches
		if $e(t,1,6)="PIDTAB" { set tMode="pidtab",tPidHdr="" continue }
		if t["Summary of jobs" { set tMode="none" continue }
		if (t?1"job:".E)&&(t["routn") { set tMode="jobs",tJobHdr=tL continue }
		if $e(t,1,9)="GFILETAB:" { set tMode="gfile" continue }
		if $e(t,1,14)="RESOURCE STATS" { set tMode="res" continue }
		if $e(t,1,16)="RESOURCE % STATS" { set tMode="respct" continue }
		if $e(t,1,16)="Global Counters:" { set tMode="gcount" continue }
		if $e(t,1,10)="ERROR LOG:" { set tMode="errlog" continue }
		if (t?1"Write Daemon #"1.N1" Statistics:")||(t?1"BSHASH chain statistics".E) { set tMode="kv",tGroup=$p(t,":",1) continue }
		if $lf(tGroupsKV,$p(t,":",1))&&($e(t,*)=":") { set tMode="kv",tGroup=$p(t,":",1) continue }
		if $e(t,1,21)="JOB Server Statistics" { set tMode="kv",tGroup="JOB Server Statistics" continue }
		if $e(t,1,12)="IRISTempSfn:" { set tSC=ctx.KV(tSecName,"IRISTempSfn",+$zstrip($p(t,":",2),"<>W"),s,"Header") set tSC=ctx.KV(tSecName,"IRISAuditSfn",+$zstrip($p(t,"IRISAuditSfn",2),"<>W"),s,"Header") set tMode="none" continue }
		if $e(t,1,9)="WD Phase:" { set tSC=ctx.KV(tSecName,"WD Phase",$p(t,":",2,*),s,"Write Daemon") continue }
		if (tL'?1." ".E)&&($e(t,*)=":")&&(tMode="kv") { set tMode="none" }
		if (t="Transaction(s) in process: job:TPindex,TPfilecnt")||($e(t,1,7)="Dumping")||($e(t,1,12)="Hibernation ")||($e(t,1,8)="Network ")||($e(t,1,9)="NAMESPACE")||($e(t,1,4)="GIND")||($e(t,1,6)="DBName")||($e(t,1,8)="GXLATTAB")||($e(t,1,4)="====")||($e(t,1,6)="Number") { set tMode="none" continue }
		// ---- per mode handling
		if tMode="hdr" {
			if t["ClientSystemName" { set tSC=ctx.KV(tSecName,"ClientSystemName",$p($p(t,"'",2),"'",1),s,"Header") continue }
			continue:t=""
			continue:$e(t,1,9)="LRU Queue"
			continue:(tL?1." ".E)&&($e(t,1,9)'="TotalBlks")
			continue:(t["InterSystems IRIS")||(t["From directory")||(t["From Directory")||(t["IRISSTAT Compiled")||(t["The time is")||($e(t,1,3)="..\")||($e(t,1,2)="./")||(t["bin/irisstat")||(t["bin\irisstat")
			if $e(t,1,11)="Buffer Size" {
				set tRun.BlockSize=+$zstrip($p(t,"Buffer Size:",2),"<>W")
			}
			if t["# of buffers" { set tSC=ctx.KV(tSecName,"buffers in wdqinmemoryq",$p(t,":",2),s,"Header") continue }
			set tSC=..HeaderPairs(ctx,tSecName,t,s,.tVars) quit:$$$ISERR(tSC)
			continue
		}
		if tMode="pidtab" {
			if t="" { set:tPidHdr'="" tMode="none" continue }
			if $e(t,1,4)="job:" { set tPidHdr=$lfs(t,":") continue }
			continue:tPidHdr=""
			continue:$p(t,":",1)'?1.N
			set tJobNo=+$p(t,":",1)
			set tObj=##class(SysPerf.Data.IRISJob).%New()
			do tObj.RunSetObjectId(ctx.RunId)
			set tObj.SampleNo=s,tObj.SampleTS=tTS,tObj.JobNo=tJobNo,tObj.RawLine=$e(tL,1,2000)
			for j=2:1:$ll(tPidHdr) {
				set tCol=$li(tPidHdr,j),tV=$zstrip($p(t,":",j),"<>W")
				if tCol="pid" set tObj.PID=+tV
				if tCol="jobtyp" set tObj.JobType=tV
				if tCol="pstate" set tObj.PState=tV
				if tCol="phyrd" set tObj.PhyRd=+tV
				if tCol="wdqbk" set tObj.WDQBlk=+tV
				if tCol="logrd" set tObj.LogRd=+tV
			}
			set tJobs(tJobNo)=tObj
			continue
		}
		if tMode="jobs" {
			continue:t=""
			set tJ=$p(tL,":",1)
			continue:$zstrip(tJ,"<>W")'?1.N.1"j".1" "
			set tJobNo=+$zstrip(tJ,"<>W"),tR=$p(tL,":",2,*),tFields=""
			set tNext=ctx.L(pSec,s,n+1)
			if ($zstrip(tR,">W")'[" ")&&($zstrip(tR,"<>W")'="")&&($p(tNext,":",1)'?1." "1.N.1"j".1" ") {
				set tRoutine=$zstrip(tR,"<>W"),tFields=tNext,n=n+1
			} else {
				set tRoutine=$zstrip($e(tR,1,7),"<>W"),tFields=$e(tR,8,*)
			}
			set w=##class(SysPerf.Util).Words(tFields),tNs=""
			if ($lg(w,1)'="")&&('##class(SysPerf.Util).IsNum($lg(w,1))) set tNs=$lg(w,1),w=$li(w,2,*)
			set tLines=$lg(w,1),tGlo=$lg(w,2),w=$s($ll(w)>2:$li(w,3,*),1:"")
			set (tDevice,tExe,tIP)=""
			if $ll(w)>=3 { set tDevice=$lg(w,1),tExe=$lg(w,2),tIP=$lg(w,3) }
			elseif $ll(w)=2 { set tDevice=$lg(w,1) if $lg(w,2)?1.3N1"."1.3N1"."1.3N1"."1.3N { set tIP=$lg(w,2) } else { set tExe=$lg(w,2) } }
			elseif $ll(w)=1 { set tDevice=$lg(w,1) }
			if $d(tJobs(tJobNo)) {
				set tObj=tJobs(tJobNo)
				set tObj.Routine=tRoutine,tObj.Namespace=tNs,tObj.Lines=tLines,tObj.Glorefs=tGlo,tObj.Device=tDevice,tObj.Exe=tExe,tObj.ClientIP=tIP
			}
			continue
		}
		if tMode="gfile" {
			if $e(t,1,11)="RO reason: " { if $isobject($g(tDB)) set tDB.ROReason=$p(t,"RO reason: ",2) continue }
			if t="" { set tMode="none" continue }
			if (tL'?1." ".E)&&(t'?1.N1" "1.E) continue
			if t?1.N1" "1.E,(t["/")||(t["\")||(t[":") {
				// "1 c:\intersystems\irishealthuat\mgr\ "
				if $isobject($g(tDB)) { set tSC=tDB.%Save() quit:$$$ISERR(tSC)  set tDB="" }
				set tDB=##class(SysPerf.Data.DatabaseFile).%New()
				do tDB.RunSetObjectId(ctx.RunId)
				set tDB.SampleNo=s,tDB.SampleTS=tTS
				// the numbers may follow the directory on the same line (short paths)
				set w=##class(SysPerf.Util).Words(t),tK=0
				for j=3:1:$ll(w) if ($li(w,j)?1.N)&&($lg(w,j+2)?1.N1","1.N) set tK=j quit
				if tK {
					set tDB.Directory=$lts($li(w,2,tK-1)," ")
					do ..GFileNums(tDB,$li(w,tK,*))
				} else {
					set tDB.Directory=$zstrip($p(t," ",2,*),"<>W")
				}
				set tDB.DBName=$g(ctx.DBMap(##class(SysPerf.Util).NormDir(tDB.Directory)))
				continue
			}
			if $isobject($g(tDB)) do ..GFileNums(tDB,##class(SysPerf.Util).Words(t))
			continue
		}
		if (tMode="res")||(tMode="respct") {
			if t="" { set tMode="none" continue }
			set tNums=..ResRow(tL,.tNo,.tName) continue:tNums=""
			if '$d(tRes(tNo)) {
				set tRes(tNo)=##class(SysPerf.Data.ResourceStat).%New()
				do tRes(tNo).RunSetObjectId(ctx.RunId)
				set tRes(tNo).Source="c1",tRes(tNo).SampleNo=s,tRes(tNo).SampleTS=tTS,tRes(tNo).ResNo=tNo,tRes(tNo).ResName=tName
			}
			set o=tRes(tNo)
			if tMode="res" {
				set o.Seize=+$lg(tNums,1),o.NSeize=+$lg(tNums,2),o.ASeize=+$lg(tNums,3),o.BSeize=+$lg(tNums,4),o.BusySet=+$lg(tNums,5),o.Wakeups=+$lg(tNums,6)
			} else {
				set o.NSeizePct=+$lg(tNums,2),o.ASeizePct=+$lg(tNums,3),o.BSeizePct=+$lg(tNums,4),o.BusySetPct=+$lg(tNums,5),o.WakeupsPct=+$lg(tNums,6)
			}
			continue
		}
		if tMode="gcount" {
			if t="" { set tMode="none" continue }
			set tM=##class(%Regex.Matcher).%New("([A-Za-z][\w\-\>]*(?: [\w\-\>]+)?)\s+(-?\d+)",t)
			while tM.Locate() { set tSC=ctx.KV(tSecName,tM.Group(1),tM.Group(2),s,"Global Counters") quit:$$$ISERR(tSC) }
			quit:$$$ISERR(tSC)
			continue
		}
		if tMode="kv" {
			continue:t=""
			set tLast=$p(t," ",$l(t," ")),tLabel=$zstrip($e(t,1,$l(t)-$l(tLast)),"<>W")
			set:$e(tLabel,*)=":" tLabel=$e(tLabel,1,*-1)
			if ##class(SysPerf.Util).IsNum(tLast),tLabel?.E1A.E { set tSC=ctx.KV(tSecName,tLabel,tLast,s,tGroup) quit:$$$ISERR(tSC) }
			elseif t[":" { set tSC=ctx.KV(tSecName,$p(t,":",1),$p(t,":",2,*),s,tGroup) quit:$$$ISERR(tSC) }
			continue
		}
		if tMode="errlog" {
			continue:t=""
			continue:(t["Err")&&(t["Pid")&&(t["Routine")
			if t["errors kept out of" {
				set tSC=ctx.KV(tSecName,"Errors total",+$p(t,"out of ",2),s,"ERROR LOG") quit:$$$ISERR(tSC)
				set tSC=ctx.KV(tSecName,"Errors kept",+t,s,"ERROR LOG") quit:$$$ISERR(tSC)
				set tMode="none"
				continue
			}
			set tSC=ctx.KV(tSecName,"Error "_$i(tErrNo),t,s,"ERROR LOG") quit:$$$ISERR(tSC)
			continue
		}
	}
	quit:$$$ISERR(tSC) tSC
	if $isobject($g(tDB)) { set tSC=tDB.%Save() quit:$$$ISERR(tSC) tSC }
	set tNo="" for { set tNo=$o(tJobs(tNo)) quit:tNo=""  set tSC=tJobs(tNo).%Save() quit:$$$ISERR(tSC)  set ctx.Rows=ctx.Rows+1 }
	quit:$$$ISERR(tSC) tSC
	set tNo="" for { set tNo=$o(tRes(tNo)) quit:tNo=""  set tSC=tRes(tNo).%Save() quit:$$$ISERR(tSC) }
	quit:$$$ISERR(tSC) tSC
	// large pages / shared memory page size
	if $g(tVars("SHMEMPAGESZ"))'="" set tRun.LargePages=(+tVars("SHMEMPAGESZ")>65536)
	quit tSC
}

/// Fill a DatabaseFile from the GFILETAB number columns (SFN SYS UIC VOL KB BLOCKS EXPBLKS MAXBLOCKS GDIR GPNT RDIR RGRW GDAT COL CENG FLAGS...)
ClassMethod GFileNums(tDB As SysPerf.Data.DatabaseFile, w As %List) [ Private ]
{
	set tDB.SFN=$lg(w,1),tDB.SysNo=$lg(w,2),tDB.BlockSizeKB=$lg(w,5),tDB.Blocks=$lg(w,6),tDB.ExpBlocks=$lg(w,7),tDB.MaxBlocks=$lg(w,8),tDB.Collation=$lg(w,14)
	set tDB.Flags=$s($ll(w)>15:$lts($li(w,16,*)," "),1:"")
	set tDB.SizeMB=$fn(tDB.Blocks*tDB.BlockSizeKB/1024,"",1)
	set tDB.MaxSizeMB=$s(tDB.MaxBlocks>0:$fn(tDB.MaxBlocks*tDB.BlockSizeKB/1024,"",1),1:"")
	set tDB.ReadOnly=((" "_tDB.Flags_" ")[" RDO ")
	set tDB.Journaled='((" "_tDB.Flags_" ")[" NOJN ")
}

// ---------------------------------------------------------------- irisstat -D

ClassMethod IrisstatD(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tSecName="irisstat -D"
	try {
		for n=1:1:ctx.N(pSec,0) set tSC=ctx.KV(tSecName,"Arguments",$p(ctx.L(pSec,0,n),":",2,*))
		set tSamples=ctx.Samples(pSec)
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k) continue:s=0
			set tTS=ctx.IrisstatTime(pSec,s),tMode="hdr",tInt="",tColl=""
			kill tRes,tVars
			for n=1:1:ctx.N(pSec,s) {
				set tL=ctx.L(pSec,s,n),t=$zstrip(tL,"<>W")
				if $e(t,1,21)="RESOURCE STATS OVER A" { set tInt=+$p(t,"OVER A ",2),tMode="res" continue }
				if $e(t,1,16)="RESOURCE % STATS" { set tMode="pct" continue }
				if $e(t,1,19)="RESOURCE /sec STATS" { set tMode="sec" continue }
				if $e(t,1,9)="Total of " {
					set tColl=+$p(t,"Total of ",2),tMode="coll"
					set tSC=ctx.KV(tSecName,"Block collisions",tColl,s,"Block collisions") quit:$$$ISERR(tSC)
					set tSC=ctx.KV(tSecName,"Collision samples",+$p(t," in ",2),s,"Block collisions") quit:$$$ISERR(tSC)
					continue
				}
				if tMode="hdr" {
					continue:(t="")||(t["InterSystems IRIS")||(t["From directory")||(t["From Directory")||(t["IRISSTAT Compiled")||(t["The time is")||(t["irisstat -s")||(t["ClientSystemName")
					continue:(tL?1." ".E)&&($e(t,1,9)'="TotalBlks")&&($e(t,1,10)'="Grequeuecn")&&($e(t,1,9)'="Gminreque")
					set tSC=..HeaderPairs(ctx,tSecName,t,s,.tVars) quit:$$$ISERR(tSC)
					continue
				}
				if tMode="coll" {
					continue:t=""
					set tSC=ctx.KV(tSecName,"Collision line "_n,t,s,"Block collisions") quit:$$$ISERR(tSC)
					continue
				}
				set tNums=..ResRow(tL,.tNo,.tName) continue:tNums=""
				if '$d(tRes(tNo)) {
					set tRes(tNo)=##class(SysPerf.Data.ResourceStat).%New()
					do tRes(tNo).RunSetObjectId(ctx.RunId)
					set tRes(tNo).Source="D",tRes(tNo).SampleNo=s,tRes(tNo).SampleTS=tTS,tRes(tNo).ResNo=tNo,tRes(tNo).ResName=tName,tRes(tNo).IntervalSec=tInt
				}
				set o=tRes(tNo)
				if tMode="res" {
					set o.Seize=+$lg(tNums,1),o.NSeize=+$lg(tNums,2),o.ASeize=+$lg(tNums,3),o.BSeize=+$lg(tNums,4),o.BusySet=+$lg(tNums,5),o.Wakeups=+$lg(tNums,6)
				} elseif tMode="pct" {
					set o.NSeizePct=+$lg(tNums,2),o.ASeizePct=+$lg(tNums,3),o.BSeizePct=+$lg(tNums,4),o.BusySetPct=+$lg(tNums,5),o.WakeupsPct=+$lg(tNums,6)
				} elseif tMode="sec" {
					set o.SeizePerSec=+$lg(tNums,1),o.NSeizePerSec=+$lg(tNums,2),o.ASeizePerSec=+$lg(tNums,3),o.BSeizePerSec=+$lg(tNums,4)
				}
			}
			quit:$$$ISERR(tSC)
			set tNo="" for { set tNo=$o(tRes(tNo)) quit:tNo=""  set tRes(tNo).BlockCollisions=tColl set tSC=tRes(tNo).%Save() quit:$$$ISERR(tSC) }
			quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

// ---------------------------------------------------------------- irisstat -R

ClassMethod IrisstatR(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tSecName="irisstat -R"
	try {
		set tSamples=ctx.Samples(pSec),tHdr=0
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k)
			for n=1:1:ctx.N(pSec,s) {
				set tL=ctx.L(pSec,s,n),t=$zstrip(tL,"<>W")
				continue:t=""
				if t["irisstat arguments" { set tSC=ctx.KV(tSecName,"Arguments",$p(t,":",2,*)) continue }
				if (t["hash")&&(t["rouname") { set tHdr=1 continue }
				if 'tHdr {
					continue:(t["InterSystems IRIS")||(t["From directory")||(t["From Directory")||(t["IRISSTAT Compiled")||(t["irisstat -s")||(t["ClientSystemName")
					if t["The time is" continue
					if $e(t,1,18)="Number of rtn buf:" {
						set tR=$p(t,":",2,*)
						for j=1:1:$l(tR,",") { set tP=$zstrip($p(tR,",",j),"<>W") continue:tP=""  set tSC=ctx.KV(tSecName,"Routine buffers "_$zstrip($p(tP,"->",1),"<>W"),$p(tP,"->",2),s,"Routine buffers") }
						continue
					}
					if $e(t,1,11)="gmaxrouvec " { set tSC=ctx.KV(tSecName,"gmaxrouvec",$p(t,":",2,*),s,"Routine buffers") continue }
					if $e(t,1,16)="gmaxinitalrouvec" { set tSC=ctx.KV(tSecName,"gmaxinitalrouvec",$p(t,":",2,*),s,"Routine buffers") continue }
					if t["gmaxsharedclsvec" {
						set tM=##class(%Regex.Matcher).%New("(gmaxsharedclsvec|gmaxclsvec|classes inuse|classes LRU)\s+(\d+)",t)
						while tM.Locate() { set tSC=ctx.KV(tSecName,tM.Group(1),tM.Group(2),s,"Class vectors") }
						continue
					}
					if t["shared cls memused" { set tSC=ctx.KV(tSecName,"shared cls memused",$p(t,"memused",2),s,"Class vectors") continue }
					if t["numrblru" { set tSC=ctx.KV(tSecName,"numrblru",+$p(t,"numrblru=",2),s,"Routine buffers") set tSC=ctx.KV(tSecName,"rou wait time sec",+$zstrip($p(t,"wait time",2),"<>W"),s,"Routine buffers") continue }
					set tSC=ctx.KV(tSecName,"Line "_n,t,s,"Header")
					continue
				}
				set w=##class(SysPerf.Util).Words(t)
				continue:$lg(w,1)'?1.N1":"1.N
				set tObj=##class(SysPerf.Data.RoutineBuffer).%New()
				do tObj.RunSetObjectId(ctx.RunId)
				set tObj.SampleNo=s,tObj.Hash=+$p($lg(w,1),":",1),tObj.Buf=+$p($lg(w,1),":",2)
				set tObj.SizeBytes=$lg(w,2),tObj.SysNo=$lg(w,3),tObj.SFN=$lg(w,4),tObj.InUse=$lg(w,5),tObj.Old=$lg(w,6),tObj.BufType=$lg(w,7)
				set tObj.RoutineName=$lts($li(w,12,*)," ")
				set tSC=tObj.%Save() quit:$$$ISERR(tSC)
			}
			quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

}
