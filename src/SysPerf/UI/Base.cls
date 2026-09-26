/// Common layout, security and helpers for all SysPerf %CSP.Page screens.
/// Access requires USE on resource SysPerf_Viewer; admin actions require USE on SysPerf_Admin.
Class SysPerf.UI.Base Extends %CSP.Page [ Abstract ]
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "text/html";

Parameter SECURITYRESOURCE = "SysPerf_Viewer";

/// Application version (also busts browser cache of CSS/JS)
Parameter VERSION = "1.2.0";

Parameter PAGETITLE = "IRIS Performance Analytics";

/// Nav item to highlight: home, runs, compare, load, admin
Parameter NAVID;

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	kill %SysPerfReply
	do ..SecurityHeaders()
	if %request.Method="POST" {
		if '..CheckCSRF() {
			if ..WantsJSON() {
				set %response.Status="403 Forbidden",%response.ContentType="application/json"
				set %SysPerfReply={"error":"Session token expired - reload the page and retry."}
				quit 1
			}
			do ..Flash("err","Your session token expired - please retry.")
			set %response.Redirect=%request.URL_$s(%request.CgiEnvs("QUERY_STRING")'="":"?"_%request.CgiEnvs("QUERY_STRING"),1:"")
			quit 1
		}
		try {
			do ..OnPost()
		} catch ex {
			if ..WantsJSON() { set %response.ContentType="application/json",%SysPerfReply={"error":(ex.DisplayString())} }
			else { do ..Flash("err",ex.DisplayString()) }
		}
	}
	quit 1
}

/// JSON reply wanted (fetch() calls send the X-CSRF-Token header)
ClassMethod WantsJSON() As %Boolean [ ServerOnly = 1 ]
{
	quit (%request.GetCgiEnv("HTTP_X_CSRF_TOKEN")'="")||(%request.GetCgiEnv("HTTP_ACCEPT")["application/json")
}

ClassMethod SecurityHeaders() [ ServerOnly = 1 ]
{
	do %response.SetHeader("X-Frame-Options","SAMEORIGIN")
	do %response.SetHeader("X-Content-Type-Options","nosniff")
	do %response.SetHeader("Referrer-Policy","same-origin")
	do %response.SetHeader("Cache-Control","no-store")
}

/// Override to handle POST. Either set %response.Redirect (post/redirect/get) or call ReplyJSON().
ClassMethod OnPost() [ ServerOnly = 1 ]
{
}

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	set tSC=$$$OK
	if $d(%SysPerfReply) {
		do %SysPerfReply.%ToJSON()
		quit $$$OK
	}
	try {
		do ..Header()
		set tSC=..Body()
		if $$$ISERR(tSC) write "<div class='notice err'>",..H($system.Status.GetErrorText(tSC)),"</div>"
		do ..Footer()
	} catch ex {
		write "<div class='notice err'>Unexpected error: ",..H(ex.DisplayString()),"</div>"
		do ..Footer()
	}
	quit $$$OK
}

/// Override: page content
ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	quit $$$OK
}

ClassMethod Title() As %String [ CodeMode = expression, ServerOnly = 1 ]
{
..#PAGETITLE
}

/// Navigation item to highlight (override for pages with several views)
ClassMethod NavId() As %String [ CodeMode = expression, ServerOnly = 1 ]
{
..#NAVID
}

