/// One PERFMON collection: findings with recommendations, per-global, global-by-routine,
/// per-routine, per-process and per-database statistics, the process list, any other tables
/// in the report, and the original report.
Class SysPerf.UI.PMRun Extends SysPerf.UI.Base
{

Parameter NAVID = "pm-home";

Parameter PAGETITLE = "PERFMON collection - IRIS Operations Portal";

ClassMethod OnPost() [ ServerOnly = 1 ]
{
	set tOp=..P("op"),tId=..P("id")
	if tOp="ack" {
		set tF=..P("finding")
		if tF'?1.N do ..ReplyJSON({"error":"bad finding"}) quit
		if '..IsAdmin() do ..ReplyJSON({"error":"Acknowledging requires the SysPerfAdmin role"}) quit
		set tObj=##class(SysPerf.PM.Finding).%OpenId(tF)
		if '$isobject(tObj) do ..ReplyJSON({"error":"not found"}) quit
		set tObj.Acknowledged=1,tObj.AckBy=$username,tObj.AckTS=$zdt($h,3),tObj.AckNote=$e(..P("note"),1,4000)
		set tSC=tObj.%Save()
		do ..ReplyJSON($s($$$ISOK(tSC):{"ok":1},1:{"error":($system.Status.GetErrorText(tSC))}))
		quit
	}
	if tId'?1.N quit
	set tBack="SysPerf.UI.PMRun.cls?id="_tId
	if '..IsAdmin() { do ..Flash("err","This action requires the SysPerfAdmin role.") set %response.Redirect=tBack quit }
	if tOp="notes" {
		set c=##class(SysPerf.PM.Collection).%OpenId(tId)
		if $isobject(c) set c.Notes=$e(..P("notes"),1,32000) do c.%Save() do ..Flash("ok","Notes saved.")
		set %response.Redirect=tBack
	} elseif tOp="reanalyze" {
		set tSC=##class(SysPerf.PM.Analyzer).Analyze(tId)
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):"Collection re-analysed with the current thresholds.",1:$system.Status.GetErrorText(tSC)))
		set %response.Redirect=tBack
	} elseif tOp="delete" {
		set tSC=##class(SysPerf.PM.Collection).Purge(tId)
		do ..Flash($s($$$ISOK(tSC):"ok",1:"err"),$s($$$ISOK(tSC):"Collection "_tId_" deleted.",1:$system.Status.GetErrorText(tSC)))
		set %response.Redirect=$s($$$ISOK(tSC):"SysPerf.UI.PMHome.cls",1:tBack)
	}
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set tId=..P("id")
	if (tId'?1.N)||'##class(SysPerf.PM.Collection).%ExistsId(tId) {
		write "<div class='notice err'>Collection not found. <a href='SysPerf.UI.PMHome.cls'>Back to PERFMON collections</a></div>"
		quit $$$OK
	}
	set tCsrf=..H(..CSRF()),c=##class(SysPerf.PM.Collection).%OpenId(tId,0)
	&html<
<div class="flex" style="align-items:flex-start">
  <div style="min-width:0;flex:1">
    <div class="muted small"><a href="SysPerf.UI.PMHome.cls">PERFMON</a> / <span id="crumb"></span></div>
    <h1 id="title">PERFMON collection #(tId)#</h1>
    <div class="meta" id="meta"></div>
  </div>
  <div class="flex" id="headTools"></div>
</div>
<div class="stat section" id="kpi"></div>
<div class="tabs" id="tabs" role="tablist">
  <button data-tab="findings">Findings<span class="cnt" id="cntF"></span></button>
  <button data-tab="globals">Globals</button>
  <button data-tab="rglobals">Globals by routine</button>
  <button data-tab="routines">Routines</button>
  <button data-tab="procs">Processes</button>
  <button data-tab="dbs">Databases</button>
  <button data-tab="proclist">Process list</button>
  <button data-tab="generic">Other tables</button>
  <button data-tab="notes">Notes</button>
  <button data-tab="report">Original report</button>
