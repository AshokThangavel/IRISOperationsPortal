/// Live system dashboard: rates computed from cumulative SYS.Stats counters, polled while the page is open.
Class SysPerf.UI.Live Extends SysPerf.UI.Base
{

Parameter NAVID = "live";

Parameter PAGETITLE = "System Dashboard - IRIS Operations Portal";

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	&html<
<h1>System Dashboard</h1>
<p class="sub">Rates are calculated in the browser from the instance's cumulative counters. Nothing is stored; the history resets when you leave the page.</p>
<div class="sp-filters">
  <label>Refresh every<div id="fInt"></div></label>
  <button class="btn" id="btnPause" type="button">Pause</button>
  <span class="muted small" id="lastUpd"></span>
</div>
<div class="stat" id="kpi"></div>
<div class="grid g2 section">
  <div class="card"><h2>Global references and updates / s</h2><div id="cGlo"></div></div>
  <div class="card"><h2>Physical block reads and writes / s</h2><div id="cPhy"></div></div>
  <div class="card"><h2>Routine lines / s</h2><div id="cRtn"></div></div>
  <div class="card"><h2>Journal entries / s</h2><div id="cJrn"></div></div>
  <div class="card"><h2>Processes and web sessions</h2><div id="cProc"></div></div>
  <div class="card"><h2>Buffer cache efficiency (logical ÷ physical reads)</h2><div id="cEff"></div></div>
</div>
<div class="card section"><div class="card-h"><h2>System status</h2><a class="small" href="SysPerf.UI.Ops.cls?v=logs">System logs ›</a></div><div class="stat" id="status"></div></div>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, prev = null, H = {}, timer = null, paused = false, iv = 5000, MAX = 180;
	  try { iv = +localStorage.getItem('sysperf.liveiv') || 5000; } catch (e) {}
	  function push(k, t, v) { (H[k] = H[k] || []).push([t, v]); if (H[k].length > MAX) H[k].shift(); }
	  function kpi(host, label, val, unit, cls) {
	    host.appendChild(SP.el('div', {}, [SP.el('div', { cls: 'l', text: label }), SP.el('div', { cls: 'v' }, [cls ? SP.el('span', { cls: 'dot ' + cls }) : null, val == null ? '–' : (typeof val === 'number' ? SP.fmt(val, val < 10 ? 1 : 0) : String(val)) + (unit ? ' ' + unit : '')])]));
	  }
	  function charts() {
	    var o = { unit: '/s', height: 180, zoom: false };
	    SP.lineChart($('#cGlo'), Object.assign({}, o, { series: [{ name: 'References', pts: H.refs || [] }, { name: 'Updates', pts: H.upd || [] }] }));
	    SP.lineChart($('#cPhy'), Object.assign({}, o, { series: [{ name: 'Reads', pts: H.prd || [] }, { name: 'Writes', pts: H.pwr || [] }] }));
	    SP.lineChart($('#cRtn'), Object.assign({}, o, { series: [{ name: 'Lines', pts: H.rtn || [] }] }));
	    SP.lineChart($('#cJrn'), Object.assign({}, o, { series: [{ name: 'Entries', pts: H.jrn || [] }] }));
	    SP.lineChart($('#cProc'), { height: 180, zoom: false, series: [{ name: 'Processes', pts: H.proc || [] }, { name: 'Web sessions', pts: H.csp || [] }] });
	    SP.lineChart($('#cEff'), { height: 180, zoom: false, unit: ':1', series: [{ name: 'Logical ÷ physical', pts: H.eff || [] }], empty: 'No physical reads in the sample – everything is served from cache' });
	  }
	  function tick() {
	    SP.live('counters').then(function (c) {
	      var t = Date.now();
	      if (prev) {
	        var dt = (c.ms - prev.ms) / 1000; if (dt <= 0) { prev = c; return; }
	        function r(k) { return Math.max(0, (c[k] - prev[k]) / dt); }
	        var refs = r('gloRefs'), upd = r('gloUpdates'), lr = r('logicalReads'), prd = r('physReads'), pwr = r('physWrites'), jrn = r('jrnEntries'), rtn = r('rtnLines');
	        push('refs', t, refs); push('upd', t, upd); push('prd', t, prd); push('pwr', t, pwr); push('jrn', t, jrn); push('rtn', t, rtn);
	        if (prd > 0) push('eff', t, lr / prd);
	        var k = SP.clear($('#kpi'));
	        kpi(k, 'Global refs / s', refs); kpi(k, 'Global updates / s', upd); kpi(k, 'Logical reads / s', lr);
	        kpi(k, 'Physical reads / s', prd, '', prd > 5000 ? 'warn' : ''); kpi(k, 'Physical writes / s', pwr); kpi(k, 'Journal entries / s', jrn);
	        kpi(k, 'Routine lines / s', rtn); kpi(k, 'Write daemon queue', c.wdQueue, '', c.wdQueue > 10000 ? 'warn' : '');
	        kpi(k, 'Processes', c.processes); kpi(k, 'Web sessions', c.cspSessions);
	        kpi(k, 'License units', c.licenseCurrent + ' / ' + c.licenseLimit, '', c.licenseLimit && c.licenseCurrent / c.licenseLimit > 0.9 ? 'bad' : c.licenseLimit && c.licenseCurrent / c.licenseLimit > 0.75 ? 'warn' : 'ok');
	      }
	      push('proc', t, c.processes); push('csp', t, c.cspSessions);
	      prev = c; charts();
	      $('#lastUpd').textContent = 'Updated ' + SP.tstr(t, true) + (prev ? '' : ' (collecting first interval…)');
	    }).catch(function (e) { $('#lastUpd').textContent = 'Refresh failed: ' + (e.message || e); });
	  }
	  function status() {
	    SP.live('sysinfo').then(function (d) {
	      var s = SP.clear($('#status'));
	      [['Uptime', d.SystemUpTime], ['Last backup', d.LastBackup || 'none recorded'], ['Database space', d.DatabaseSpace], ['Journal', d.JournalStatus], ['Journal space', d.JournalSpace], ['Journal state', d.journalState], ['Lock table', d.LockTable], ['Write daemon', d.WriteDaemon], ['ECP app server', d.ECPAppServer], ['ECP data server', d.ECPDataServer], ['Application errors', d.ApplicationErrors], ['Serious alerts', d.SeriousAlerts], ['Cache efficiency', d.CacheEfficiency], ['License', d.LicenseType], ['Mirror', d.mirrorMember ? d.mirrorType + ' – ' + d.mirrorStatus : 'not a mirror member']].forEach(function (x) {
	        var v = x[1] == null || x[1] === '' ? '–' : String(x[1]), cls = '';
	        if (/Application errors|Serious alerts/.test(x[0])) cls = +v > 0 ? (x[0] === 'Serious alerts' ? 'bad' : 'warn') : 'ok';
	        else if (!/Uptime|Cache|License|Last backup|Mirror/.test(x[0]) || x[0] === 'Mirror' && d.mirrorMember) cls = SP.status(v);
	        kpi(s, x[0], v.replace(/\s+/g, ' '), '', cls);
	      });
	    }).catch(function (e) { SP.fail($('#status'), e); });
	  }
	  function schedule() { clearInterval(timer); if (!paused) timer = setInterval(tick, iv); }
	  document.addEventListener('DOMContentLoaded', function () {
	    SP.seg($('#fInt'), [{ v: 2000, l: '2 s' }, { v: 5000, l: '5 s' }, { v: 10000, l: '10 s' }, { v: 30000, l: '30 s' }], iv, function (v) { iv = v; try { localStorage.setItem('sysperf.liveiv', v); } catch (e) {} schedule(); });
	    $('#btnPause').addEventListener('click', function () { paused = !paused; this.textContent = paused ? 'Resume' : 'Pause'; schedule(); if (!paused) tick(); });
	    document.addEventListener('visibilitychange', function () { if (document.hidden) clearInterval(timer); else { schedule(); tick(); } });
	    tick(); status(); schedule(); setInterval(status, 60000);
	  });
	})();
}

}
