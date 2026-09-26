/// Run detail: every piece of one ^SystemPerformance report - findings with recommendations,
/// mgstat, OS, disks, processes, IRIS jobs, resource contention, databases, CPF, system info,
/// OS processes, routine buffers, raw OS counters and the raw report text.
Class SysPerf.UI.Run Extends SysPerf.UI.Base
{

Parameter NAVID = "runs";

Parameter PAGETITLE = "Run - IRIS Operations Portal";

ClassMethod OnPost() [ ServerOnly = 1 ]
{
	set tOp=..P("op"),tId=..P("id")
	if tOp="ack" {
		set tF=..P("finding")
		if tF'?1.N do ..ReplyJSON({"error":"bad finding"}) quit
		if '..IsAdmin() do ..ReplyJSON({"error":"Acknowledging requires the SysPerfAdmin role"}) quit
		set tObj=##class(SysPerf.Data.Finding).%OpenId(tF)
		if '$isobject(tObj) do ..ReplyJSON({"error":"not found"}) quit
		set tObj.Acknowledged=1,tObj.AckBy=$username,tObj.AckTS=$zdt($h,3),tObj.AckNote=$e(..P("note"),1,4000)
		set tSC=tObj.%Save()
		do ..ReplyJSON($s($$$ISOK(tSC):{"ok":1},1:{"error":($system.Status.GetErrorText(tSC))}))
		quit
	}
	if tId'?1.N quit
	set tBack="SysPerf.UI.Run.cls?id="_tId
	if '..IsAdmin() { do ..Flash("err","This action requires the SysPerfAdmin role.") set %response.Redirect=tBack quit }
	if tOp="notes" {
		set tRun=##class(SysPerf.Data.Run).%OpenId(tId)
		if $isobject(tRun) set tRun.Notes=$e(..P("notes"),1,32000) do tRun.%Save() do ..Flash("ok","Notes saved.")
		set %response.Redirect=tBack
	} elseif tOp="reanalyze" {
		set tSC=##class(SysPerf.Loader).Reanalyze(tId)
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):"Run re-analysed with the current thresholds.",1:$system.Status.GetErrorText(tSC)))
		set %response.Redirect=tBack
	} elseif tOp="delete" {
		set tSC=##class(SysPerf.Data.Run).Purge(tId)
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):"Run "_tId_" deleted.",1:$system.Status.GetErrorText(tSC)))
		set %response.Redirect=$s($$$ISOK(tSC):"SysPerf.UI.Runs.cls",1:tBack)
	}
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set tId=..P("id")
	if (tId'?1.N)||'##class(SysPerf.Data.Run).%ExistsId(tId) {
		write "<div class='notice err'>Run not found. <a href='SysPerf.UI.Runs.cls'>Back to runs</a></div>"
		quit $$$OK
	}
	set tCsrf=..H(..CSRF()),tAdmin=..IsAdmin()
	&html<
<div class="flex" style="align-items:flex-start">
  <div style="min-width:0;flex:1">
    <div class="muted small"><a href="SysPerf.UI.Runs.cls">Runs</a> / <span id="crumb"></span></div>
    <h1 id="title">Run #(tId)#</h1>
    <div class="meta" id="meta"></div>
  </div>
  <div class="flex" id="headTools"></div>
</div>
<div id="errs"></div>
<div class="tabs" id="tabs" role="tablist">
  <button data-tab="findings">Findings<span class="cnt" id="cntF"></span></button>
  <button data-tab="summary">System</button>
  <button data-tab="mgstat">IRIS (mgstat)</button>
  <button data-tab="os">OS</button>
  <button data-tab="disk">Disks</button>
  <button data-tab="process">Processes</button>
  <button data-tab="jobs">IRIS jobs</button>
  <button data-tab="resource">Contention</button>
  <button data-tab="db">Databases</button>
  <button data-tab="config">Configuration</button>
  <button data-tab="kv">All details</button>
  <button data-tab="osproc">OS processes</button>
  <button data-tab="rtn">Routine buffers</button>
  <button data-tab="raw">Raw OS counters</button>
  <button data-tab="report">Report text</button>
</div>
<section class="tabpane" id="tab-findings">
  <div class="flex" style="margin-bottom:10px"><span id="fSev"></span><span class="muted small" id="fNote"></span></div>
  <div id="findings"></div>
</section>
<section class="tabpane" id="tab-summary">
  <div class="grid g2">
    <div class="card"><h2>Instance</h2><dl class="kv" id="sumInst"></dl></div>
    <div class="card"><h2>Server</h2><dl class="kv" id="sumSrv"></dl></div>
    <div class="card"><h2>Collection</h2><dl class="kv" id="sumCol"></dl></div>
    <div class="card"><h2>Notes</h2><div id="notesBox"></div></div>
  </div>
</section>
<section class="tabpane" id="tab-mgstat">
  <div class="card"><div class="card-h"><h2>mgstat charts</h2><span class="muted small">one chart per counter · tick counters in the table to add charts</span></div><div class="grid g2" id="mgCharts"></div></div>
  <div class="card section"><h2>Statistics of every mgstat counter</h2><div id="mgStats"></div></div>
  <div class="card section"><h2>All mgstat samples</h2><div id="mgRows"></div></div>
</section>
<section class="tabpane" id="tab-os">
  <div class="sp-filters"><label>Source<select id="osSrc"></select></label></div>
  <div class="grid g2" id="osCharts"></div>
  <div class="card section"><h2>Statistics</h2><div id="osStats"></div></div>
</section>
<section class="tabpane" id="tab-disk">
  <div class="sp-filters"><label>Source<select id="dkSrc"></select></label><label>Metric<select id="dkMetric"></select></label></div>
  <div class="card"><div id="dkChart"></div></div>
  <div class="card section"><h2>Per device averages</h2><div id="dkTable"></div></div>
</section>
<section class="tabpane" id="tab-process">
  <div class="grid g2">
    <div class="card"><h2>Busiest processes (global references between first and last %SS sample)</h2><div id="pdChart"></div></div>
    <div class="card"><h2>Busiest processes (commands executed)</h2><div id="pdChart2"></div></div>
  </div>
  <div class="card section"><h2>Process activity during the run</h2><div id="pdTable"></div></div>
  <div class="card section"><div class="card-h"><h2>%SS snapshot</h2><label class="small">Sample <select id="ssSample"></select></label></div><div id="ssTable"></div></div>