</div>
<section class="tabpane" id="tab-findings">
  <div class="flex" style="margin-bottom:10px"><span id="fSev"></span><span class="muted small" id="fNote"></span></div>
  <div id="findings"></div>
</section>
<section class="tabpane" id="tab-globals">
  <div class="grid g2"><div class="card"><h2>Top globals by references / s</h2><div id="gRefs"></div></div><div class="card"><h2>Top globals by physical reads / s</h2><div id="gPhy"></div></div>
  <div class="card"><h2>Top globals by updates / s (set + kill)</h2><div id="gUpd"></div></div><div class="card"><h2>Top globals by journal entries / s</h2><div id="gJrn"></div></div></div>
  <div class="card section"><div id="tGlobals"></div></div>
</section>
<section class="tabpane" id="tab-rglobals"><p class="muted small">Global activity attributed to the routine that caused it. SQL routines (%sqlcq.*) and generated class routines are resolved to their class where possible.</p><div class="card"><div id="tRGlobals"></div></div></section>
<section class="tabpane" id="tab-routines">
  <div class="grid g2"><div class="card"><h2>Top routines by lines executed</h2><div id="rLines"></div></div><div class="card"><h2>Top routines by loads (buffer fetches)</h2><div id="rLoads"></div></div></div>
  <div class="card section"><div id="tRoutines"></div></div>
</section>
<section class="tabpane" id="tab-procs">
  <div class="grid g2"><div class="card"><h2>Share of global references by process</h2><div id="pRefs"></div></div><div class="card"><h2>Share of routine lines by process</h2><div id="pLines"></div></div></div>
  <div class="card section"><div id="tProcs"></div></div>
</section>
<section class="tabpane" id="tab-dbs">
  <div class="grid g2"><div class="card"><h2>Global references by database</h2><div id="dRefs"></div></div><div class="card"><h2>Physical block reads by database</h2><div id="dPhy"></div></div></div>
  <div class="card section"><div id="tDbs"></div></div>
</section>
<section class="tabpane" id="tab-proclist"><div class="card"><div id="tProcList"></div></div></section>
<section class="tabpane" id="tab-generic"><div id="generic"></div></section>
<section class="tabpane" id="tab-notes">
  <div class="card"><h2>Notes</h2>
  <form method="post" action="SysPerf.UI.PMRun.cls?id=#(tId)#"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" value="notes"><input type="hidden" name="id" value="#(tId)#">
  <textarea name="notes" rows="8" style="width:100%" maxlength="32000" #($s(..IsAdmin():"",1:"readonly"))#>#(..H(c.Notes))#</textarea>
  #($s(..IsAdmin():"<p><button class='btn primary' type='submit'>Save notes</button></p>",1:"<p class='muted small'>Editing notes requires the SysPerfAdmin role.</p>"))#
  </form></div>
