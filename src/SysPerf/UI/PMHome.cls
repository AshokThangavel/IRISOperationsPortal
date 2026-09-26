/// PERFMON: loaded timed collections, trends across collections, hottest globals over time,
/// and (admins) starting a new timed collection in a background job.
Class SysPerf.UI.PMHome Extends SysPerf.UI.Base
{

Parameter NAVID = "pm-home";

Parameter PAGETITLE = "PERFMON - IRIS Operations Portal";

ClassMethod NavId() As %String [ ServerOnly = 1 ]
{
	quit $s($g(%request.Data("tab",1))="collect":"pm-collect",1:"pm-home")
}

ClassMethod OnPost() [ ServerOnly = 1 ]
{
	set tOp=..P("op")
	if tOp="collect" {
		if '..IsAdmin() do ..ReplyJSON({"error":"Starting a collection requires the SysPerfAdmin role"}) quit
		set tSec=..P("seconds")
		set tSC=##class(SysPerf.PM.Collector).Start(tSec,.tReq,"Portal:"_$username)
		do ..ReplyJSON($s($$$ISOK(tSC):{"ok":1,"request":(+tReq)},1:{"error":($system.Status.GetErrorText(tSC))}))
		quit
	}
	set %response.Redirect="SysPerf.UI.PMHome.cls"
	if '..IsAdmin() { do ..Flash("err","This action requires the SysPerfAdmin role.") quit }
	set tIds=..P("ids"),(tOK,tErr)=0
	for i=1:1:$l(tIds,",") {
		set tId=$p(tIds,",",i) continue:tId'?1.N
		if tOp="delete" { set tSC=##class(SysPerf.PM.Collection).Purge(tId) }
		elseif tOp="reanalyze" { set tSC=##class(SysPerf.PM.Analyzer).Analyze(tId) }
		else { continue }
		if $$$ISOK(tSC) { set tOK=tOK+1 } else { set tErr=tErr+1 }
	}
	do ..Flash($s(tErr:"err",1:"ok"),$case(tOp,"delete":"Deleted",:"Re-analysed")_" "_tOK_" collection(s)"_$s(tErr:", "_tErr_" failed",1:"")_".")
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set tCsrf=..H(..CSRF()),tAdmin=..IsAdmin()
	&html<
<h1>PERFMON</h1>
<p class="sub">Timed collections of the PERFMON utility: which globals, routines and processes generate the load, and where it lands on disk.</p>
<div class="tabs" id="tabs" role="tablist">
  <button data-tab="list">Collections</button>
  <button data-tab="trend">Trends</button>
  <button data-tab="collect">Run collection</button>
</div>
<section class="tabpane" id="tab-list">
  <div class="sp-filters">
    <label>System<select id="fSys"><option value="">All systems</option></select></label>
    <label>From<input type="date" id="fFrom"></label><label>To<input type="date" id="fTo"></label>
    <span id="adminTools" class="flex"></span>
  </div>
  <div class="card"><div id="colls"></div></div>
</section>
<section class="tabpane" id="tab-trend">
  <div class="sp-filters"><label>System<select id="tSys"></select></label><label>Top globals by<div id="tMetric"></div></label></div>
  <div class="grid g2">
    <div class="card"><h2>Global references / s</h2><div id="cRefs"></div></div>
    <div class="card"><h2>Physical block reads / s</h2><div id="cPhy"></div></div>
    <div class="card"><h2>Journal entries / s</h2><div id="cJrn"></div></div>
    <div class="card"><h2>Routine lines / s</h2><div id="cLines"></div></div>
  </div>
  <div class="card section"><h2 id="tgTitle">Hottest globals across collections</h2><div id="cTop"></div></div>
  <div class="card section"><h2>Health score per collection</h2><div id="cHealth"></div></div>
</section>
<section class="tabpane" id="tab-collect">
  <div class="grid g2">
    <div class="card">
      <h2>Start a timed collection</h2>
      <p class="muted small">Runs <code>$$Collect^PERFMON(seconds,"HTML",file)</code> in %SYS in a background job, saves the report to the archive directory and loads it automatically. PERFMON is instance-wide, so only one collection can run at a time. Collection adds a small overhead while it runs.</p>
>
	if tAdmin {
		&html<
      <form id="fCollect" class="form-row">
        <label>Duration<select id="fSec"><option value="10">10 seconds</option><option value="30">30 seconds</option><option value="60" selected>1 minute</option><option value="300">5 minutes</option><option value="600">10 minutes</option><option value="900">15 minutes</option><option value="1800">30 minutes</option><option value="3600">60 minutes</option></select></label>
        <button class="btn primary" type="submit" id="btnGo">Start collection</button>
      </form>
>
	} else {
		&html<<div class="notice">Starting a collection requires the SysPerfAdmin role. You can still view collections and their progress.</div>>
	}
	&html<
      <div id="progress" class="section"></div>
    </div>
    <div class="card"><h2>Other ways to collect</h2>
      <ul class="small">
        <li><b>Scheduled:</b> the task class <code>SysPerf.Task.PerfmonCollect</code> (property <i>Seconds</i>) runs a collection on a schedule in Task Manager.</li>
        <li><b>Terminal:</b> <code>do ##class(SysPerf.PM.Collector).Start(60,.id)</code> starts a background collection (request <i>id</i>), or run PERFMON yourself and upload the HTML.</li>
        <li><b>Existing files:</b> upload PERFMON_*.html reports on <a href="SysPerf.UI.PMLoad.cls">Load PERFMON Files</a> or drop them into the inbox directory; they are detected automatically.</li>
      </ul>
    </div>
  </div>
  <div class="card section"><h2>Collection requests</h2><div id="reqs"></div></div>
</section>
<form id="f" method="post" class="hide"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" id="fOp"><input type="hidden" name="ids" id="fIds"></form>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, CFG = window.SP_CFG, S = { systems: [], sys: '', metric: 'RefsPerSec' }, tbl = null, sel = {}, pollT = null;
	  try { S.sys = localStorage.getItem('sysperf.pmsys') || ''; } catch (e) {}
	  function loadList() {
	    SP.pmapi('collections', { sys: $('#fSys').value, from: $('#fFrom').value, to: $('#fTo').value }).then(function (j) {
	      sel = {};
	      j.rows.forEach(function (r) { var d = r.dur || 1; r.refsps = r.TotalGloRefs / d; r.phyps = r.TotalPhyBlkRd / d; r.jrnps = r.TotalJrnEntry / d; r.linesps = r.TotalRtnLines / d; });
	      tbl = SP.table($('#colls'), {
	        rows: j.rows, csv: 'perfmon_collections', sort: { k: 'ts', dir: 'desc' },
	        columns: [
	          CFG.admin ? { k: 'id', l: '', nosort: true, render: function (v) { var c = SP.el('input', { type: 'checkbox', 'aria-label': 'Select collection ' + v }); c.checked = !!sel[v]; c.addEventListener('change', function () { sel[v] = c.checked; tools(); }); return c; } } : null,
	          { k: 'ts', l: 'Collected', link: function (r) { return 'SysPerf.UI.PMRun.cls?id=' + r.id; } },
	          { k: 'sys', l: 'System' }, { k: 'dur', l: 'Seconds', num: true, dec: 0 },
	          { k: 'health', l: 'Health', num: true, render: function (v) { return SP.score(v); } },
	          { k: 'crit', l: 'Critical', num: true, dec: 0 }, { k: 'warn', l: 'Warnings', num: true, dec: 0 },
	          { k: 'refsps', l: 'Global refs/s', num: true, dec: 0 }, { k: 'phyps', l: 'Phys. reads/s', num: true, dec: 0 }, { k: 'jrnps', l: 'Journal/s', num: true, dec: 0 }, { k: 'linesps', l: 'Lines/s', num: true, dec: 0 },
	          { k: 'ProcessCount', l: 'Processes', num: true, dec: 0 }, { k: 'Origin', l: 'Origin' }, { k: 'FileName', l: 'File', cls: 'small' }
	        ].filter(Boolean),
	        empty: 'No PERFMON collections loaded. Use "Run collection" or PERFMON > Load PERFMON Files.'
	      });
	      tools();
	    }).catch(function (e) { SP.fail($('#colls'), e); });
	  }
	  function tools() {
	    if (!CFG.admin) return;
	    var ids = Object.keys(sel).filter(function (k) { return sel[k]; }), h = SP.clear($('#adminTools'));
	    function act(op, label, confirmTxt) {
	      h.appendChild(SP.el('button', { cls: 'btn' + (op === 'delete' ? ' danger' : ''), text: label + (ids.length ? ' (' + ids.length + ')' : ''), disabled: ids.length ? null : 'disabled', onclick: function () {
	        if (confirmTxt && !confirm(confirmTxt.replace('%n', ids.length))) return;
	        $('#fOp').value = op; $('#fIds').value = ids.join(','); $('#f').submit();
	      } }));
	    }
	    act('reanalyze', 'Re-analyse'); act('delete', 'Delete', 'Delete %n collection(s) and all their data?');
	  }
	  function trends() {
	    var sys = $('#tSys').value; if (!sys) { SP.clear($('#cTop')).appendChild(SP.el('div', { cls: 'empty', text: 'No collections loaded yet.' })); return; }
	    SP.pmapi('trend', { sys: sys }).then(function (j) {
	      function s(k) { return j.rows.map(function (r) { return [SP.ts(r.ts), +r[k]]; }); }
	      var o = { unit: '/s', height: 200, empty: 'Needs at least one collection' };
	      SP.lineChart($('#cRefs'), Object.assign({}, o, { series: [{ name: 'Global refs/s', pts: s('refs') }, { name: 'Updates/s', pts: s('upd') }] }));
	      SP.lineChart($('#cPhy'), Object.assign({}, o, { series: [{ name: 'Physical reads/s', pts: s('phy') }] }));
	      SP.lineChart($('#cJrn'), Object.assign({}, o, { series: [{ name: 'Journal entries/s', pts: s('jrn') }] }));
	      SP.lineChart($('#cLines'), Object.assign({}, o, { series: [{ name: 'Routine lines/s', pts: s('lines') }] }));
	      SP.lineChart($('#cHealth'), { height: 180, yZero: true, yMax: 100, series: [{ name: 'Health', pts: s('health') }], refs: [{ v: 55, label: 'warning' }, { v: 80, label: 'good' }] });
	    }).catch(function (e) { SP.fail($('#cRefs'), e); });
	    SP.pmapi('topglobals', { sys: sys, m: S.metric }).then(function (j) {
	      var lab = { RefsPerSec: 'references/s', PhyRdPerSec: 'physical reads/s', JrnPerSec: 'journal entries/s', UpdPerSec: 'updates/s' }[S.metric];
	      $('#tgTitle').textContent = 'Hottest globals across collections – ' + lab;
	      SP.lineChart($('#cTop'), { height: 260, unit: '/s', series: j.series.map(function (x) { return { name: x.name, pts: x.pts.map(function (p) { return [SP.ts(p[0]), p[1]]; }) }; }) });
	    }).catch(function (e) { SP.fail($('#cTop'), e); });
	  }
	  function reqs() {
	    return SP.pmapi('requests').then(function (j) {
	      SP.table($('#reqs'), { rows: j.rows, search: false, csv: 'perfmon_requests', page: 15, columns: [
	        { k: 'id', l: '#', num: true, dec: 0 }, { k: 'RequestedTS', l: 'Requested' }, { k: 'RequestedBy', l: 'By' }, { k: 'DurationSec', l: 'Seconds', num: true, dec: 0 },
	        { k: 'Status', l: 'Status', render: function (v) { return SP.el('span', {}, [SP.el('span', { cls: 'dot ' + (v === 'Done' ? 'ok' : v === 'Error' ? 'bad' : 'warn') }), v]); } },
	        { k: 'StartTS', l: 'Started' }, { k: 'EndTS', l: 'Finished' }, { k: 'CollectionId', l: 'Collection', render: function (v) { return v ? SP.el('a', { href: 'SysPerf.UI.PMRun.cls?id=' + v, text: 'Open #' + v }) : ''; } }, { k: 'Message', l: 'Message', cls: 'wrap' }, { k: 'Origin', l: 'Origin' }],
	        empty: 'No collections have been requested from the portal.' });
	      var active = j.rows.filter(function (r) { return /Queued|Collecting|Loading/.test(r.Status); })[0];
	      if (active) watch(active.id);
	      return j;
	    }).catch(function (e) { SP.fail($('#reqs'), e); });
	  }
	  function watch(id) {
	    clearTimeout(pollT);
	    var p = $('#progress'), btn = $('#btnGo'); if (btn) btn.disabled = true;
	    SP.pmapi('request', { id: id }).then(function (j) {
	      var r = j.rows[0]; if (!r) return;
	      SP.clear(p);
	      var el = r.StartTS ? (Date.now() - SP.ts(r.StartTS)) / 1000 : 0, pct = r.Status === 'Collecting' ? Math.min(99, 100 * el / r.DurationSec) : r.Status === 'Loading' ? 99 : r.Status === 'Done' ? 100 : 2;
	      p.appendChild(SP.el('div', { cls: 'flex' }, [SP.el('span', { cls: 'dot ' + (r.Status === 'Done' ? 'ok' : r.Status === 'Error' ? 'bad' : 'warn') }), SP.el('b', { text: 'Request #' + r.id + ': ' + r.Status }), SP.el('span', { cls: 'muted small', text: r.Status === 'Collecting' ? Math.max(0, Math.round(r.DurationSec - el)) + ' s remaining' : (r.Message || '') })]));
	      var bar = SP.el('div', { cls: 'progress' }), i = SP.el('i'); i.style.width = pct + '%'; bar.appendChild(i); p.appendChild(bar);
	      if (r.Status === 'Done' && r.CollectionId) { p.appendChild(SP.el('a', { cls: 'btn primary', href: 'SysPerf.UI.PMRun.cls?id=' + r.CollectionId, text: 'Open the analysis' })); if (btn) btn.disabled = false; reqs(); loadList(); }
	      else if (r.Status === 'Error') { p.appendChild(SP.el('div', { cls: 'notice err', text: r.Message || 'Collection failed' })); if (btn) btn.disabled = false; reqs(); }
	      else pollT = setTimeout(function () { watch(id); }, 2000);
	    }).catch(function (e) { SP.fail(p, e); if (btn) btn.disabled = false; });
	  }
	  document.addEventListener('DOMContentLoaded', function () {
	    SP.tabs($('#tabs'), function (t) {
	      if (t === 'trend') trends();
	      if (t === 'collect') reqs();
	    });
	    SP.pmapi('systems').then(function (j) {
	      S.systems = j.systems;
	      j.systems.forEach(function (s) { $('#fSys').appendChild(SP.el('option', { value: s.sys, text: s.sys + ' (' + s.n + ')' })); $('#tSys').appendChild(SP.el('option', { value: s.sys, text: s.sys })); });
	      if (S.sys && j.systems.some(function (s) { return s.sys === S.sys; })) { $('#fSys').value = S.sys; $('#tSys').value = S.sys; }
	      loadList();
	      if ($('#tab-trend').classList.contains('on')) trends();
	    }).catch(function (e) { SP.fail($('#colls'), e); });
	    ['#fSys', '#fFrom', '#fTo'].forEach(function (s) { $(s).addEventListener('change', function () { if (s === '#fSys') { try { localStorage.setItem('sysperf.pmsys', this.value); } catch (e) {} } loadList(); }); });
	    $('#tSys').addEventListener('change', trends);
	    SP.seg($('#tMetric'), [{ v: 'RefsPerSec', l: 'References' }, { v: 'PhyRdPerSec', l: 'Physical reads' }, { v: 'UpdPerSec', l: 'Updates' }, { v: 'JrnPerSec', l: 'Journal' }], S.metric, function (v) { S.metric = v; trends(); });
	    var f = $('#fCollect');
	    if (f) f.addEventListener('submit', function (ev) {
	      ev.preventDefault(); $('#btnGo').disabled = true;
	      SP.post('SysPerf.UI.PMHome.cls', { op: 'collect', seconds: $('#fSec').value }).then(function (j) { reqs(); watch(j.request); })
	        .catch(function (e) { $('#btnGo').disabled = false; SP.clear($('#progress')).appendChild(SP.el('div', { cls: 'notice err', text: e.message })); });
	    });
	  });
	})();
}

}