</section>
<section class="tabpane" id="tab-jobs">
  <div class="card"><div class="card-h"><h2>IRIS jobs (irisstat -c1 PIDTAB)</h2><label class="small">Sample <select id="jbSample"></select></label></div>
  <div class="grid g2"><div id="jbChart"></div><div id="jbState"></div></div></div>
  <div class="card section"><div id="jbTable"></div></div>
</section>
<section class="tabpane" id="tab-resource">
  <div class="card"><div class="card-h"><h2>Resource seizes per second (irisstat -D)</h2><span class="muted small">top resources · contention shows as Nseize/Aseize/Bseize %</span></div><div id="rsChart"></div></div>
  <div class="card section"><div class="card-h"><h2>Resource table</h2><label class="small">Sample <select id="rsSample"></select></label></div><div id="rsTable"></div></div>
</section>
<section class="tabpane" id="tab-db">
  <div class="card"><div class="card-h"><h2>Database sizes</h2><label class="small">Sample <select id="dbSample"></select></label></div><div id="dbChart"></div></div>
  <div class="card section"><div id="dbTable"></div></div>
</section>
<section class="tabpane" id="tab-config">
  <div class="card"><div class="card-h"><h2>Key configuration</h2></div><dl class="kv" id="cfgKey"></dl></div>
  <div class="card section"><div class="card-h"><h2>CPF file</h2><label class="small">Section <select id="cfgSec"><option value="">All sections</option></select></label></div><div id="cfgTable"></div></div>
</section>
<section class="tabpane" id="tab-kv">
  <div class="card"><div class="card-h"><h2>Every scalar detail extracted from the report</h2><label class="small">Section <select id="kvSec"><option value="">All sections</option></select></label></div>
  <p class="muted small">Configuration, profile, license, OS / hardware info, lscpu, sysctl, irisstat counters (write daemon, journal, routine, global counters, error log) and more.</p><div id="kvTable"></div></div>
</section>
<section class="tabpane" id="tab-osproc">
  <div class="card"><div class="card-h"><h2>OS processes</h2><div class="card-tools"><label class="small"><input type="checkbox" id="opIris"> IRIS processes only</label><label class="small">Sample <select id="opSample"></select></label></div></div><div id="opChart"></div><div id="opTable"></div></div>
</section>
<section class="tabpane" id="tab-rtn">
  <div class="card"><h2>Routine buffers in use (irisstat -R)</h2><div id="rtnTable"></div></div>
</section>
<section class="tabpane" id="tab-raw">
  <div class="sp-filters"><label>Source<select id="rwSrc"></select></label><label id="rwEntL" class="hide">Device / CPU<select id="rwEnt"></select></label><label>Find counter<input type="search" id="rwFind" placeholder="e.g. Disk sec/Read"></label></div>
  <div class="checks" id="rwCols"></div>
  <div class="card section"><div id="rwChart"></div></div>
</section>
<section class="tabpane" id="tab-report">
  <div class="grid" style="grid-template-columns:minmax(220px,300px) minmax(0,1fr)">
    <div class="card"><h2>Sections</h2><div id="secList"></div></div>
    <div class="card"><div class="card-h"><h2 id="secTitle">Select a section</h2><label class="small">Sample <select id="secSample"></select></label></div><div id="secText" class="raw">Choose a section on the left to see its original text.</div></div>
  </div>
