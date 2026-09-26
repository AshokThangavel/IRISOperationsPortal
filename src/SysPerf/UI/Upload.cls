/// Load ^SystemPerformance HTML reports: upload, scan the inbox folder on demand and follow the load log.
/// SysPerf.UI.PMLoad extends this page for PERFMON reports (parameter KIND).
Class SysPerf.UI.Upload Extends SysPerf.UI.Base
{

Parameter NAVID = "load";

Parameter PAGETITLE = "Load SystemPerformance Files - IRIS Operations Portal";

/// SystemPerformance | PERFMON
Parameter KIND = "SystemPerformance";

ClassMethod OnPost() [ ServerOnly = 1 ]
{
	set %response.Redirect=$classname()_".cls"
	if '..IsAdmin() { do ..Flash("err","Loading reports requires the SysPerfAdmin role.") quit }
	set tOp=..P("op")
	if tOp="scan" {
		job ##class(SysPerf.Loader).BackgroundInbox()::5
		do ..Flash($s($test:"ok",1:"err"),$s($test:"Inbox scan started in the background - files appear in the log below.",1:"Could not start the background job."))
		quit
	}
	if tOp="upload" {
		set tForce=(..P("force")="1"),(tN,tErr)=0,tMsg=""
		set i=""
		for {
			set i=$o(%request.MimeData("file",i)) quit:i=""
			set tStream=%request.MimeData("file",i)
			continue:'$isobject(tStream)
			set tName=tStream.FileName
			continue:tName=""
			set tSC=##class(SysPerf.Loader).LoadUpload(tStream,tName,tForce,.tLogId,.tRunId,..#KIND)
			if $$$ISERR(tSC) { set tErr=tErr+1,tMsg=tMsg_" "_tName_": "_$system.Status.GetErrorText(tSC) } else { set tN=tN+1 }
		}
		if 'tN,'tErr { do ..Flash("err","No file received. Choose one or more .html reports.") quit }
		do ..Flash($s(tErr:"err",1:"ok"),$s(tN:tN_" file(s) queued for loading. ",1:"")_$s(tErr:"Rejected:"_tMsg,1:"Progress is shown below."))
	}
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set tSet=##class(SysPerf.Config.Settings).Get(),tAdmin=..IsAdmin(),tCsrf=..H(..CSRF()),tPM=(..#KIND="PERFMON")
	set tKindLabel=$s(tPM:"PERFMON",1:"SystemPerformance")
	set tPattern=..H($s(tPM:"PERFMON_<config>_<date>_<time>.html",1:"<host>_<instance>_<date>_<time>_<profile>.html · pButtons"))
	set tTerm=..H($s(tPM:"do ##class(SysPerf.PM.Loader).LoadFile(""D:\perf\PERFMON_x.html"",.collId)",1:"do ##class(SysPerf.Loader).LoadFile(""D:\perf\report.html"",.runId)"))
	if tPM {
		&html<<h1>Load PERFMON Files</h1><p class="sub">Load PERFMON timed-collection HTML reports (PERFMON_*.html) from any server into the PERFMON tables. Identical files and already loaded collections are skipped. To collect on this instance instead, use <a href="SysPerf.UI.PMHome.cls?tab=collect">Run Collection</a>.</p>>
	} else {
		&html<<h1>Load SystemPerformance Files</h1><p class="sub">Load ^SystemPerformance (or ^pButtons) HTML reports into the analytics tables. Identical files and already loaded runs are skipped.</p>>
	}
	&html<<div class="grid g2">>
	if tAdmin {
		&html<
  <div class="card">
    <h2>Upload</h2>
    <form method="post" enctype="multipart/form-data" id="upForm">
      <input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="upload">
      <div class="drop" id="drop">
        <p><b>Drop #(tKindLabel)# report files here</b> or</p>
        <input type="file" name="file" id="file" accept=".html,.htm" multiple>
        <p class="muted small">#(tPattern)#</p>
        <p class="muted small" id="picked">Max #(tSet.MaxUploadMB)# MB per file · files load in the background</p>
      </div>
      <div class="flex" style="margin-top:10px">
        <label class="small"><input type="checkbox" name="force" value="1"> Reload even if already loaded</label>
        <button class="btn primary right" type="submit" id="upBtn">Upload and load</button>
      </div>
    </form>
  </div>
  <div class="card">
    <h2>Inbox folder</h2>
    <dl class="kv"><dt>Inbox</dt><dd class="mono">#(..H(tSet.InboxDir))#</dd><dt>Archive</dt><dd class="mono">#(..H(tSet.ArchiveDir))#</dd><dt>Error</dt><dd class="mono">#(..H(tSet.ErrorDir))#</dd><dt>File pattern</dt><dd>#(..H(tSet.FilePattern))#</dd><dt>Last scan</dt><dd>#(..H(tSet.LastScanTS))#</dd></dl>
    <p class="small">The inbox is shared by SystemPerformance and PERFMON reports; each file is recognised from its contents. The Task Manager job <b>SysPerf load reports</b> loads the inbox daily; loaded files move to Archive, failures to Error.</p>
    <form method="post"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="scan"><button class="btn" type="submit">Scan inbox now</button></form>
    <div class="sep"></div>
    <p class="small muted">From a terminal:<br><span class="mono">#(tTerm)#</span><br><span class="mono">do ##class(SysPerf.Loader).LoadDirectory("D:\perf",1,.summary) write summary</span></p>
  </div>>
	} else {
		&html<<div class="card"><h2>Upload</h2><p>Uploading requires the <b>SysPerfAdmin</b> role. Ask an administrator, or place files in the inbox folder.</p></div>>
	}
	&html<</div>
<div class="card section"><div class="card-h"><h2>Load log</h2><span class="muted small" id="logInfo"></span></div><div id="log" data-kind="#(..#KIND)#"></div></div>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, tbl = null, timer = null;
	  function load() {
	    SP.api('loadlog', { kind: $('#log').getAttribute('data-kind') }).then(function (j) {
	      var busy = j.rows.some(function (r) { return r.Status === 'Queued' || r.Status === 'Running'; });
	      $('#logInfo').textContent = busy ? 'Loading… refreshes every 3 s' : 'Last 200 load attempts';
	      if (!tbl) tbl = SP.table($('#log'), { rows: j.rows, page: 25, csv: 'loadlog', columns: [
	        { k: 'id', l: 'ID', num: true, dec: 0 }, { k: 'StartTS', l: 'Started' }, { k: 'FileName', l: 'File' }, { k: 'Origin', l: 'Origin' },
	        { k: 'Status', l: 'Status', render: function (v) { var sev = v === 'OK' ? 'OK' : v === 'Error' ? 'C' : v === 'Skipped' ? 'I' : 'W'; var b = SP.badge(sev); b.lastChild.textContent = v; return b; } },
	        { k: 'Seconds', l: 'Seconds', num: true }, { k: 'RowsLoaded', l: 'Rows', num: true },
	        { k: 'RunID', l: 'Result', render: function (v, r) { return v ? SP.el('a', { href: (r.Kind === 'PERFMON' ? 'SysPerf.UI.PMRun.cls?id=' : 'SysPerf.UI.Run.cls?id=') + v, text: 'open #' + v }) : ''; } },
	        { k: 'Message', l: 'Message', cls: 'wrap' }, { k: 'UserName', l: 'User' }] });
	      else tbl.set(j.rows);
	      clearTimeout(timer);
	      if (busy) timer = setTimeout(load, 3000);
	    }).catch(function (e) { SP.fail($('#log'), e); });
	  }
	  document.addEventListener('DOMContentLoaded', function () {
	    load();
	    var drop = $('#drop'), file = $('#file');
	    if (!drop) return;
	    function show() { var n = file.files.length; $('#picked').textContent = n ? n + ' file(s): ' + Array.prototype.map.call(file.files, function (f) { return f.name + ' (' + SP.fmt(f.size / 1048576, 1) + ' MB)'; }).join(', ') : ''; }
	    file.addEventListener('change', show);
	    ['dragenter', 'dragover'].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add('over'); }); });
	    ['dragleave', 'drop'].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.remove('over'); }); });
	    drop.addEventListener('drop', function (e) { if (e.dataTransfer && e.dataTransfer.files.length) { file.files = e.dataTransfer.files; show(); } });
	    $('#upForm').addEventListener('submit', function () { $('#upBtn').disabled = true; $('#upBtn').textContent = 'Uploading…'; });
	  });
	})();
}

}