/// Sidebar definition: group|id|label|url|admin-only
ClassMethod NavItems() As %List [ ServerOnly = 1 ]
{
	quit $lb(
		"|portal|Home|SysPerf.UI.Portal.cls|",
		"SystemPerformance|home|Trends Dashboard|SysPerf.UI.Home.cls|",
		"SystemPerformance|runs|Runs|SysPerf.UI.Runs.cls|",
		"SystemPerformance|compare|Compare Runs|SysPerf.UI.Compare.cls|",
		"SystemPerformance|load|Load SystemPerformance Files|SysPerf.UI.Upload.cls|",
		"PERFMON|pm-home|Collections|SysPerf.UI.PMHome.cls|",
		"PERFMON|pm-collect|Run Collection|SysPerf.UI.PMHome.cls?tab=collect|",
		"PERFMON|pm-load|Load PERFMON Files|SysPerf.UI.PMLoad.cls|",
		"System Operation|live|System Dashboard|SysPerf.UI.Live.cls|",
		"System Operation|ops-processes|Processes|SysPerf.UI.Ops.cls?v=processes|",
		"System Operation|ops-locks|Locks|SysPerf.UI.Ops.cls?v=locks|",
		"System Operation|ops-databases|Databases|SysPerf.UI.Ops.cls?v=databases|",
		"System Operation|ops-journals|Journals|SysPerf.UI.Ops.cls?v=journals|",
		"System Operation|ops-mirror|Mirror Monitor|SysPerf.UI.Ops.cls?v=mirror|",
		"System Operation|ops-tasks|Task Manager|SysPerf.UI.Ops.cls?v=tasks|",
		"System Operation|ops-logs|System Logs|SysPerf.UI.Ops.cls?v=logs|",
		"System Operation|ops-apperrors|Application Error Log|SysPerf.UI.Ops.cls?v=apperrors|",
		"System Operation|ops-license|License Usage|SysPerf.UI.Ops.cls?v=license|",
		"Interoperability|int-productions|Productions|SysPerf.UI.Interop.cls?v=productions|",
		"Interoperability|int-queues|Queues|SysPerf.UI.Interop.cls?v=queues|",
		"Interoperability|int-events|Event Log|SysPerf.UI.Interop.cls?v=events|",
		"Administration|admin|Settings & Thresholds|SysPerf.UI.Admin.cls|1")
}

ClassMethod Header() [ ServerOnly = 1 ]
{
	set tV=..#VERSION,tNav=..NavId(),tAdmin=..IsAdmin()
	write "<!doctype html>",!,"<html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>",!
	write "<title>",..H(..Title()),"</title>",!
	write "<link rel='stylesheet' href='SysPerf.UI.Assets.cls?f=app.css&amp;v=",tV,"'>",!
	write "<script>window.SP_CFG={data:'SysPerf.UI.Data.cls',live:'SysPerf.UI.LiveData.cls',pm:'SysPerf.UI.PMData.cls',runPage:'SysPerf.UI.Run.cls',csrf:",..JSON(..CSRF()),",admin:",$s(tAdmin:"true",1:"false"),"};",!
	write "(function(){try{var t=localStorage.getItem('sysperf.theme');if(t)document.documentElement.setAttribute('data-theme',t);}catch(e){}})();</script>",!
	write "<script src='SysPerf.UI.Assets.cls?f=app.js&amp;v=",tV,"'></script>",!
	write "</head><body class='pt'>",!
	// ---- top bar
	set tInst=##class(%SYS.System).GetInstanceName(),tHost=$system.INetInfo.LocalHostName()
	write "<header class='pt-top'>"
	write "<button class='pt-burger' id='navBtn' type='button' aria-label='Menu' aria-controls='ptSide'>&#9776;</button>"
	write "<a class='pt-brand' href='SysPerf.UI.Portal.cls'><svg viewBox='0 0 24 24' aria-hidden='true'><rect x='2' y='13' width='4' height='8' rx='1' fill='var(--s1)'/><rect x='8' y='8' width='4' height='13' rx='1' fill='var(--s3)'/><rect x='14' y='4' width='4' height='17' rx='1' fill='var(--s2)'/><rect x='20' y='10' width='2' height='11' rx='1' fill='var(--s7)'/></svg><span>IRIS Operations Portal</span></a>"
	write "<span class='pt-inst' title='Instance on this server'><b>",..H(tInst),"</b> on ",..H(tHost)," · IRIS ",..H($system.Version.GetNumber()),"</span>"
	write "<span class='pt-chips' id='ptChips'></span>"
	write "<span class='sp-spacer'></span>"
	write "<span class='sp-user'>",..H($username),"</span>"
	write "<button id='themeBtn' class='sp-icon-btn' type='button' title='Toggle light / dark'>&#9680;</button>"
	write "</header>",!
	// ---- sidebar
	write "<div class='pt-wrap'><nav class='pt-side' id='ptSide' aria-label='Portal navigation'>"
	set tItems=..NavItems(),tGroup=$c(0)
	for i=1:1:$ll(tItems) {
		set it=$li(tItems,i),g=$p(it,"|",1),id=$p(it,"|",2)
		continue:($p(it,"|",5)=1)&&('tAdmin)
		if g'=tGroup {
			write:tGroup'=$c(0) "</div>"
			write "<div class='pt-grp'>" write:g'="" "<div class='pt-gh'>",..H(g),"</div>"
			set tGroup=g
		}
		write "<a href='",$p(it,"|",4),"'",$s(id=tNav:" class='on' aria-current='page'",1:""),">",..H($p(it,"|",3)),"</a>"
	}
	write "</div><div class='pt-side-foot'>SysPerf ",tV,"<br>",..H($namespace),"</div></nav>",!
	write "<main class='sp-main pt-main'>",!
	set tFlash=$g(%session.Data("SysPerf.flash"))
	if tFlash'="" {
		kill %session.Data("SysPerf.flash")
		write "<div class='notice ",$case($p(tFlash,"|",1),"err":"err","ok":"ok",:""),"'>",..H($p(tFlash,"|",2,*)),"</div>",!
	}
}