</section>
<form id="adminForm" method="post" class="hide"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="id" value="#(tId)#"><input type="hidden" name="op" id="adminOp"><textarea name="notes" id="adminNotes"></textarea></form>
<script>window.SP_RUN={id:#(+tId)#,admin:#($s(tAdmin:"true",1:"false"))#};</script>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, R = window.SP_RUN, ID = R.id, RUN = null, SRC = null, TABS = null;
	  var MG_DEFAULT = ['Glorefs', 'PhyRds', 'Gloupds', 'PhyWrs', 'CacheHitPct', 'RouLaS', 'Jrnwrts', 'WDQsz'];
	  var MG_UNITS = { CacheHitPct: '%', WDQsz: 'blocks', WDphase: 'phase', ActECP: 'conns', GblSz: '', WDpass: '' };
	  var mgSel = {};
	  var OSLAB = { CPUBusyPct: 'busy', CPUUserPct: 'user', CPUSysPct: 'system', CPUIOWaitPct: 'I/O wait', CPUStealPct: 'steal', CPUMaxCorePct: 'busiest core', RunQueue: 'run queue', ProcsBlocked: 'blocked', MemAvailMB: 'available', MemFreeMB: 'free', MemCacheMB: 'cache', SwapUsedMB: 'swap used', MemCommitPct: 'committed', PagingFilePct: 'paging file', PageInPerSec: 'page in', PageOutPerSec: 'page out', SwapInPerSec: 'swap in', SwapOutPerSec: 'swap out', ContextSwPerSec: 'context sw', InterruptsPerSec: 'interrupts', BlocksInPerSec: 'blocks in', BlocksOutPerSec: 'blocks out', NetRxKBPerSec: 'received', NetTxKBPerSec: 'sent', DiskMaxReadLatMs: 'read', DiskMaxWriteLatMs: 'write', DiskTotalIOPS: 'IOPS', ProcessCount: 'processes' };

	  function kv(host, pairs) {
	    SP.clear(host);
	    pairs.forEach(function (p) { if (p[1] === '' || p[1] == null) return; host.appendChild(SP.el('dt', { text: p[0] })); host.appendChild(SP.el('dd', { text: String(p[1]) })); });
	  }
	  function opt(sel, v, t) { sel.appendChild(SP.el('option', { value: v, text: t })); }
	  function tsPts(s) { return s.pts.map(function (p) { return [SP.ts(p[0]), p[1]]; }); }
	  function bandPts(s) { return (s.band || []).map(function (p) { return [SP.ts(p[0]), p[1], p[2]]; }); }
	  function cardChart(host, title, sub) {
	    var c = SP.el('div', { cls: 'card' }, [SP.el('div', { cls: 'card-h' }, [SP.el('h2', { text: title }), sub ? SP.el('span', { cls: 'muted small', text: sub }) : null])]);
	    var ch = SP.el('div'); c.appendChild(ch); host.appendChild(c); return ch;
	  }
	  function adminPost(op, notes) { $('#adminOp').value = op; if (notes != null) $('#adminNotes').value = notes; $('#adminForm').submit(); }

	  /* ---------------------------------------------------------------- header */
	  function header() {
	    return SP.api('run', { id: ID }).then(function (r) {
	      RUN = r;
	      document.title = r.SystemName + ' ' + r.RunId + ' - SysPerf';
	      $('#crumb').textContent = r.SystemName;
	      $('#title').textContent = r.SystemName + ' — ' + (r.StartTS || '').slice(0, 16);
	      var m = SP.clear($('#meta'));
	      function mi(label, val) { if (val === '' || val == null) return; m.appendChild(SP.el('span', {}, [label + ' ', SP.el('b', { text: String(val) })])); }
	      m.appendChild(SP.score(r.HealthScore));
	      mi('Critical', r.CriticalCount); mi('Warnings', r.WarningCount);
	      mi('Period', (r.StartTS || '') + ' → ' + ((r.EndTS || '').slice(11)));
	      mi('Duration', dur(r.DurationSec)); mi('Interval', r.IntervalSec != null ? r.IntervalSec + ' s' : '');
	      mi('Profile', r.ProfileName); mi('IRIS', r.IRISVersion); mi('Platform', r.Platform);
	      var t = SP.clear($('#headTools'));
	      if (r.prevId) t.appendChild(SP.el('a', { cls: 'btn sm', href: 'SysPerf.UI.Run.cls?id=' + r.prevId, text: '‹ Previous run' }));
	      if (r.nextId) t.appendChild(SP.el('a', { cls: 'btn sm', href: 'SysPerf.UI.Run.cls?id=' + r.nextId, text: 'Next run ›' }));
	      if (r.prevId) t.appendChild(SP.el('a', { cls: 'btn sm', href: 'SysPerf.UI.Compare.cls?a=' + r.prevId + '&b=' + ID, text: 'Compare with previous' }));
	      t.appendChild(SP.el('button', { cls: 'btn sm', text: 'Print / PDF', onclick: function () { window.print(); } }));
	      if (R.admin) {
	        t.appendChild(SP.el('button', { cls: 'btn sm', text: 'Re-analyse', title: 'Re-run the rules with the current thresholds', onclick: function () { adminPost('reanalyze'); } }));
	        t.appendChild(SP.el('button', { cls: 'btn sm danger', text: 'Delete run', onclick: function () { if (confirm('Delete this run and all of its data?')) adminPost('delete'); } }));
	      }
	      var e = SP.clear($('#errs'));
	      if (r.CollectionErrors) e.appendChild(SP.el('div', { cls: 'notice warn', text: 'Collector problem during this run: ' + r.CollectionErrors }));
	      if (r.StatusText) e.appendChild(SP.el('div', { cls: 'notice warn', text: 'Parser warnings: ' + r.StatusText }));
	    });
	  }
	  function dur(s) { if (s == null) return ''; var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60; return (h ? h + 'h ' : '') + (h || m ? m + 'm ' : '') + (h ? '' : x + 's'); }

	  /* ---------------------------------------------------------------- tabs */
	  var loaders = {
	    findings: function () {
	      SP.api('runfindings', { id: ID }).then(function (j) {
	        var all = j.findings, sev = 'problems';
	        var cnt = all.filter(function (f) { return f.sev === 'C' || f.sev === 'W'; }).length;
	        $('#cntF').textContent = cnt ? cnt : '';
	        function show() {
	          var list = all.filter(function (f) { return sev === 'all' ? true : sev === 'problems' ? f.sev !== 'OK' : f.sev === sev; });
	          SP.findings($('#findings'), list, { canAck: R.admin, openWarn: true, onDrill: function (t) { TABS.show(t === 'iris' ? 'kv' : t === 'license' ? 'kv' : t, true); } });
	        }
	        SP.seg($('#fSev'), [{ v: 'problems', l: 'Problems (' + all.filter(function (f) { return f.sev !== 'OK'; }).length + ')' }, { v: 'C', l: 'Critical' }, { v: 'W', l: 'Warning' }, { v: 'I', l: 'Info' }, { v: 'OK', l: 'Passed checks (' + all.filter(function (f) { return f.sev === 'OK'; }).length + ')' }, { v: 'all', l: 'All' }], sev, function (v) { sev = v; show(); });
	        $('#fNote').textContent = 'Thresholds are editable on the Admin page; re-analyse to apply.';
	        show();
	      }).catch(function (e) { SP.fail($('#findings'), e); });
	    },
	    summary: function () {
	      var r = RUN;
	      kv($('#sumInst'), [['System', r.SystemName], ['Instance', r.Instance], ['Product', r.ProductVersion], ['IRIS version', r.IRISVersion], ['Directory', r.InstanceDirectory], ['Superserver port', r.SuperServerPort], ['GUID', r.InstanceGUID], ['Customer / license', r.Customer], ['Global buffers', r.GlobalBuffersMB != null ? SP.fmt(r.GlobalBuffersMB) + ' MB' : ''], ['Routine buffers', r.RoutineBuffersMB != null ? SP.fmt(r.RoutineBuffersMB) + ' MB' : ''], ['Block size', r.BlockSize], ['Large pages', r.LargePages === '' ? 'unknown' : (r.LargePages == 1 ? 'yes' : 'no')], ['Write daemon cycle', r.WDCycle], ['mgstat version', r.MgstatVersion]]);
	      kv($('#sumSrv'), [['Host', r.Host], ['OS', r.OSName], ['OS version', r.OSVersion], ['CPUs', r.NumCPU], ['CPU model', r.CPUModel], ['Physical memory', r.TotalMemoryMB != null ? SP.fmt(r.TotalMemoryMB) + ' MB' : ''], ['Available at collection', r.AvailableMemoryMB != null ? SP.fmt(r.AvailableMemoryMB) + ' MB' : ''], ['Virtual machine', r.IsVirtual ? 'yes (' + (r.Hypervisor || '') + ')' : 'no / unknown'], ['Boot time', r.BootTime]]);
	      kv($('#sumCol'), [['Run id', r.RunId], ['Profile', r.ProfileName], ['Started by', r.StartedBy], ['Start', r.StartTS], ['End', r.EndTS], ['Duration', dur(r.DurationSec)], ['Interval', r.IntervalSec + ' s'], ['Samples', r.SampleCount], ['Perfmon definition', r.PerfmonDefinition], ['Output directory', r.LogDirectory], ['Sections', r.SectionList], ['Source file', r.SourceFile], ['File size', r.FileSize != null ? SP.fmt(r.FileSize / 1048576, 1) + ' MB' : ''], ['SHA-256', r.FileHash], ['Loaded', r.LoadedTS + ' by ' + r.LoadedBy + ' in ' + SP.fmt(r.LoadSeconds, 1) + ' s'], ['Analysed', r.AnalyzedTS]]);
	      var nb = SP.clear($('#notesBox'));
	      if (R.admin) {
	        var ta = SP.el('textarea', { rows: 6, 'aria-label': 'Notes' }); ta.value = r.Notes || '';
	        nb.appendChild(ta); nb.appendChild(SP.el('div', { style: 'margin-top:8px' }, [SP.el('button', { cls: 'btn primary sm', text: 'Save notes', onclick: function () { adminPost('notes', ta.value); } })]));
	      } else nb.appendChild(SP.el('div', { cls: 'rec', text: r.Notes || 'No notes.' }));
	    },
	    mgstat: function () {
	      MG_DEFAULT.forEach(function (c) { mgSel[c] = true; });
	      SP.api('rstats', { id: ID, t: 'Mgstat' }).then(function (j) {
	        SP.table($('#mgStats'), {
	          rows: j.stats, page: 60, csv: 'mgstat_stats_' + ID, columns: [
	            { k: 'col', l: 'Chart', nosort: true, render: function (v) { var cb = SP.el('input', { type: 'checkbox', 'aria-label': 'Chart ' + v }); cb.checked = !!mgSel[v]; cb.addEventListener('change', function () { mgSel[v] = cb.checked; mgCharts(); }); return cb; } },
	            { k: 'col', l: 'Counter' }, { k: 'desc', l: 'Meaning', cls: 'wrap' }, { k: 'avg', l: 'Avg', num: true }, { k: 'p95', l: 'P95', num: true }, { k: 'max', l: 'Max', num: true }, { k: 'min', l: 'Min', num: true }, { k: 'maxTS', l: 'Max at' }]
	        });
	      });
	      mgCharts();
	      var box = SP.clear($('#mgRows'));
	      box.appendChild(SP.el('p', { cls: 'small', text: (RUN.SampleCount || 0) + ' samples. Download every column of every sample, or load them into a table here (large runs can be slow in the browser).' }));
	      box.appendChild(SP.el('div', { cls: 'flex' }, [exportBtn('Mgstat', 'Download mgstat (CSV)'), SP.el('button', { cls: 'btn', text: 'Show all samples here', onclick: function (ev) {
	        ev.target.disabled = true; ev.target.textContent = 'Loading…';
	        SP.api('rtable', { id: ID, k: 'mgstat' }).then(function (j) {
	          var cols = j.rows.length ? Object.keys(j.rows[0]).filter(function (k) { return k !== 'Run' && k !== 'ID' && k !== 'Extra'; }) : [];
	          var host = SP.el('div', { style: 'margin-top:10px' }); box.appendChild(host); ev.target.remove();
	          SP.table(host, { rows: j.rows, page: 50, csv: false, columns: cols.map(function (k) { return { k: k, l: k, num: k !== 'SampleTS' }; }) });
	        });
	      } })]));
	    },
	    os: function () {
	      var sel = SP.clear($('#osSrc'));
	      if (!SRC.os.length) { $('#osCharts').appendChild(SP.el('div', { cls: 'notice warn', text: 'No OS time-series in this report (perfmon / vmstat / iostat / sar not collected). See the Findings tab for how to fix the collector.' })); return; }
	      var pref = ['perfmon', 'sar-u', 'vmstat', 'iostat', 'free', 'sar-d'];
	      SRC.os.sort(function (a, b) { return pref.indexOf(a.src) - pref.indexOf(b.src); }).forEach(function (s) { opt(sel, s.src, s.src + ' (' + s.n + ' samples)'); });
	      sel.addEventListener('change', osDraw); osDraw();
	      exportBar($('#tab-os'), [['OSStat', 'Download OS metrics (CSV)'], ['OSSample', 'Download raw OS samples (CSV)']]);
	    },
	    disk: function () {
	      var srcs = {}; SRC.disk.forEach(function (d) { srcs[d.src] = 1; });
	      var sel = SP.clear($('#dkSrc'));
	      Object.keys(srcs).forEach(function (s) { opt(sel, s, s); });
	      if (!sel.options.length) { $('#dkChart').appendChild(SP.el('div', { cls: 'notice warn', text: 'No per-disk data in this report.' })); return; }
	      var ms = SP.clear($('#dkMetric'));
	      [['ReadLatMs', 'Read latency (ms)'], ['WriteLatMs', 'Write latency (ms)'], ['AwaitMs', 'Await (ms)'], ['TransfersPerSec', 'IOPS'], ['ReadsPerSec', 'Reads/s'], ['WritesPerSec', 'Writes/s'], ['ReadKBPerSec', 'Read KB/s'], ['WriteKBPerSec', 'Write KB/s'], ['QueueLen', 'Queue length'], ['UtilPct', 'Utilisation %']].forEach(function (m) { opt(ms, m[0], m[1]); });
	      sel.addEventListener('change', dkDraw); ms.addEventListener('change', dkChart); dkDraw();
	      exportBar($('#tab-disk'), [['DiskStat', 'Download per-disk samples (CSV)']]);
	    },
	    process: function () {
	      exportBar($('#tab-process'), [['Process', 'Download all %SS samples (CSV)'], ['ProcessDelta', 'Download process activity (CSV)']]);
	      SP.api('rtable', { id: ID, k: 'pdelta' }).then(function (j) {
	        var rows = j.rows;
	        SP.barChart($('#pdChart'), { rows: rows.slice(0, 10).map(function (r) { return { label: r.PID + ' ' + (r.Routine || '') + (r.Namespace ? ' [' + r.Namespace + ']' : ''), value: r.GlobDelta, sub: SP.fmt(r.GlobPerSec) + ' glorefs/s · ' + SP.fmt(r.GlobSharePct) + '% · ' + (r.UserLocation || '') }; }), empty: 'Needs at least two %SS samples' });
	        var byCpu = rows.slice().sort(function (a, b) { return b.CPUDelta - a.CPUDelta; });
	        SP.barChart($('#pdChart2'), { rows: byCpu.slice(0, 10).map(function (r) { return { label: r.PID + ' ' + (r.Routine || ''), value: r.CPUDelta, color: 'var(--s2)', sub: SP.fmt(r.CPUPerSec) + ' /s · ' + (r.UserLocation || '') }; }), empty: 'Needs at least two %SS samples' });
	        SP.table($('#pdTable'), { rows: rows, page: 25, csv: 'process_activity_' + ID, columns: [{ k: 'PID', l: 'PID', num: true, dec: 0 }, { k: 'Namespace', l: 'Namespace' }, { k: 'Routine', l: 'Routine' }, { k: 'UserLocation', l: 'User / location' }, { k: 'GlobDelta', l: 'Global refs', num: true }, { k: 'GlobPerSec', l: 'Glorefs/s', num: true }, { k: 'GlobSharePct', l: '% of all', num: true }, { k: 'CPUDelta', l: 'Commands', num: true }, { k: 'CPUPerSec', l: 'Commands/s', num: true }, { k: 'Seconds', l: 'Seconds', num: true }, { k: 'Device', l: 'Device' }] });
	      });
	      sampleSel($('#ssSample'), SRC.ss, function (s) {
	        SP.api('rtable', { id: ID, k: 'process', s: s }).then(function (j) {
	          SP.table($('#ssTable'), { rows: j.rows, page: 100, csv: 'ss_' + ID + '_' + s, sort: { k: 'Glob', dir: 'desc' }, columns: [{ k: 'PID', l: 'PID', num: true, dec: 0 }, { k: 'IsCurrent', l: '*', fmt: function (v) { return v ? '*' : ''; } }, { k: 'Namespace', l: 'Namespace' }, { k: 'Routine', l: 'Routine' }, { k: 'CPU', l: 'Commands', num: true }, { k: 'Glob', l: 'Global refs', num: true }, { k: 'Priority', l: 'Pri', num: true }, { k: 'UserLocation', l: 'User / location' }, { k: 'Device', l: 'Device' }] });
	        });
	      }, true);
	    },
	    jobs: function () {
	      exportBar($('#tab-jobs'), [['IRISJob', 'Download all IRIS job samples (CSV)']]);
	      sampleSel($('#jbSample'), SRC.jobs, function (s) {
	        SP.api('rtable', { id: ID, k: 'jobs', s: s }).then(function (j) {
	          var rows = j.rows;
	          SP.barChart($('#jbChart'), { rows: rows.slice().sort(function (a, b) { return b.PhyRd - a.PhyRd; }).slice(0, 10).filter(function (r) { return r.PhyRd > 0; }).map(function (r) { return { label: r.PID + ' ' + (r.Routine || 'daemon') + (r.Namespace ? ' [' + r.Namespace + ']' : ''), value: r.PhyRd, sub: 'physical reads · state ' + r.PState }; }), empty: 'No physical reads recorded' });
	          var st = {}; rows.forEach(function (r) { st[r.PState] = (st[r.PState] || 0) + 1; });
	          SP.barChart($('#jbState'), { rows: Object.keys(st).sort(function (a, b) { return st[b] - st[a]; }).map(function (k) { return { label: 'state ' + k, value: st[k], color: 'var(--s3)', sub: 'jobs' }; }) });
	          SP.table($('#jbTable'), { rows: rows, page: 100, csv: 'irisjobs_' + ID + '_' + s, columns: [{ k: 'JobNo', l: 'Job', num: true, dec: 0 }, { k: 'PID', l: 'PID', num: true, dec: 0 }, { k: 'PState', l: 'State' }, { k: 'JobType', l: 'Type' }, { k: 'PhyRd', l: 'Phys reads', num: true }, { k: 'LogRd', l: 'Logical reads', num: true }, { k: 'WDQBlk', l: 'WDQ blocks', num: true }, { k: 'Routine', l: 'Routine' }, { k: 'Namespace', l: 'Namespace' }, { k: 'Lines', l: 'Lines', num: true }, { k: 'Glorefs', l: 'Glorefs', num: true }, { k: 'Device', l: 'Device' }, { k: 'ClientIP', l: 'Client IP' }, { k: 'Exe', l: 'Exe' }] });
	        });
	      }, true);
	    },
	    resource: function () {
	      exportBar($('#tab-resource'), [['ResourceStat', 'Download resource statistics (CSV)']]);
	      SP.api('rtable', { id: ID, k: 'resall' }).then(function (j) {
	        var by = {}, tot = {};
	        j.rows.forEach(function (r) { (by[r.ResName] = by[r.ResName] || []).push([SP.ts(r.SampleTS), r.SeizePerSec]); tot[r.ResName] = (tot[r.ResName] || 0) + (r.Seize || 0); });
	        var names = Object.keys(tot).sort(function (a, b) { return tot[b] - tot[a]; }).slice(0, 6).sort();
	        SP.lineChart($('#rsChart'), { series: names.map(function (n, i) { return { name: n, pts: by[n], color: SP.color(i) }; }), unit: 'seizes/s', height: 240, empty: 'No irisstat -D data' });
	      });
	      var samples = SRC.res.map(function (r) { return { s: r.src + '|' + r.s, ts: r.ts, n: r.n, label: (r.src === 'D' ? 'irisstat -D #' : 'irisstat -c1 (cumulative) #') + r.s + ' ' + (r.ts || '') }; });
	      sampleSel($('#rsSample'), samples, function (v) {
	        var p = v.split('|');
	        SP.api('rtable', { id: ID, k: 'res', src: p[0], s: p[1] }).then(function (j) {
	          SP.table($('#rsTable'), { rows: j.rows, page: 60, csv: 'resources_' + ID, rowCls: function (r) { return (r.NSeizePct > 1 || r.ASeizePct > 1 || r.BSeizePct > 1) ? 'hl' : ''; }, columns: [{ k: 'ResNo', l: '#', num: true, dec: 0 }, { k: 'ResName', l: 'Resource' }, { k: 'Seize', l: 'Seize', num: true }, { k: 'NSeize', l: 'Nseize', num: true }, { k: 'ASeize', l: 'Aseize', num: true }, { k: 'BSeize', l: 'Bseize', num: true }, { k: 'BusySet', l: 'BusySet', num: true }, { k: 'Wakeups', l: 'Wakeups', num: true }, { k: 'NSeizePct', l: 'Nseize %', num: true }, { k: 'ASeizePct', l: 'Aseize %', num: true }, { k: 'BSeizePct', l: 'Bseize %', num: true }, { k: 'SeizePerSec', l: 'Seize/s', num: true }, { k: 'BlockCollisions', l: 'Block coll.', num: true }] });
	        });
	      }, false);
	    },
	    db: function () {
	      exportBar($('#tab-db'), [['DatabaseFile', 'Download database samples (CSV)']]);
	      sampleSel($('#dbSample'), SRC.dbs, function (s) {
	        SP.api('rtable', { id: ID, k: 'db', s: s }).then(function (j) {
	          var rows = j.rows;
	          SP.barChart($('#dbChart'), { rows: rows.slice().sort(function (a, b) { return b.SizeMB - a.SizeMB; }).map(function (r) { return { label: r.DBName || r.Directory, value: r.SizeMB, color: r.ReadOnly ? 'var(--muted)' : 'var(--s1)', sub: r.Directory + (r.ReadOnly ? ' · read-only' : '') + (r.Journaled ? '' : ' · not journaled') }; }), unit: 'MB' });
	          SP.table($('#dbTable'), { rows: rows, page: 100, csv: 'databases_' + ID, columns: [{ k: 'SFN', l: 'SFN', num: true, dec: 0 }, { k: 'DBName', l: 'Database' }, { k: 'Directory', l: 'Directory' }, { k: 'SizeMB', l: 'Size MB', num: true }, { k: 'MaxSizeMB', l: 'Max MB', num: true }, { k: 'Blocks', l: 'Blocks', num: true }, { k: 'BlockSizeKB', l: 'Block KB', num: true }, { k: 'ReadOnly', l: 'Read-only', fmt: function (v) { return v ? 'yes' : ''; } }, { k: 'Journaled', l: 'Journaled', fmt: function (v) { return v ? 'yes' : 'NO'; } }, { k: 'Flags', l: 'Flags' }, { k: 'ROReason', l: 'RO reason' }] });
	        });
	      }, true);
	    },
	    config: function () {
	      SP.api('rtable', { id: ID, k: 'cpf' }).then(function (j) {
	        var rows = j.rows, secs = {};
	        var keyMap = { 'config|globals': 'Global buffers (globals)', 'config|routines': 'Routine buffers', 'config|gmheap': 'gmheap (KB)', 'config|locksiz': 'Lock table (locksiz)', 'config|jrnbufs': 'Journal buffers (MB)', 'config|wijdir': 'WIJ directory', 'config|bbsiz': 'Process memory (bbsiz)', 'config|MaxServerConn': 'MaxServerConn', 'Journal|CurrentDirectory': 'Journal directory', 'Journal|AlternateDirectory': 'Alternate journal dir', 'Journal|FreezeOnError': 'Journal FreezeOnError', 'Journal|DaysBeforePurge': 'Journal days before purge', 'Journal|FileSizeLimit': 'Journal file size (MB)', 'Startup|SystemPerformanceDailyReportsOn': 'Daily SystemPerformance', 'Startup|MaxConsoleLogSize': 'messages.log max MB', 'Startup|EnsembleAutoStart': 'Productions auto start', 'MirrorMember|JoinMirror': 'Mirror member', 'SQL|AutoParallel': 'SQL auto parallel', 'WorkQueues|Default': 'Work queue Default', 'WorkQueues|SQL': 'Work queue SQL' };
	        var key = [];
	        rows.forEach(function (r) { secs[r.Section] = 1; var k = keyMap[r.Section + '|' + r.Name]; if (k) key.push([k, (r.Value === '' ? '(default / empty)' : r.Value)]); });
	        kv($('#cfgKey'), key);
	        var sel = $('#cfgSec'); Object.keys(secs).forEach(function (s) { opt(sel, s, s); });
	        var t = SP.table($('#cfgTable'), { rows: rows, page: 100, csv: 'cpf_' + ID, columns: [{ k: 'Section', l: 'Section' }, { k: 'Name', l: 'Name' }, { k: 'Value', l: 'Value', cls: 'wrap' }] });
	        sel.addEventListener('change', function () { t.set(sel.value ? rows.filter(function (r) { return r.Section === sel.value; }) : rows); });
	      });
	    },
	    kv: function () {
	      SP.api('rtable', { id: ID, k: 'kv' }).then(function (j) {
	        var rows = j.rows, secs = {};
	        rows.forEach(function (r) { secs[r.Section] = 1; });
	        var sel = $('#kvSec'); Object.keys(secs).forEach(function (s) { opt(sel, s, s); });
	        var t = SP.table($('#kvTable'), { rows: rows, page: 100, csv: 'details_' + ID, columns: [{ k: 'Section', l: 'Section' }, { k: 'GroupName', l: 'Group' }, { k: 'SampleNo', l: 'Sample', num: true, dec: 0 }, { k: 'Name', l: 'Name' }, { k: 'Value', l: 'Value', cls: 'wrap' }] });
	        sel.addEventListener('change', function () { t.set(sel.value ? rows.filter(function (r) { return r.Section === sel.value; }) : rows); });
	      });
	    },
	    osproc: function () {
	      var cur = [];
	      function render() {
	        var rows = $('#opIris').checked ? cur.filter(function (r) { return r.IsIRIS; }) : cur;
	        SP.barChart($('#opChart'), { rows: rows.slice(0, 10).map(function (r) { return { label: (r.ImageName || '') + ' (' + r.PID + ')', value: (r.MemKB || 0) / 1024, sub: r.UserName || '', color: r.IsIRIS ? 'var(--s1)' : 'var(--s2)' }; }), unit: 'MB' });
	        tbl.set(rows);
	      }
	      var tbl = SP.table($('#opTable'), { rows: [], page: 100, csv: 'osproc_' + ID, columns: [{ k: 'PID', l: 'PID', num: true, dec: 0 }, { k: 'PPID', l: 'PPID', num: true, dec: 0 }, { k: 'ImageName', l: 'Image' }, { k: 'UserName', l: 'User' }, { k: 'MemKB', l: 'Memory KB', num: true }, { k: 'CPUTime', l: 'CPU time' }, { k: 'CPUSeconds', l: 'CPU s', num: true }, { k: 'Status', l: 'Status' }, { k: 'SessionName', l: 'Session / TTY' }, { k: 'Command', l: 'Command', cls: 'wrap' }] });
	      $('#opIris').addEventListener('change', render);
	      sampleSel($('#opSample'), SRC.osproc, function (s) { SP.api('rtable', { id: ID, k: 'osproc', s: s }).then(function (j) { cur = j.rows; render(); }); }, true);
	    },
	    rtn: function () {
	      SP.api('rtable', { id: ID, k: 'rtnbuf' }).then(function (j) {
	        SP.table($('#rtnTable'), { rows: j.rows, page: 100, csv: 'rtnbuf_' + ID, columns: [{ k: 'RoutineName', l: 'Routine' }, { k: 'SizeBytes', l: 'Buffer bytes', num: true }, { k: 'InUse', l: 'In use', num: true }, { k: 'Old', l: 'Old', num: true }, { k: 'BufType', l: 'Type' }, { k: 'SFN', l: 'SFN', num: true, dec: 0 }] });
	      });
	    },
	    raw: function () {
	      SP.api('rtable', { id: ID, k: 'oscols' }).then(function (j) {
	        var cols = j.rows, sel = SP.clear($('#rwSrc')), srcs = {};
	        cols.forEach(function (c) { srcs[c.Source] = (srcs[c.Source] || 0) + 1; });
	        Object.keys(srcs).forEach(function (s) { opt(sel, s, s + ' (' + srcs[s] + ' columns)'); });
	        if (!sel.options.length) { $('#rwChart').appendChild(SP.el('div', { cls: 'notice warn', text: 'No raw OS counters in this report.' })); return; }
	        var picked = {};
	        function list() {
	          var box = SP.clear($('#rwCols')), q = $('#rwFind').value.toLowerCase(), src = sel.value, n = 0;
	          cols.filter(function (c) { return c.Source === src && (!q || c.Name.toLowerCase().indexOf(q) >= 0); }).forEach(function (c) {
	            if (n++ > 400) return;
	            var cb = SP.el('input', { type: 'checkbox' }); cb.checked = !!picked[src + ':' + c.ColNo];
	            cb.addEventListener('change', function () { picked[src + ':' + c.ColNo] = cb.checked; draw(); });
	            box.appendChild(SP.el('label', { title: c.Name }, [cb, c.Name.replace(/^\\\\[^\\]+/, '')]));
	          });
	        }
	        function draw() {
	          var src = sel.value, ids = Object.keys(picked).filter(function (k) { return picked[k] && k.split(':')[0] === src; }).map(function (k) { return k.split(':')[1]; }).slice(0, 8);
	          if (!ids.length) { SP.clear($('#rwChart')).appendChild(SP.el('div', { cls: 'muted', text: 'Tick up to 8 counters above to chart them (counters with different units are best charted separately).' })); return; }
	          SP.api('osraw', { id: ID, src: src, cols: ids.join(','), ent: $('#rwEnt').value || '' }).then(function (r) {
	            SP.lineChart($('#rwChart'), { series: r.series.map(function (s, i) { return { name: s.name.replace(/^\\\\[^\\]+/, ''), pts: tsPts(s), color: SP.color(i) }; }), height: 280 });
	          }).catch(function (e) { SP.fail($('#rwChart'), e); });
	        }
	        function ents() {
	          var src = sel.value, es = SP.clear($('#rwEnt')), set = {};
	          if (src === 'iostat' || src === 'sar-d') SRC.disk.forEach(function (d) { if (d.src === src) set[d.dev] = 1; });
	          var keys = Object.keys(set);
	          $('#rwEntL').classList.toggle('hide', !keys.length);
	          keys.forEach(function (k) { opt(es, k, k); });
	          if (src === 'sar-u') { $('#rwEntL').classList.remove('hide'); opt(es, 'all', 'all'); }
	        }
	        sel.addEventListener('change', function () { ents(); list(); draw(); });
	        $('#rwEnt').addEventListener('change', draw);
	        $('#rwFind').addEventListener('input', list);
	        ents(); list(); draw();
	      });
	    },
	    report: function () {
	      var cur = null;
	      SP.table($('#secList'), { rows: SRC.sections, page: 60, csv: false, search: false, columns: [{ k: 'name', l: 'Section', render: function (v, r) { return SP.el('a', { href: '#', text: v, onclick: function (e) { e.preventDefault(); open(r); } }); } }, { k: 'mode', l: 'Mode' }, { k: 'lines', l: 'Lines', num: true }] });
	      function open(r) {
	        cur = r; $('#secTitle').textContent = r.name;
	        var sel = SP.clear($('#secSample'));
	        var list = [];
	        if (r.samples > 1) for (var i = 0; i <= r.samples; i++) list.push(i);
	        if (!list.length) list = [0];
	        list.forEach(function (i) { opt(sel, i, i === 0 ? 'header / all' : 'sample ' + i); });
	        if (r.samples > 1) sel.value = '1';
	        load();
	      }
	      function load() {
	        SP.api('section', { id: ID, name: cur.name, s: $('#secSample').value || 0 }).then(function (j) {
	          var t = $('#secText'); t.textContent = j.text || (j.error || '(empty)');
	          if (j.truncated) t.textContent += '\n… truncated';
	        }).catch(function (e) { SP.fail($('#secText'), e); });
	      }
	      $('#secSample').addEventListener('change', function () { if (cur) load(); });
	    }
	  };

	  function exportBtn(t, label) { return SP.el('a', { cls: 'btn', href: 'SysPerf.UI.Export.cls?id=' + ID + '&t=' + t, text: label || ('Download ' + t + ' (CSV)') }); }
	  function exportBar(host, list) { var d = SP.el('div', { cls: 'flex section' }); list.forEach(function (x) { d.appendChild(exportBtn(x[0], x[1])); }); host.appendChild(d); }
	  function sampleSel(sel, list, onChange, last) {
	    SP.clear(sel);
	    (list || []).forEach(function (x) { opt(sel, x.s, x.label || ('#' + x.s + (x.ts ? '  ' + x.ts : '') + (x.n != null ? '  (' + x.n + ' rows)' : ''))); });
	    if (!sel.options.length) { opt(sel, '', 'no samples'); onChange(''); return; }
	    sel.value = last ? sel.options[sel.options.length - 1].value : sel.options[0].value;
	    sel.addEventListener('change', function () { onChange(sel.value); });
	    onChange(sel.value);
	  }

	  function mgCharts() {
	    var cols = Object.keys(mgSel).filter(function (k) { return mgSel[k]; });
	    var host = SP.clear($('#mgCharts'));
	    if (!cols.length) { host.appendChild(SP.el('div', { cls: 'muted', text: 'Tick counters in the table below to chart them.' })); return; }
	    SP.api('rseries', { id: ID, t: 'Mgstat', cols: cols.join(',') }).then(function (j) {
	      j.series.forEach(function (s) {
	        var ch = cardChart(host, s.name, (MG_UNITS[s.col] != null ? MG_UNITS[s.col] : 'per second') + (s.bucket > 1 ? ' · avg per ' + s.bucket + ' samples, band = min–max' : ''));
	        SP.lineChart(ch, { series: [{ name: s.name, pts: tsPts(s), band: bandPts(s), bandLabel: 'min–max', color: 'var(--s1)' }], unit: MG_UNITS[s.col] || '/s', height: 190, yZero: s.col !== 'CacheHitPct' });
	      });
	    }).catch(function (e) { SP.fail(host, e); });
	  }

	  function osDraw() {
	    var src = $('#osSrc').value, host = SP.clear($('#osCharts'));
	    var groups = [
	      ['CPU', '%', ['CPUBusyPct', 'CPUUserPct', 'CPUSysPct', 'CPUIOWaitPct', 'CPUStealPct', 'CPUMaxCorePct']],
	      ['Run queue / blocked', 'procs', ['RunQueue', 'ProcsBlocked']],
	      ['Memory', 'MB', ['MemAvailMB', 'MemFreeMB', 'MemCacheMB', 'SwapUsedMB']],
	      ['Committed / paging file', '%', ['MemCommitPct', 'PagingFilePct']],
	      ['Paging', '/s', ['PageInPerSec', 'PageOutPerSec', 'SwapInPerSec', 'SwapOutPerSec']],
	      ['Context switches / interrupts', '/s', ['ContextSwPerSec', 'InterruptsPerSec']],
	      ['Block I/O', 'blocks/s', ['BlocksInPerSec', 'BlocksOutPerSec']],
	      ['Network', 'KB/s', ['NetRxKBPerSec', 'NetTxKBPerSec']],
	      ['Worst disk latency', 'ms', ['DiskMaxReadLatMs', 'DiskMaxWriteLatMs']],
	      ['Disk IOPS (all devices)', 'IOPS', ['DiskTotalIOPS']],
	      ['Processes', 'count', ['ProcessCount']]
	    ];
	    var all = []; groups.forEach(function (g) { all = all.concat(g[2]); });
	    SP.api('rseries', { id: ID, t: 'OSStat', src: src, cols: all.join(',') }).then(function (j) {
	      var by = {}; j.series.forEach(function (s) { if (s.n) by[s.col] = s; });
	      var shown = 0;
	      groups.forEach(function (g) {
	        var ser = g[2].filter(function (c) { return by[c] && by[c].pts.some(function (p) { return p[1] != null; }); }).map(function (c, i) { return { name: OSLAB[c] || c, pts: tsPts(by[c]), color: SP.color(g[2].indexOf(c)) }; });
	        if (!ser.length) return;
	        shown++;
	        SP.lineChart(cardChart(host, g[0], g[1]), { series: ser, unit: g[1], height: 200, yMax: g[1] === '%' ? 100 : null });
	      });
	      if (!shown) host.appendChild(SP.el('div', { cls: 'muted', text: 'This source has no system-level counters.' }));
	    }).catch(function (e) { SP.fail(host, e); });
	    SP.api('rstats', { id: ID, t: 'OSStat', src: src }).then(function (j) {
	      SP.table($('#osStats'), { rows: j.stats, page: 60, csv: 'os_stats_' + ID, columns: [{ k: 'col', l: 'Metric' }, { k: 'avg', l: 'Avg', num: true }, { k: 'p95', l: 'P95', num: true }, { k: 'max', l: 'Max', num: true }, { k: 'min', l: 'Min', num: true }, { k: 'maxTS', l: 'Max at' }, { k: 'n', l: 'Samples', num: true, dec: 0 }] });
	    });
	  }
	  function dkDraw() {
	    var src = $('#dkSrc').value;
	    SP.api('rtable', { id: ID, k: 'disks', src: src }).then(function (j) {
	      SP.table($('#dkTable'), { rows: j.rows, page: 50, csv: 'disks_' + ID, rowCls: function (r) { return (r.ReadLatMs > 10 || r.WriteLatMs > 10 || r.AwaitMs > 10) ? 'hl' : ''; }, columns: [{ k: 'Device', l: 'Device' }, { k: 'IOPS', l: 'IOPS', num: true }, { k: 'ReadsPerSec', l: 'Reads/s', num: true }, { k: 'WritesPerSec', l: 'Writes/s', num: true }, { k: 'ReadKBPerSec', l: 'Read KB/s', num: true }, { k: 'WriteKBPerSec', l: 'Write KB/s', num: true }, { k: 'ReadLatMs', l: 'Read ms', num: true }, { k: 'MaxReadLatMs', l: 'Max read ms', num: true }, { k: 'WriteLatMs', l: 'Write ms', num: true }, { k: 'MaxWriteLatMs', l: 'Max write ms', num: true }, { k: 'AwaitMs', l: 'Await ms', num: true }, { k: 'QueueLen', l: 'Queue', num: true }, { k: 'MaxQueue', l: 'Max queue', num: true }, { k: 'UtilPct', l: 'Util %', num: true }, { k: 'MaxUtilPct', l: 'Max util %', num: true }] });
	    });
	    dkChart();
	  }
	  function dkChart() {
	    var m = $('#dkMetric').value;
	    SP.api('rseries', { id: ID, t: 'DiskStat', src: $('#dkSrc').value, cols: m, dev: '*' }).then(function (j) {
	      var ser = j.series.filter(function (s) { return s.pts.some(function (p) { return p[1]; }); }).slice(0, 8);
	      SP.lineChart($('#dkChart'), { series: ser.map(function (s, i) { return { name: s.name, pts: tsPts(s), color: SP.color(i) }; }), unit: $('#dkMetric').selectedOptions[0].text.replace(/^.*\(|\)$/g, ''), height: 260, empty: 'All devices were idle for this metric' });
	      if (j.series.length > 8) $('#dkChart').appendChild(SP.el('div', { cls: 'muted small', text: 'Showing 8 busiest of ' + j.series.length + ' devices; see the table for all.' }));
	    }).catch(function (e) { SP.fail($('#dkChart'), e); });
	  }

	  document.addEventListener('DOMContentLoaded', function () {
	    Promise.all([header(), SP.api('sources', { id: ID }).then(function (s) { SRC = s; })]).then(function () {
	      TABS = SP.tabs($('#tabs'), function (id) { try { loaders[id](); } catch (e) { SP.fail($('#tab-' + id), e); } });
	    }).catch(function (e) { SP.fail($('#errs'), e); });
	  });
	})();
}

}
