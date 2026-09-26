/// Parsers for the operating-system sections (Windows and Unix/Linux) of a ^SystemPerformance report.
Class SysPerf.Parser.OS [ Abstract ]
{

// ================================================================ Windows

/// systeminfo output ("Windows info")
ClassMethod WindowsInfo(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run,tKey="",tVal=""
	for n=1:1:ctx.N(pSec,0)+1 {
		set tL=$s(n>ctx.N(pSec,0):"",1:ctx.L(pSec,0,n))
		if (n>ctx.N(pSec,0))||((tL'?1" ".E)&&(tL[":")) {
			if tKey'="" {
				set tSC=ctx.KV("Windows info",tKey,tVal) quit:$$$ISERR(tSC)
				do ..WinField(tRun,tKey,tVal)
			}
			quit:n>ctx.N(pSec,0)
			set tKey=$zstrip($p(tL,":",1),"<>W"),tVal=$zstrip($p(tL,":",2,*),"<>W")
		} else {
			set t=$zstrip(tL,"<>W")
			set:t'="" tVal=tVal_$s(tVal="":"",1:"; ")_t
		}
	}
	quit tSC
}

ClassMethod WinField(tRun As SysPerf.Data.Run, pKey As %String, pVal As %String) [ Private ]
{
	if pKey="OS Name" set tRun.OSName=pVal
	if pKey="OS Version" set tRun.OSVersion=pVal
	if pKey="Total Physical Memory" set tRun.TotalMemoryMB=##class(SysPerf.Util).Num(pVal)
	if pKey="Available Physical Memory" set tRun.AvailableMemoryMB=##class(SysPerf.Util).Num(pVal)
	if pKey="System Boot Time" set tRun.BootTime=pVal
	if pKey="Processor(s)" set tRun.CPUModel=$zstrip($p(pVal,"]:",2),"<>W")
	if (pKey="System Manufacturer")||(pKey="System Model") {
		set tU=$zcvt(pVal,"U")
		for tHV="VMWARE","VIRTUAL","QEMU","XEN","KVM","NUTANIX","HYPER-V","AMAZON EC2","GOOGLE","OPENSTACK" {
			if tU[tHV set tRun.IsVirtual=1 set:tRun.Hypervisor="" tRun.Hypervisor=pVal quit
		}
		if pKey="System Model",(tU["VIRTUAL MACHINE") set tRun.Hypervisor="Microsoft Hyper-V/Azure"
	}
}

/// tasklist -V : fixed width columns defined by the ===== separator line
ClassMethod Tasklist(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tSamples=ctx.Samples(pSec)
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k),tCols="",tHdr=""
			for n=1:1:ctx.N(pSec,s) {
				set tL=ctx.L(pSec,s,n)
				continue:$zstrip(tL,"<>W")=""
				if $e($zstrip(tL,"<>W"),1,3)="===" {
					// column ranges
					set tCols="",p=1
					for {
						set a=$f(tL,"=",p) quit:'a
						set b=$f(tL," ",a) set:'b b=$l(tL)+2
						set tCols=tCols_$lb($lb(a-1,b-2)),p=b
					}
					continue
				}
				if tCols="" { set tHdr=tL continue }
				set tObj=##class(SysPerf.Data.OSProcess).%New()
				do tObj.RunSetObjectId(ctx.RunId)
				set tObj.Source="tasklist",tObj.SampleNo=s
				for c=1:1:$ll(tCols) {
					set a=$li($li(tCols,c),1),b=$s(c=$ll(tCols):$l(tL),1:$li($li(tCols,c),2))
					set v=$zstrip($e(tL,a,b),"<>W")
					if c=1 set tObj.ImageName=v
					if c=2 set tObj.PID=+v
					if c=3 set tObj.SessionName=v
					if c=5 set tObj.MemKB=##class(SysPerf.Util).Num(v)
					if c=6 set tObj.Status=v
					if c=7 set tObj.UserName=v
					if c=8 set tObj.CPUTime=v,tObj.CPUSeconds=##class(SysPerf.Util).TimeToSec(v)
					if c=9 set tObj.WindowTitle=v
				}
				set tI=$zcvt(tObj.ImageName,"L")
				set tObj.IsIRIS=($e(tI,1,4)="iris")||($e(tI,1,5)="cache")||(tI="cstat.exe")
				set tSC=tObj.%Save() quit:$$$ISERR(tSC)
				set ctx.Rows=ctx.Rows+1
			}
			quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// perfmon CSV ("(PDH-CSV 4.0)" header). Raw values -> OSColumn/OSSample, normalised -> OSStat/DiskStat
ClassMethod Perfmon(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tHdr="",tNo=0,tSamples=ctx.Samples(pSec)
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k)
			for n=1:1:ctx.N(pSec,s) {
				set tL=ctx.L(pSec,s,n)
				continue:$zstrip(tL,"<>W")=""
				if tL["(PDH-CSV" {
					set tHdr=##class(SysPerf.Util).QuotedCSV(tL)
					kill tMap
					for c=2:1:$ll(tHdr) {
						set tPath=$li(tHdr,c)
						// \\HOST\Object(Instance)\Counter
						set tP=$p(tPath,"\",4,*),tCounter=$p(tP,"\",$l(tP,"\")),tObjInst=$p(tP,"\",1,$l(tP,"\")-1)
						set tObjName=$p(tObjInst,"(",1),tInst=$s(tObjInst["(":$p($p(tObjInst,"(",2,*),")",1,$l($p(tObjInst,"(",2,*),")")-1),1:"")
						set tCol=##class(SysPerf.Data.OSColumn).%New()
						do tCol.RunSetObjectId(ctx.RunId)
						set tCol.Source="perfmon",tCol.ColNo=c,tCol.Name=$e(tPath,1,500),tCol.ObjectName=tObjName,tCol.InstanceName=tInst,tCol.Counter=tCounter
						set tSC=tCol.%Save() quit:$$$ISERR(tSC)
						set tMap(c)=$lb(tObjName,tInst,tCounter)
					}
					quit:$$$ISERR(tSC)
					continue
				}
				continue:tHdr=""
				continue:$e(tL)'=""""
				set tV=##class(SysPerf.Util).QuotedCSV(tL)
				set tRaw=$li(tV,1),tTS=##class(SysPerf.Util).TS($p(tRaw," ",1),$p(tRaw," ",2))
				continue:tTS=""
				set tNo=tNo+1
				set tVals=""
				for c=2:1:$ll(tV) { set v=$zstrip($li(tV,c),"<>W") set tVals=tVals_$lb($s(##class(SysPerf.Util).IsNum(v):+v,1:"")) }
				set tSmp=##class(SysPerf.Data.OSSample).%New()
				do tSmp.RunSetObjectId(ctx.RunId)
				set tSmp.Source="perfmon",tSmp.SampleNo=tNo,tSmp.SampleTS=tTS,tSmp.Vals=tVals
				set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
				// normalise
				set tOS=##class(SysPerf.Data.OSStat).%New()
				do tOS.RunSetObjectId(ctx.RunId)
				set tOS.Source="perfmon",tOS.SampleNo=tNo,tOS.SampleTS=tTS
				kill tDisk set (tMaxCore,tRx,tTx,tIdleTot)=""
				for c=2:1:$ll(tV) {
					continue:'$d(tMap(c))
					set v=$lg(tVals,c-1) continue:v=""
					set tO=$li(tMap(c),1),tI=$li(tMap(c),2),tC=$li(tMap(c),3)
					if tO="Processor" {
						if tI="_Total" {
							if tC="% Processor Time" set tOS.CPUBusyPct=v
							if tC="% User Time" set tOS.CPUUserPct=v
							if tC="% Privileged Time" set tOS.CPUSysPct=v
							if tC="% Interrupt Time" set tOS.CPUInterruptPct=v
							if tC="% Idle Time" set tIdleTot=v
						} else {
							set tBusy=$s(tC="% Idle Time":100-v,tC="% Processor Time":v,1:"")
							if tBusy'="",(tMaxCore="")||(tBusy>tMaxCore) set tMaxCore=tBusy
						}
					} elseif tO="System" {
						if tC="Processor Queue Length" set tOS.RunQueue=v
						if tC="Processes" set tOS.ProcessCount=v
					} elseif tO="Memory" {
						if tC="Available MBytes" set tOS.MemAvailMB=v
						if tC="% Committed Bytes In Use" set tOS.MemCommitPct=v
						if tC="Page Reads/sec" set tOS.PageInPerSec=v
						if tC="Page Writes/sec" set tOS.PageOutPerSec=v
					} elseif tO="Paging File" {
						if tC="% Usage",(tI="_Total")||(tOS.PagingFilePct="") set tOS.PagingFilePct=v
					} elseif tO="Network Interface" {
						if tC="Bytes Received/sec" set tRx=tRx+(v/1024)
						if tC="Bytes Sent/sec" set tTx=tTx+(v/1024)
					} elseif (tO="PhysicalDisk")||(tO="LogicalDisk"),tI'="_Total" {
						set tKey=tO_":"_tI
						if tC="Avg. Disk sec/Read" set tDisk(tKey,"ReadLatMs")=v*1000
						if tC="Avg. Disk sec/Write" set tDisk(tKey,"WriteLatMs")=v*1000
						if tC="Disk Reads/sec" set tDisk(tKey,"ReadsPerSec")=v
						if tC="Disk Writes/sec" set tDisk(tKey,"WritesPerSec")=v
						if tC="Disk Transfers/sec" set tDisk(tKey,"TransfersPerSec")=v
						if tC="Disk Read Bytes/sec" set tDisk(tKey,"ReadKBPerSec")=v/1024
						if tC="Disk Write Bytes/sec" set tDisk(tKey,"WriteKBPerSec")=v/1024
						if tC="Current Disk Queue Length" set tDisk(tKey,"QueueLen")=v
						if tC="Avg. Disk Read Queue Length" set tDisk(tKey,"ReadQueue")=v
						if tC="Avg. Disk Write Queue Length" set tDisk(tKey,"WriteQueue")=v
						if tC="% Idle Time" set tDisk(tKey,"UtilPct")=$s(100-v<0:0,1:100-v)
					}
				}
				if tOS.CPUBusyPct="",tIdleTot'="" set tOS.CPUBusyPct=100-tIdleTot
				set tOS.CPUMaxCorePct=tMaxCore,tOS.NetRxKBPerSec=tRx,tOS.NetTxKBPerSec=tTx
				set tSC=tOS.%Save() quit:$$$ISERR(tSC)
				// prefer PhysicalDisk; use LogicalDisk only when no PhysicalDisk counters
				set tHasPhys=($o(tDisk("PhysicalDisk:"))["PhysicalDisk:")
				set tKey=""
				for {
					set tKey=$o(tDisk(tKey)) quit:tKey=""
					if tHasPhys,$p(tKey,":",1)="LogicalDisk" continue
					set tD=##class(SysPerf.Data.DiskStat).%New()
					do tD.RunSetObjectId(ctx.RunId)
					set tD.Source="perfmon",tD.SampleNo=tNo,tD.SampleTS=tTS,tD.Device=$p(tKey,":",2,*)
					set tF="" for { set tF=$o(tDisk(tKey,tF)) quit:tF=""  set $property(tD,tF)=$fn(tDisk(tKey,tF),"",3) }
					if tD.QueueLen="",tD.ReadQueue'="" set tD.QueueLen=tD.ReadQueue+tD.WriteQueue
					set tSC=tD.%Save() quit:$$$ISERR(tSC)
				}
				quit:$$$ISERR(tSC)
				set ctx.Rows=ctx.Rows+1
			}
			quit:$$$ISERR(tSC)
		}
		quit:$$$ISERR(tSC)
		if tHdr="" {
			// collector failed - keep the message
			set tMsg=""
			for n=1:1:ctx.N(pSec,0) set t=$zstrip(ctx.L(pSec,0,n),"<>W") set:t'="" tMsg=tMsg_$s(tMsg="":"",1:" ")_t
			if tMsg'="" {
				set tSC=ctx.KV("perfmon","Collector message",tMsg)
				if ctx.Run.CollectionErrors'["perfmon" set ctx.Run.CollectionErrors=ctx.Run.CollectionErrors_$s(ctx.Run.CollectionErrors="":"",1:"; ")_"perfmon: "_tMsg
			}
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

// ================================================================ Unix / Linux

/// vmstat with the date/time prefix added by ^SystemPerformance
ClassMethod Vmstat(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tNames="",tNo=0,tColsSaved=0
		for n=1:1:ctx.N(pSec,0) {
			set tL=ctx.L(pSec,0,n),w=##class(SysPerf.Util).Words(tL)
			continue:w=""
			if $lf(w,"r"),$lf(w,"b") {
				// header - strip leading date/time tokens
				set tNames="",seen=""
				for j=1:1:$ll(w) {
					set tN=$li(w,j)
					continue:(tN["/")||(tN?1.2N1":"2N1":"2N)||(tN="AM")||(tN="PM")
					if $d(seen(tN)) { set tN=tN_"_2" }
					set seen(tN)="",tNames=tNames_$lb(tN)
				}
				if 'tColsSaved {
					for j=1:1:$ll(tNames) {
						set tCol=##class(SysPerf.Data.OSColumn).%New() do tCol.RunSetObjectId(ctx.RunId)
						set tCol.Source="vmstat",tCol.ColNo=j,tCol.Name=$li(tNames,j),tCol.Counter=$li(tNames,j)
						set tSC=tCol.%Save() quit:$$$ISERR(tSC)
					}
					quit:$$$ISERR(tSC)
					set tColsSaved=1
				}
				continue
			}
			continue:tNames=""
			continue:$lg(w,1)="procs"
			set tDate="",tTime=""
			if $lg(w,1)["/" { set tDate=$li(w,1),tTime=$li(w,2),w=$li(w,3,*) if ($lg(w,1)="AM")||($lg(w,1)="PM") set tTime=tTime_" "_$li(w,1),w=$li(w,2,*) }
			continue:'##class(SysPerf.Util).IsNum($lg(w,1))
			set tTS=$s(tDate'="":##class(SysPerf.Util).TS(tDate,tTime),1:##class(SysPerf.Util).AddSec(ctx.Run.StartTS,tNo*ctx.Interval))
			set tNo=tNo+1
			set tSmp=##class(SysPerf.Data.OSSample).%New() do tSmp.RunSetObjectId(ctx.RunId)
			set tSmp.Source="vmstat",tSmp.SampleNo=tNo-1,tSmp.SampleTS=tTS
			set tVals="" for j=1:1:$ll(w) set tVals=tVals_$lb(+$li(w,j))
			set tSmp.Vals=tVals
			set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
			// first line = averages since boot -> raw only
			continue:tNo=1
			set tOS=##class(SysPerf.Data.OSStat).%New() do tOS.RunSetObjectId(ctx.RunId)
			set tOS.Source="vmstat",tOS.SampleNo=tNo-1,tOS.SampleTS=tTS
			for j=1:1:$ll(tNames) {
				set tN=$li(tNames,j),v=$lg(w,j) continue:v=""
				set v=+v
				if tN="r" set tOS.RunQueue=v
				if tN="b" set tOS.ProcsBlocked=v
				if tN="swpd" set tOS.SwapUsedMB=$fn(v/1024,"",1)
				if tN="free" set tOS.MemFreeMB=$fn(v/1024,"",1)
				if tN="fre" set tOS.MemFreeMB=$fn(v*4/1024,"",1)
				if tN="buff" set tOS.MemBuffMB=$fn(v/1024,"",1)
				if tN="cache" set tOS.MemCacheMB=$fn(v/1024,"",1)
				if tN="si" set tOS.SwapInPerSec=v
				if tN="so" set tOS.SwapOutPerSec=v
				if tN="pi" set tOS.PageInPerSec=v
				if tN="po" set tOS.PageOutPerSec=v
				if tN="bi" set tOS.BlocksInPerSec=v
				if tN="bo" set tOS.BlocksOutPerSec=v
				if tN="in" set tOS.InterruptsPerSec=v
				if tN="cs" set tOS.ContextSwPerSec=v
				if tN="us" set tOS.CPUUserPct=v
				if (tN="sy")||(tN="sy_2") set tOS.CPUSysPct=v
				if tN="id" set tOS.CPUBusyPct=100-v
				if tN="wa" set tOS.CPUIOWaitPct=v
				if tN="st" set tOS.CPUStealPct=v
			}
			set tSC=tOS.%Save() quit:$$$ISERR(tSC)
			set ctx.Rows=ctx.Rows+1
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Disk column name -> DiskStat property (and multiplier)
ClassMethod DiskCol(pName As %String, Output pMult As %Double) As %String
{
	set pMult=1,n=$zcvt($zstrip(pName,"<>W"),"L")
	quit:n="r/s" "ReadsPerSec"
	quit:n="w/s" "WritesPerSec"
	quit:n="tps" "TransfersPerSec"
	quit:n="rkb/s" "ReadKBPerSec"
	quit:n="wkb/s" "WriteKBPerSec"
	if n="rmb/s" set pMult=1024 quit "ReadKBPerSec"
	if n="wmb/s" set pMult=1024 quit "WriteKBPerSec"
	if (n="rsec/s")||(n="rd_sec/s") set pMult=0.5 quit "ReadKBPerSec"
	if (n="wsec/s")||(n="wr_sec/s") set pMult=0.5 quit "WriteKBPerSec"
	quit:n="r_await" "ReadLatMs"
	quit:n="w_await" "WriteLatMs"
	quit:n="await" "AwaitMs"
	quit:(n="aqu-sz")||(n="avgqu-sz") "QueueLen"
	quit:n="%util" "UtilPct"
	quit:n="areq-sz" "AvgReqKB"
	if n="avgrq-sz" set pMult=0.5 quit "AvgReqKB"
	quit ""
}

/// iostat -x -t (avg-cpu + Device blocks per interval)
ClassMethod Iostat(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tNo=0,tTS="",tMode="",tCpuNames="",tDevNames="",tDevCols=0,tCpuCols=0,tHasTS=0
		for n=1:1:ctx.N(pSec,0) {
			set tL=ctx.L(pSec,0,n),t=$zstrip(tL,"<>W"),w=##class(SysPerf.Util).Words(tL)
			if t="" { set tMode="" continue }
			// timestamp line "09/26/2026 09:07:44 AM" or ISO "2026-09-26T09:07:44+0000"
			if ($ll(w)<=3)&&(($lg(w,1)?1.2N1"/"1.2N1"/"2.4N)||($lg(w,1)?4N1"-"2N1"-"2N.E))&&($lg(w,2)[":"||($lg(w,1)["T")) {
				set tHasTS=1
				if $lg(w,1)["T" { set tTS=##class(SysPerf.Util).TS($p($lg(w,1),"T",1),$e($p($lg(w,1),"T",2),1,8)) }
				else { set tTS=##class(SysPerf.Util).TS($lg(w,1),$lg(w,2)_" "_$lg(w,3)) }
				set tNo=tNo+1
				continue
			}
			if $e(t,1,8)="avg-cpu:" {
				set tCpuNames=##class(SysPerf.Util).Words($p(t,"avg-cpu:",2)),tMode="cpu"
				if 'tHasTS set tNo=tNo+1,tTS=##class(SysPerf.Util).AddSec(ctx.Run.StartTS,(tNo-1)*ctx.Interval)
				if 'tCpuCols {
					for j=1:1:$ll(tCpuNames) { set tCol=##class(SysPerf.Data.OSColumn).%New() do tCol.RunSetObjectId(ctx.RunId) set tCol.Source="iostat-cpu",tCol.ColNo=j,tCol.Name=$li(tCpuNames,j),tCol.Counter=$li(tCpuNames,j) set tSC=tCol.%Save() quit:$$$ISERR(tSC) }
					quit:$$$ISERR(tSC)
					set tCpuCols=1
				}
				continue
			}
			if ($e(t,1,6)="Device")||($e(t,1,5)="Disks") {
				set tDevNames=$li(w,2,*),tMode="dev"
				if 'tDevCols {
					for j=1:1:$ll(tDevNames) { set tCol=##class(SysPerf.Data.OSColumn).%New() do tCol.RunSetObjectId(ctx.RunId) set tCol.Source="iostat",tCol.ColNo=j,tCol.Name=$li(tDevNames,j),tCol.Counter=$li(tDevNames,j) set tSC=tCol.%Save() quit:$$$ISERR(tSC) }
					quit:$$$ISERR(tSC)
					set tDevCols=1
				}
				continue
			}
			if tMode="cpu" {
				continue:'##class(SysPerf.Util).IsNum($lg(w,1))
				set tVals="" for j=1:1:$ll(w) set tVals=tVals_$lb(+$li(w,j))
				set tSmp=##class(SysPerf.Data.OSSample).%New() do tSmp.RunSetObjectId(ctx.RunId)
				set tSmp.Source="iostat-cpu",tSmp.SampleNo=tNo,tSmp.SampleTS=tTS,tSmp.Vals=tVals
				set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
				set tMode=""
				// first report = since boot
				continue:tNo<=1
				set tOS=##class(SysPerf.Data.OSStat).%New() do tOS.RunSetObjectId(ctx.RunId)
				set tOS.Source="iostat",tOS.SampleNo=tNo,tOS.SampleTS=tTS
				for j=1:1:$ll(tCpuNames) {
					set tN=$li(tCpuNames,j),v=+$lg(w,j)
					if tN="%user" set tOS.CPUUserPct=v
					if tN="%system" set tOS.CPUSysPct=v
					if tN="%iowait" set tOS.CPUIOWaitPct=v
					if tN="%steal" set tOS.CPUStealPct=v
					if tN="%idle" set tOS.CPUBusyPct=100-v
				}
				set tSC=tOS.%Save() quit:$$$ISERR(tSC)
				continue
			}
			if tMode="dev" {
				set tDev=$lg(w,1)
				continue:tDev=""
				set tVals="" for j=2:1:$ll(w) set tVals=tVals_$lb(+$li(w,j))
				set tSmp=##class(SysPerf.Data.OSSample).%New() do tSmp.RunSetObjectId(ctx.RunId)
				set tSmp.Source="iostat",tSmp.SampleNo=tNo,tSmp.SampleTS=tTS,tSmp.Entity=tDev,tSmp.Vals=tVals
				set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
				continue:tNo<=1
				set tD=##class(SysPerf.Data.DiskStat).%New() do tD.RunSetObjectId(ctx.RunId)
				set tD.Source="iostat",tD.SampleNo=tNo,tD.SampleTS=tTS,tD.Device=tDev
				for j=1:1:$ll(tDevNames) {
					set tProp=..DiskCol($li(tDevNames,j),.tMult) continue:tProp=""
					set v=$lg(w,j+1) continue:v=""
					set $property(tD,tProp)=$fn(v*tMult,"",3)
				}
				if tD.TransfersPerSec="" set tD.TransfersPerSec=tD.ReadsPerSec+tD.WritesPerSec
				set tSC=tD.%Save() quit:$$$ISERR(tSC)
				set ctx.Rows=ctx.Rows+1
			}
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// Find "mm/dd/yyyy" in the sar/iostat banner line
ClassMethod BannerDate(ctx As SysPerf.Parser.Context, pSec As %Integer) As %String
{
	set tOut=ctx.BaseDate
	for n=1:1:$s(ctx.N(pSec,0)<5:ctx.N(pSec,0),1:5) {
		set w=##class(SysPerf.Util).Words(ctx.L(pSec,0,n))
		for j=1:1:$ll(w) {
			set tW=$li(w,j)
			if (tW?1.2N1"/"1.2N1"/"2.4N)||(tW?4N1"-"2N1"-"2N) set tOut=$p(##class(SysPerf.Util).TS(tW,"00:00:00")," ",1) quit
		}
		quit:tOut'=ctx.BaseDate
	}
	quit tOut
}

/// Split a sar line into time + rest. Returns time "hh:mm:ss" (24h) or "" when not a data line.
ClassMethod SarTime(ByRef w As %List) As %String
{
	set t=$lg(w,1)
	quit:t'?1.2N1":"2N1":"2N ""
	set tAP=$lg(w,2)
	if (tAP="AM")||(tAP="PM") {
		set hh=+t if tAP="PM",hh<12 set hh=hh+12
		if tAP="AM",hh=12 set hh=0
		set t=##class(SysPerf.Util).P2(hh)_":"_$p(t,":",2,3),w=$li(w,3,*)
	} else { set w=$li(w,2,*) }
	quit t
}

ClassMethod SarU(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tDate=..BannerDate(ctx,pSec),tNames="",tPrevT="",tNo=0,tCols=0,tLastTS=""
		kill tCore
		for n=1:1:ctx.N(pSec,0) {
			set w=##class(SysPerf.Util).Words(ctx.L(pSec,0,n))
			continue:w=""
			continue:$lg(w,1)["Average"
			set tT=..SarTime(.w) continue:tT=""
			if $lf(w,"CPU") {
				set tNames=$li(w,2,*)
				if 'tCols { for j=1:1:$ll(tNames) { set tCol=##class(SysPerf.Data.OSColumn).%New() do tCol.RunSetObjectId(ctx.RunId) set tCol.Source="sar-u",tCol.ColNo=j,tCol.Name=$li(tNames,j),tCol.Counter=$li(tNames,j) set tSC=tCol.%Save() quit:$$$ISERR(tSC) } set tCols=1 }
				quit:$$$ISERR(tSC)
				continue
			}
			continue:tNames=""
			if tPrevT'="",tT<tPrevT set tDate=$zd($zdh(tDate,3)+1,3)
			set tPrevT=tT,tTS=tDate_" "_tT,tCPU=$lg(w,1)
			set tVals="" for j=2:1:$ll(w) set tVals=tVals_$lb(+$li(w,j))
			set tSmp=##class(SysPerf.Data.OSSample).%New() do tSmp.RunSetObjectId(ctx.RunId)
			set tSmp.Source="sar-u",tSmp.SampleTS=tTS,tSmp.Entity=tCPU,tSmp.Vals=tVals
			if tTS'=tLastTS set tNo=tNo+1,tLastTS=tTS
			set tSmp.SampleNo=tNo
			set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
			if tCPU'="all" {
				set tIdle=$lg(w,$lf(tNames,"%idle")+1)
				if tIdle'="" { set b=100-tIdle if '$d(tCore(tTS))||(b>tCore(tTS)) set tCore(tTS)=b }
				continue
			}
			set tOS=##class(SysPerf.Data.OSStat).%New() do tOS.RunSetObjectId(ctx.RunId)
			set tOS.Source="sar-u",tOS.SampleNo=tNo,tOS.SampleTS=tTS
			for j=2:1:$ll(tNames) {
				set tN=$li(tNames,j),v=$lg(w,j+1) continue:v=""
				set v=+v
				if (tN="%user")||(tN="%usr") set tOS.CPUUserPct=v
				if (tN="%system")||(tN="%sys") set tOS.CPUSysPct=v
				if tN="%iowait" set tOS.CPUIOWaitPct=v
				if tN="%steal" set tOS.CPUStealPct=v
				if tN="%idle" set tOS.CPUBusyPct=$fn(100-v,"",2)
				if tN="%irq" set tOS.CPUInterruptPct=v
			}
			set tSC=tOS.%Save() quit:$$$ISERR(tSC)
			set ctx.Rows=ctx.Rows+1
		}
		quit:$$$ISERR(tSC)
		// busiest core per timestamp (sar -P ALL)
		set tTS=""
		for {
			set tTS=$o(tCore(tTS)) quit:tTS=""
			set tID=..FindOSStat(ctx.RunId,"sar-u",tTS) continue:tID=""
			set tOS=##class(SysPerf.Data.OSStat).%OpenId(tID) set tOS.CPUMaxCorePct=tCore(tTS) set tSC=tOS.%Save() quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

ClassMethod FindOSStat(pRun As %Integer, pSource As %String, pTS As %String) As %String
{
	&sql(SELECT TOP 1 ID INTO :tID FROM SysPerf_Data.OSStat WHERE Run=:pRun AND Source=:pSource AND SampleTS=:pTS)
	quit $s(SQLCODE=0:tID,1:"")
}

ClassMethod SarD(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tDate=..BannerDate(ctx,pSec),tNames="",tPrevT="",tNo=0,tCols=0,tLastTS=""
		for n=1:1:ctx.N(pSec,0) {
			set w=##class(SysPerf.Util).Words(ctx.L(pSec,0,n))
			continue:w=""
			continue:$lg(w,1)["Average"
			set tT=..SarTime(.w) continue:tT=""
			if $lg(w,1)="DEV" {
				set tNames=$li(w,2,*)
				if 'tCols { for j=1:1:$ll(tNames) { set tCol=##class(SysPerf.Data.OSColumn).%New() do tCol.RunSetObjectId(ctx.RunId) set tCol.Source="sar-d",tCol.ColNo=j,tCol.Name=$li(tNames,j),tCol.Counter=$li(tNames,j) set tSC=tCol.%Save() quit:$$$ISERR(tSC) } set tCols=1 }
				quit:$$$ISERR(tSC)
				continue
			}
			continue:tNames=""
			if tPrevT'="",tT<tPrevT set tDate=$zd($zdh(tDate,3)+1,3)
			set tPrevT=tT,tTS=tDate_" "_tT,tDev=$lg(w,1)
			if tTS'=tLastTS set tNo=tNo+1,tLastTS=tTS
			set tVals="" for j=2:1:$ll(w) set tVals=tVals_$lb(+$li(w,j))
			set tSmp=##class(SysPerf.Data.OSSample).%New() do tSmp.RunSetObjectId(ctx.RunId)
			set tSmp.Source="sar-d",tSmp.SampleNo=tNo,tSmp.SampleTS=tTS,tSmp.Entity=tDev,tSmp.Vals=tVals
			set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
			set tD=##class(SysPerf.Data.DiskStat).%New() do tD.RunSetObjectId(ctx.RunId)
			set tD.Source="sar-d",tD.SampleNo=tNo,tD.SampleTS=tTS,tD.Device=tDev
			for j=1:1:$ll(tNames) {
				set tProp=..DiskCol($li(tNames,j),.tMult) continue:tProp=""
				set v=$lg(w,j+1) continue:v=""
				set $property(tD,tProp)=$fn(v*tMult,"",3)
			}
			set tSC=tD.%Save() quit:$$$ISERR(tSC)
			set ctx.Rows=ctx.Rows+1
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// free (CSV written by ^SystemPerformance, MB)
ClassMethod Free(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tNames="",tNo=0
		for n=1:1:ctx.N(pSec,0) {
			set t=$zstrip(ctx.L(pSec,0,n),"<>W")
			continue:t=""
			set tV=##class(SysPerf.Util).CSV(t)
			if $e(t,1,5)="Date," {
				set tNames=tV
				for j=3:1:$ll(tNames) { continue:$li(tNames,j)=""  set tCol=##class(SysPerf.Data.OSColumn).%New() do tCol.RunSetObjectId(ctx.RunId) set tCol.Source="free",tCol.ColNo=j-2,tCol.Name=$li(tNames,j),tCol.Counter=$li(tNames,j) set tSC=tCol.%Save() quit:$$$ISERR(tSC) }
				quit:$$$ISERR(tSC)
				continue
			}
			continue:tNames=""
			set tTS=##class(SysPerf.Util).TS($lg(tV,1),$lg(tV,2)) continue:tTS=""
			set tNo=tNo+1
			set tVals="" for j=3:1:$ll(tV) { continue:$li(tNames,j)=""  set tVals=tVals_$lb(+$li(tV,j)) }
			set tSmp=##class(SysPerf.Data.OSSample).%New() do tSmp.RunSetObjectId(ctx.RunId)
			set tSmp.Source="free",tSmp.SampleNo=tNo,tSmp.SampleTS=tTS,tSmp.Vals=tVals
			set tSC=tSmp.%Save() quit:$$$ISERR(tSC)
			set tOS=##class(SysPerf.Data.OSStat).%New() do tOS.RunSetObjectId(ctx.RunId)
			set tOS.Source="free",tOS.SampleNo=tNo,tOS.SampleTS=tTS
			for j=3:1:$ll(tNames) {
				set tN=$zcvt($li(tNames,j),"L"),v=$lg(tV,j) continue:v=""
				set v=+v
				if tN="memtotal",ctx.Run.TotalMemoryMB="" set ctx.Run.TotalMemoryMB=v
				if tN="free" set tOS.MemFreeMB=v
				if tN="available" set tOS.MemAvailMB=v
				if tN="buf/cache" set tOS.MemCacheMB=v
				if tN="swapused" set tOS.SwapUsedMB=v
			}
			set tSC=tOS.%Save() quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// ps -elfy
ClassMethod PS(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK
	try {
		set tSamples=ctx.Samples(pSec)
		for k=1:1:$ll(tSamples) {
			set s=$li(tSamples,k),tHdr=""
			for n=1:1:ctx.N(pSec,s) {
				set tL=ctx.L(pSec,s,n),w=##class(SysPerf.Util).Words(tL)
				continue:w=""
				if $lf(w,"PID"),$lf(w,"CMD")||$lf(w,"COMMAND") { set tHdr=w continue }
				continue:tHdr=""
				set tNC=$ll(tHdr)-1
				continue:$ll(w)<tNC
				set tObj=##class(SysPerf.Data.OSProcess).%New() do tObj.RunSetObjectId(ctx.RunId)
				set tObj.Source="ps",tObj.SampleNo=s
				for j=1:1:tNC {
					set tN=$li(tHdr,j),v=$li(w,j)
					if tN="S" set tObj.Status=v
					if (tN="UID")||(tN="USER") set tObj.UserName=v
					if tN="PID" set tObj.PID=+v
					if tN="PPID" set tObj.PPID=+v
					if tN="PRI" set tObj.Priority=v
					if (tN="RSS")||(tN="RSZ") set tObj.MemKB=+v
					if tN="TIME" set tObj.CPUTime=v,tObj.CPUSeconds=##class(SysPerf.Util).TimeToSec(v)
					if tN="TTY" set tObj.SessionName=v
				}
				set tObj.Command=$e($lts($li(w,tNC+1,*)," "),1,2000)
				set tExe=$p($lg(w,tNC+1),"/",$l($lg(w,tNC+1),"/"))
				set tObj.ImageName=tExe
				set tObj.IsIRIS=(tExe["irisdb")||(tExe["iris")||(tExe["cache")||(tExe["irisstat")
				set tSC=tObj.%Save() quit:$$$ISERR(tSC)
				set ctx.Rows=ctx.Rows+1
			}
			quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

/// cpu section: lscpu (key: value) - /proc/cpuinfo stays in the raw section
ClassMethod CPUInfo(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n),t=$zstrip(tL,"<>W")
		continue:(t="")||(t="lscpu:")
		quit:$e(t,1,13)="/proc/cpuinfo"
		continue:t'[":"
		set tK=$zstrip($p(t,":",1),"<>W"),tV=$zstrip($p(t,":",2,*),"<>W")
		set tSC=ctx.KV("cpu",tK,tV,0,"lscpu") quit:$$$ISERR(tSC)
		if tK="CPU(s)",tRun.NumCPU="" set tRun.NumCPU=+tV
		if tK="Model name" set tRun.CPUModel=tV
		if tK="Hypervisor vendor" set tRun.IsVirtual=1,tRun.Hypervisor=tV
	}
	quit tSC
}

/// df -m / df -k
ClassMethod DF(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tPend=""
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n),w=##class(SysPerf.Util).Words(tL)
		continue:w=""
		continue:$lg(w,1)="Filesystem"
		// long device names wrap onto the next line
		if $ll(w)=1 { set tPend=$lg(w,1) continue }
		if tPend'="" set w=$lb(tPend)_w,tPend=""
		continue:$ll(w)<6
		set tMount=$lts($li(w,6,*)," "),tPct=+$tr($li(w,5),"%")
		set tSC=ctx.KV("df",tMount,tPct,0,"Use%") quit:$$$ISERR(tSC)
		set tSC=ctx.KV("df",tMount,"fs="_$li(w,1)_"; sizeMB="_$li(w,2)_"; usedMB="_$li(w,3)_"; availMB="_$li(w,4)_"; use="_$li(w,5),0,"Filesystem") quit:$$$ISERR(tSC)
	}
	quit tSC
}

/// key = value lines (sysctl -a)
ClassMethod KeyEq(ctx As SysPerf.Parser.Context, pSec As %Integer, pSection As %String) As %Status
{
	set tSC=$$$OK
	for n=1:1:ctx.N(pSec,0) {
		set t=$zstrip(ctx.L(pSec,0,n),"<>W")
		continue:t'["="
		set tSC=ctx.KV(pSection,$p(t,"=",1),$p(t,"=",2,*)) quit:$$$ISERR(tSC)
	}
	quit tSC
}

/// ipcs: shared memory segments and semaphores
ClassMethod Ipcs(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tGrp="",tShm=0
	for n=1:1:ctx.N(pSec,0) {
		set t=$zstrip(ctx.L(pSec,0,n),"<>W")
		continue:t=""
		if $e(t,1,6)="------" { set tGrp=$zstrip($tr(t,"-"),"<>W") continue }
		set w=##class(SysPerf.Util).Words(t)
		continue:($lg(w,1)="key")||($lg(w,1)="")
		if tGrp["Shared Memory" set tShm=tShm+$lg(w,5)
		set tSC=ctx.KV("ipcs",tGrp_" "_$lg(w,2),t,0,tGrp) quit:$$$ISERR(tSC)
	}
	if tShm set tSC=ctx.KV("ipcs","Shared memory total MB",$fn(tShm/1048576,"",0),0,"Summary")
	quit tSC
}

/// "<distro> info" section: uname, os-release, id, ulimit, /proc/meminfo ...
ClassMethod UnixInfo(ctx As SysPerf.Parser.Context, pSec As %Integer) As %Status
{
	set tSC=$$$OK,tRun=ctx.Run,tGrp="",tSecName=$lg(^||SP("sec",pSec),1)
	for n=1:1:ctx.N(pSec,0) {
		set tL=ctx.L(pSec,0,n),t=$zstrip(tL,"<>W")
		continue:t=""
		if $e(t,*)=":",t'[" = " { set tGrp=$e(t,1,*-1) continue }
		if $e(t,1,8)="uname -a" { set tRun.OSVersion=$zstrip($p(t,":",2,*),"<>W") set tSC=ctx.KV(tSecName,"uname -a",tRun.OSVersion,0,"uname") continue }
		if tGrp="issue" { set:tRun.OSName="" tRun.OSName=t set tSC=ctx.KV(tSecName,"issue",t,0,tGrp) continue }
		if tGrp="ulimit -a",t["(" {
			set tSC=ctx.KV(tSecName,$zstrip($p(t,"(",1),"<>W"),$p(t," ",$l(t," ")),0,tGrp) continue
		}
		if t?1(1A,1"_").(1AN,1"_")1"=".E {
			set tK=$p(t,"=",1),tV=$tr($p(t,"=",2,*),"""")
			if tK="PRETTY_NAME" set tRun.OSName=tV
			set tSC=ctx.KV(tSecName,tK,tV,0,tGrp) continue
		}
		if t[":" {
			set tK=$zstrip($p(t,":",1),"<>W"),tV=$zstrip($p(t,":",2,*),"<>W")
			if tK="MemTotal" set tRun.TotalMemoryMB=$fn(+tV/1024,"",0)
			set tSC=ctx.KV(tSecName,tK,tV,0,tGrp) continue
		}
		set tSC=ctx.KV(tSecName,tGrp_" "_n,t,0,tGrp)
	}
	quit tSC
}

// ================================================================ derived

/// Per source & timestamp: worst disk latency / queue / util and total IOPS into OSStat
ClassMethod DeriveDiskMax(ctx As SysPerf.Parser.Context) As %Status
{
	set tSC=$$$OK
	try {
		set tSQL="SELECT %EXACT(Source) Source,SampleTS,MIN(SampleNo) SampleNo,MAX(ReadLatMs) RL,MAX(WriteLatMs) WL,MAX(AwaitMs) AW,MAX(QueueLen) Q,MAX(UtilPct) U,SUM(TransfersPerSec) T,SUM(ReadsPerSec) R,SUM(WritesPerSec) W FROM SysPerf_Data.DiskStat WHERE Run=? GROUP BY %EXACT(Source),SampleTS"
		set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL,ctx.RunId)
		while tRS.%Next() {
			set tSrc=tRS.Source
			set tOSSrc=$case(tSrc,"iostat":"iostat","perfmon":"perfmon",:tSrc)
			set tID=..FindOSStat(ctx.RunId,tOSSrc,tRS.SampleTS)
			if tID'="" { set tOS=##class(SysPerf.Data.OSStat).%OpenId(tID) }
			else { set tOS=##class(SysPerf.Data.OSStat).%New() do tOS.RunSetObjectId(ctx.RunId) set tOS.Source=tOSSrc,tOS.SampleTS=tRS.SampleTS,tOS.SampleNo=tRS.SampleNo }
			set tOS.DiskMaxReadLatMs=$s(tRS.RL'="":tRS.RL,1:tRS.AW)
			set tOS.DiskMaxWriteLatMs=$s(tRS.WL'="":tRS.WL,1:tRS.AW)
			set tOS.DiskMaxQueue=tRS.Q,tOS.DiskMaxUtilPct=tRS.U
			set tOS.DiskTotalIOPS=$s(tRS.T'="":tRS.T,1:tRS.R+tRS.W)
			set tSC=tOS.%Save() quit:$$$ISERR(tSC)
		}
	} catch ex { set tSC=ex.AsStatus() }
	quit tSC
}

}