ClassMethod Footer() [ ServerOnly = 1 ]
{
	write !,"<footer class='muted small pt-foot'>IRIS Operations Portal · SysPerf ",..#VERSION," · ",$zdt($h,3),"</footer></main></div>"
	write "<script>SP.portalChrome&&SP.portalChrome();</script></body></html>"
}

// ------------------------------------------------------------ helpers

/// Write the page script (XData "Script" of the concrete page class)
ClassMethod WriteScript(pXData As %String = "Script") [ ServerOnly = 1 ]
{
	set tXD=##class(%Dictionary.CompiledXData).%OpenId($classname()_"||"_pXData,0)
	quit:'$isobject(tXD)
	write "<script>",!
	while 'tXD.Data.AtEnd {
		set tL=tXD.Data.ReadLine()
		if $e(tL)=$c(9) set tL=$e(tL,2,*)
		write tL,!
	}
	write "</script>",!
}

/// HTML escape
ClassMethod H(pText As %String) As %String [ CodeMode = expression, ServerOnly = 1 ]
{
$zcvt(pText,"O","HTML")
}

/// JSON string literal (with quotes) - safe inside <script>
ClassMethod JSON(pText As %String) As %String [ ServerOnly = 1 ]
{
	set t=""""_$zcvt(pText,"O","JSON")_""""
	// never allow </script> to terminate the script block
	quit $replace($replace(t,"<","<"),">",">")
}

ClassMethod IsAdmin() As %Boolean [ ServerOnly = 1 ]
{
	quit $system.Security.Check("SysPerf_Admin","USE")||$system.Security.Check("%Admin_Manage","USE")
}

ClassMethod CSRF() As %String [ ServerOnly = 1 ]
{
	if $g(%session.Data("SysPerf.csrf"))="" {
		set tB=$system.Encryption.GenCryptRand(24),tH=""
		for i=1:1:$l(tB) set tH=tH_$tr($j($zhex($a(tB,i)),2)," ","0")
		set %session.Data("SysPerf.csrf")=$zcvt(tH,"L")
	}
	quit %session.Data("SysPerf.csrf")
}

ClassMethod CheckCSRF() As %Boolean [ ServerOnly = 1 ]
{
	set tTok=$g(%request.Data("csrf",1))
	if tTok="" set tTok=%request.GetCgiEnv("HTTP_X_CSRF_TOKEN")
	quit (tTok'="")&&(tTok=$g(%session.Data("SysPerf.csrf")))
}

/// Request parameter
ClassMethod P(pName As %String, pDefault As %String = "") As %String [ CodeMode = expression, ServerOnly = 1 ]
{
$g(%request.Data(pName,1),pDefault)
}

ClassMethod Flash(pType As %String, pText As %String) [ ServerOnly = 1 ]
{
	set %session.Data("SysPerf.flash")=pType_"|"_pText
}

/// Reply to a POST with JSON (written by OnPage instead of the HTML page)
ClassMethod ReplyJSON(pObj As %DynamicObject) [ ServerOnly = 1 ]
{
	set %response.ContentType="application/json"
	set %SysPerfReply=pObj
}

ClassMethod RequireAdmin() As %Boolean [ ServerOnly = 1 ]
{
	if '..IsAdmin() {
		set %response.Status="403 Forbidden"
		quit 0
	}
	quit 1
}

}