</section>
<section class="tabpane" id="tab-report"><div id="report"></div></section>
<form id="f" method="post" class="hide" action="SysPerf.UI.PMRun.cls?id=#(tId)#"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" id="fOp"><input type="hidden" name="id" value="#(tId)#"></form>
<script>window.PM_ID=#(+tId)#;</script>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, CFG = window.SP_CFG, ID = window.PM_ID, C = null, TABS, FIND = [], sevF = 'all';
	  var yn = function (v) { return +v ? 'Yes' : ''; };
	  function bars(host, rows, k, lab, unit) {
	    rows = rows.filter(function (r) { return !+r.IsOther && +r[k] > 0; }).sort(function (a, b) { return b[k] - a[k]; }).slice(0, 12);
	    SP.barChart(host, { unit: unit || '', rows: rows.map(function (r) { return { label: lab(r), value: Math.round(+r[k] * 10) / 10, sub: r.DBName || r.ClassName || '' }; }) });
	  }
	  function kpi(label, val, cls) { $('#kpi').appendChild(SP.el('div', {}, [SP.el('div', { cls: 'l', text: label }), SP.el('div', { cls: 'v' }, [cls ? SP.el('span', { cls: 'dot ' + cls }) : null, val])])); }
	  function header() {
	    return SP.pmapi('coll', { id: ID }).then(function (c) {
	      C = c; var d = c.DurationSec || 1;
	      $('#crumb').textContent = c.SystemName; $('#title').textContent = 'PERFMON ' + c.SystemName + ' – ' + c.CollectedTS;
	      document.title = 'PERFMON ' + c.SystemName + ' ' + c.CollectedTS;
	      var m = SP.clear($('#meta'));
	      [['Host', c.Host], ['Configuration', c.Config], ['Duration', SP.fmt(c.DurationSec, 0) + ' s'], ['Origin', c.Origin], ['File', c.FileName], ['Loaded', c.LoadedTS + ' by ' + (c.LoadedBy || '')], ['Tables', String(c.TableList || '').split(',').join(', ')]].forEach(function (x) { if (x[1]) m.appendChild(SP.el('span', {}, [SP.el('b', { text: x[0] + ': ' }), String(x[1])])); });
	      SP.clear($('#kpi'));
	      kpi('Health', SP.score(c.HealthScore)); kpi('Critical', String(c.CriticalCount || 0), c.CriticalCount ? 'bad' : 'ok'); kpi('Warnings', String(c.WarningCount || 0), c.WarningCount ? 'warn' : 'ok');
	      kpi('Global refs / s', SP.fmt(c.TotalGloRefs / d, 0)); kpi('Updates / s', SP.fmt((c.TotalGloSets + c.TotalGloKills) / d, 0)); kpi('Physical reads / s', SP.fmt(c.TotalPhyBlkRd / d, 0)); kpi('Physical writes / s', SP.fmt(c.TotalPhyBlkWrt / d, 0));
	      kpi('Journal entries / s', SP.fmt(c.TotalJrnEntry / d, 0)); kpi('Blocks allocated / s', SP.fmt(c.TotalBlkAlloc / d, 1)); kpi('Routine lines / s', SP.fmt(c.TotalRtnLines / d, 0)); kpi('Routine loads / s', SP.fmt(c.TotalRtnLoads / d, 0));
	      kpi('Cache miss', c.TotalLogBlkRd ? SP.fmt(100 * c.TotalPhyBlkRd / c.TotalLogBlkRd, 2) + ' %' : '–'); kpi('Processes', SP.fmt(c.ProcessCount, 0)); kpi('Globals / routines', SP.fmt(c.GlobalCount, 0) + ' / ' + SP.fmt(c.RoutineCount, 0));
	      var h = SP.clear($('#headTools'));
	      if (c.prevId) h.appendChild(SP.el('a', { cls: 'btn', href: '?id=' + c.prevId, text: '‹ Previous' }));
	      if (c.nextId) h.appendChild(SP.el('a', { cls: 'btn', href: '?id=' + c.nextId, text: 'Next ›' }));
	      h.appendChild(SP.el('button', { cls: 'btn', text: 'Print', onclick: function () { window.print(); } }));
	      if (CFG.admin) {
	        h.appendChild(SP.el('button', { cls: 'btn', text: 'Re-analyse', onclick: function () { $('#fOp').value = 'reanalyze'; $('#f').submit(); } }));
	        h.appendChild(SP.el('button', { cls: 'btn danger', text: 'Delete', onclick: function () { if (confirm('Delete this collection and all its data?')) { $('#fOp').value = 'delete'; $('#f').submit(); } } }));
	      }
	    }).catch(function (e) { SP.fail($('#meta'), e); });
	  }
	  function findings() {
	    SP.pmapi('findings', { id: ID }).then(function (j) {
	      FIND = j.findings;
	      var n = { C: 0, W: 0, I: 0 }; FIND.forEach(function (f) { n[f.sev] = (n[f.sev] || 0) + 1; });
	      $('#cntF').textContent = FIND.filter(function (f) { return f.sev === 'C' || f.sev === 'W'; }).length || '';
	      SP.seg($('#fSev'), [{ v: 'all', l: 'All (' + FIND.length + ')' }, { v: 'C', l: 'Critical (' + n.C + ')' }, { v: 'W', l: 'Warning (' + n.W + ')' }, { v: 'I', l: 'Info (' + n.I + ')' }, { v: 'open', l: 'Not acknowledged' }], sevF, function (v) { sevF = v; draw(); });
	      $('#fNote').textContent = 'Each finding explains what was measured, why it matters and what to do. Use "Show evidence tab" to jump to the numbers.';
	      draw();
	    }).catch(function (e) { SP.fail($('#findings'), e); });
	    function draw() {
	      var list = FIND.filter(function (f) { return sevF === 'all' || (sevF === 'open' ? !f.ack && f.sev !== 'OK' : f.sev === sevF); });
	      SP.findings($('#findings'), list, { canAck: CFG.admin, openWarn: true, ackUrl: 'SysPerf.UI.PMRun.cls', onDrill: function (t) { TABS.show({ databases: 'dbs', processes: 'procs' }[t] || t, true); } });
	    }
	  }
	  function tbl(t) { return SP.pmapi('table', { id: ID, t: t }).then(function (j) { return j.rows; }); }
	  var loaders = {
	    globals: function () {
	      tbl('globals').then(function (rows) {
	        rows.forEach(function (r) { r.UpdPerSec = r.UpdPerSec || 0; });
	        var g = function (r) { return '^' + String(r.GlobalName).replace(/^\^/, ''); };
	        bars($('#gRefs'), rows, 'RefsPerSec', g, '/s'); bars($('#gPhy'), rows, 'PhyRdPerSec', g, '/s'); bars($('#gUpd'), rows, 'UpdPerSec', g, '/s'); bars($('#gJrn'), rows, 'JrnPerSec', g, '/s');
	        SP.table($('#tGlobals'), { rows: rows, csv: 'perfmon_globals_' + ID, columns: [
	          { k: 'Rank', l: '#', num: true, dec: 0 }, { k: 'GlobalName', l: 'Global' }, { k: 'DBName', l: 'Database' }, { k: 'TotRefs', l: 'References', num: true, dec: 0 }, { k: 'PctRefs', l: '% refs', num: true, dec: 1 }, { k: 'RefsPerSec', l: 'Refs/s', num: true, dec: 0 },
	          { k: 'GloSet', l: 'Sets', num: true, dec: 0 }, { k: 'GloKill', l: 'Kills', num: true, dec: 0 }, { k: 'UpdPerSec', l: 'Upd/s', num: true, dec: 0 }, { k: 'BlkAlloc', l: 'Blocks alloc.', num: true, dec: 0 }, { k: 'JrnEntry', l: 'Journal', num: true, dec: 0 }, { k: 'JrnPerSec', l: 'Jrn/s', num: true, dec: 0 },
	          { k: 'PhyBlkRd', l: 'Phys. reads', num: true, dec: 0 }, { k: 'PhyRdPerSec', l: 'Phys. rd/s', num: true, dec: 0 }, { k: 'PhyBlkWrt', l: 'Phys. writes', num: true, dec: 0 }, { k: 'LogBlkRd', l: 'Logical reads', num: true, dec: 0 }, { k: 'MissPct', l: 'Miss %', num: true, dec: 2 }, { k: 'Directory', l: 'Directory', cls: 'wrap' }],
	          rowCls: function (r) { return +r.IsOther ? 'muted' : +r.PctRefs >= 50 || +r.PhyRdPerSec >= 2000 ? 'row-bad' : +r.PctRefs >= 25 || +r.PhyRdPerSec >= 500 ? 'row-warn' : null; } });
	      }).catch(function (e) { SP.fail($('#tGlobals'), e); });
	    },
	    rglobals: function () {
	      tbl('rglobals').then(function (rows) {
	        SP.table($('#tRGlobals'), { rows: rows, csv: 'perfmon_global_by_routine_' + ID, columns: [
	          { k: 'Rank', l: '#', num: true, dec: 0 }, { k: 'Routine', l: 'Routine' }, { k: 'IsSQL', l: 'SQL', fmt: yn }, { k: 'ClassName', l: 'Class' }, { k: 'TotRefs', l: 'References', num: true, dec: 0 }, { k: 'PctRefs', l: '% refs', num: true, dec: 1 }, { k: 'RefsPerSec', l: 'Refs/s', num: true, dec: 0 },
	          { k: 'GloSet', l: 'Sets', num: true, dec: 0 }, { k: 'GloKill', l: 'Kills', num: true, dec: 0 }, { k: 'BlkAlloc', l: 'Blocks alloc.', num: true, dec: 0 }, { k: 'JrnEntry', l: 'Journal', num: true, dec: 0 }, { k: 'PhyBlkRd', l: 'Phys. reads', num: true, dec: 0 }, { k: 'PhyRdPerSec', l: 'Phys. rd/s', num: true, dec: 0 },
	          { k: 'PhyBlkWrt', l: 'Phys. writes', num: true, dec: 0 }, { k: 'LogBlkRd', l: 'Logical reads', num: true, dec: 0 }, { k: 'MissPct', l: 'Miss %', num: true, dec: 2 }, { k: 'DBName', l: 'Database' }],
	          rowCls: function (r) { return +r.IsOther ? 'muted' : +r.PctRefs >= 25 ? 'row-warn' : null; } });
	      }).catch(function (e) { SP.fail($('#tRGlobals'), e); });
	    },
	    routines: function () {
	      tbl('routines').then(function (rows) {
	        var l = function (r) { return r.Routine + (r.ClassName ? ' (' + r.ClassName + ')' : ''); };
	        bars($('#rLines'), rows, 'LinesPerSec', l, '/s'); bars($('#rLoads'), rows, 'LoadsPerSec', l, '/s');
	        SP.table($('#tRoutines'), { rows: rows, csv: 'perfmon_routines_' + ID, columns: [
	          { k: 'Rank', l: '#', num: true, dec: 0 }, { k: 'Routine', l: 'Routine' }, { k: 'IsSQL', l: 'SQL', fmt: yn }, { k: 'ClassName', l: 'Class' }, { k: 'RtnLines', l: 'Lines', num: true, dec: 0 }, { k: 'PctLines', l: '% lines', num: true, dec: 1 }, { k: 'LinesPerSec', l: 'Lines/s', num: true, dec: 0 },
	          { k: 'RtnLoads', l: 'Loads', num: true, dec: 0 }, { k: 'LoadsPerSec', l: 'Loads/s', num: true, dec: 0 }, { k: 'RtnFetch', l: 'Fetches', num: true, dec: 0 }, { k: 'LinePerLoad', l: 'Lines/load', num: true, dec: 1 }, { k: 'DBName', l: 'Database' }],
	          rowCls: function (r) { return +r.IsOther ? 'muted' : +r.PctLines >= 40 ? 'row-bad' : +r.PctLines >= 20 ? 'row-warn' : null; } });
	      }).catch(function (e) { SP.fail($('#tRoutines'), e); });
	    },
	    procs: function () {
	      tbl('procs').then(function (rows) {
	        var l = function (r) { return r.PID + ' ' + (r.Routine || r.UserName || ''); };
	        bars($('#pRefs'), rows, 'PctRefs', l, '%'); bars($('#pLines'), rows, 'PctLines', l, '%');
	        SP.table($('#tProcs'), { rows: rows, csv: 'perfmon_processes_' + ID, sort: { k: 'TotRefs', dir: 'desc' }, columns: [
	          { k: 'PID', l: 'PID' }, { k: 'UserName', l: 'User' }, { k: 'Namespace', l: 'Namespace' }, { k: 'Routine', l: 'Routine' }, { k: 'State', l: 'State' }, { k: 'ClientName', l: 'Client' }, { k: 'ExeName', l: 'Executable' }, { k: 'ClientIP', l: 'IP' },
	          { k: 'TotRefs', l: 'Global refs', num: true, dec: 0 }, { k: 'PctRefs', l: '% refs', num: true, dec: 1 }, { k: 'RefsPerSec', l: 'Refs/s', num: true, dec: 0 }, { k: 'GloSet', l: 'Sets', num: true, dec: 0 }, { k: 'GloKill', l: 'Kills', num: true, dec: 0 }, { k: 'JrnEntry', l: 'Journal', num: true, dec: 0 },
	          { k: 'PhyBlkRd', l: 'Phys. reads', num: true, dec: 0 }, { k: 'PhyBlkWrt', l: 'Phys. writes', num: true, dec: 0 }, { k: 'LogBlkRd', l: 'Logical reads', num: true, dec: 0 }, { k: 'RtnLines', l: 'Lines', num: true, dec: 0 }, { k: 'PctLines', l: '% lines', num: true, dec: 1 }, { k: 'LinesPerSec', l: 'Lines/s', num: true, dec: 0 }, { k: 'RtnLoads', l: 'Loads', num: true, dec: 0 }],
	          rowCls: function (r) { return +r.IsOther ? 'muted' : +r.PctRefs >= 50 || +r.PctLines >= 50 ? 'row-bad' : +r.PctRefs >= 25 || +r.PctLines >= 25 ? 'row-warn' : /LOCK/i.test(r.State || '') ? 'row-warn' : null; } });
	      }).catch(function (e) { SP.fail($('#tProcs'), e); });
	    },
	    dbs: function () {
	      SP.pmapi('dbs', { id: ID }).then(function (j) {
	        var rows = j.rows, d = (C && C.DurationSec) || 1, lab = function (r) { return r.DBName || r.Directory; };
	        rows.forEach(function (r) { r.refsps = r.TotRefs / d; r.phyps = r.PhyBlkRd / d; r.IsOther = 0; });
	        bars($('#dRefs'), rows, 'refsps', lab, '/s'); bars($('#dPhy'), rows, 'phyps', lab, '/s');
	        SP.table($('#tDbs'), { rows: rows, csv: 'perfmon_databases_' + ID, columns: [{ k: 'DBName', l: 'Database' }, { k: 'Directory', l: 'Directory', cls: 'wrap' }, { k: 'Globals', l: 'Globals listed', num: true, dec: 0 }, { k: 'TotRefs', l: 'References', num: true, dec: 0 }, { k: 'refsps', l: 'Refs/s', num: true, dec: 0 }, { k: 'GloSet', l: 'Sets', num: true, dec: 0 }, { k: 'GloKill', l: 'Kills', num: true, dec: 0 }, { k: 'PhyBlkRd', l: 'Phys. reads', num: true, dec: 0 }, { k: 'phyps', l: 'Phys. rd/s', num: true, dec: 0 }, { k: 'PhyBlkWrt', l: 'Phys. writes', num: true, dec: 0 }, { k: 'LogBlkRd', l: 'Logical reads', num: true, dec: 0 }, { k: 'JrnEntry', l: 'Journal', num: true, dec: 0 }, { k: 'BlkAlloc', l: 'Blocks alloc.', num: true, dec: 0 }], empty: 'No per-global table in this report.' });
	      }).catch(function (e) { SP.fail($('#tDbs'), e); });
	    },
	    proclist: function () {
	      tbl('proclist').then(function (rows) {
	        SP.table($('#tProcList'), { rows: rows, csv: 'perfmon_process_list_' + ID, columns: [{ k: 'JobNo', l: 'Job #', num: true, dec: 0 }, { k: 'DisplayPID', l: 'PID' }, { k: 'UserName', l: 'User' }, { k: 'Device', l: 'Device' }, { k: 'Namespace', l: 'Namespace' }, { k: 'Routine', l: 'Routine' }, { k: 'Commands', l: 'Commands', num: true, dec: 0 }, { k: 'Globals', l: 'Globals', num: true, dec: 0 }, { k: 'State', l: 'State' }, { k: 'ClientName', l: 'Client' }, { k: 'ExeName', l: 'Executable' }, { k: 'ClientIP', l: 'IP' }, { k: 'OSUserName', l: 'OS user' }, { k: 'CPUTime', l: 'CPU' }, { k: 'PrvGblBlkCnt', l: 'Private global blocks', num: true, dec: 0 }], empty: 'No process list in this report.' });
	      }).catch(function (e) { SP.fail($('#tProcList'), e); });
	    },
	    generic: function () {
	      tbl('generic').then(function (rows) {
	        var host = SP.clear($('#generic')), by = {};
	        rows.forEach(function (r) { (by[r.table] = by[r.table] || []).push(r); });
	        var names = Object.keys(by);
	        if (!names.length) { host.appendChild(SP.el('div', { cls: 'notice ok', text: 'Every table in this report was mapped to a dedicated tab.' })); return; }
	        names.forEach(function (n, i) {
	          var list = by[n], hdr = list[0].header, cols = hdr.map(function (h, k) { return { k: 'c' + k, l: h || ('Column ' + (k + 1)), num: false }; });
	          var data = list.map(function (r) { var o = {}; r.cells.forEach(function (v, k) { o['c' + k] = v; }); return o; });
	          cols.forEach(function (c) { c.num = data.every(function (o) { return o[c.k] == null || o[c.k] === '' || !isNaN(+String(o[c.k]).replace(/,/g, '')); }); if (c.num) data.forEach(function (o) { if (o[c.k] !== '' && o[c.k] != null) o[c.k] = +String(o[c.k]).replace(/,/g, ''); }); });
	          var d = SP.el('div'); host.appendChild(SP.el('div', { cls: 'card section' }, [SP.el('h2', { text: n }), d]));
	          SP.table(d, { rows: data, columns: cols, csv: 'perfmon_' + n });
	        });
	      }).catch(function (e) { SP.fail($('#generic'), e); });
	    },
	    report: function () {
	      var h = SP.clear($('#report'));
	      if (C && !C.hasRaw) { h.appendChild(SP.el('div', { cls: 'notice', text: 'The original report was not kept for this collection (setting "Keep raw sections" was off when it was loaded).' + (C.SourceFile ? ' Source file: ' + C.SourceFile : '') })); return; }
	      h.appendChild(SP.el('p', { cls: 'muted small' }, ['Shown in a sandboxed frame with scripts disabled. ', SP.el('a', { href: CFG.pm + '?action=raw&id=' + ID, target: '_blank', rel: 'noopener', text: 'Open in a new tab' })]));
	      var w = SP.el('div', { cls: 'iframe-wrap' }), f = SP.el('iframe', { title: 'Original PERFMON report', sandbox: '', src: CFG.pm + '?action=raw&id=' + ID });
	      w.appendChild(f); h.appendChild(w);
	    }
	  };
	  document.addEventListener('DOMContentLoaded', function () {
	    header().then(function () {
	      TABS = SP.tabs($('#tabs'), function (t) { if (t === 'findings') findings(); else if (loaders[t]) loaders[t](); });
	    });
	  });
	})();
}

}
