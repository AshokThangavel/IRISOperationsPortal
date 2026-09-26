/// Portal home: instance status, live workload, latest SystemPerformance / PERFMON analysis,
/// interoperability overview and recent alerts.
Class SysPerf.UI.Portal Extends SysPerf.UI.Base
{

Parameter NAVID = "portal";

Parameter PAGETITLE = "Home - IRIS Operations Portal";

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	&html<
<h1 id="hTitle">IRIS Operations Portal</h1>
<p class="sub" id="hSub">Live status of this instance and the latest performance analysis.</p>
<div class="stat" id="stat"></div>
<div class="grid g2 section">
  <div class="card"><div class="card-h"><h2>Global references / second</h2><a class="small" href="SysPerf.UI.Live.cls">System dashboard ›</a></div><div id="cRefs"></div></div>
  <div class="card"><div class="card-h"><h2>Physical reads / second</h2><span class="muted small">sampled every 5 s while this page is open</span></div><div id="cPhy"></div></div>
</div>
<div class="grid g3 section">
  <a class="card tile-link" href="SysPerf.UI.Runs.cls" id="tSP"><h2>SystemPerformance</h2><div id="spBody" class="muted">No report loaded yet</div></a>
  <a class="card tile-link" href="SysPerf.UI.PMHome.cls" id="tPM"><h2>PERFMON</h2><div id="pmBody" class="muted">No collection yet</div></a>
  <a class="card tile-link" href="SysPerf.UI.Interop.cls?v=productions"><h2>Interoperability</h2><div id="intBody" class="muted">Loading…</div></a>
</div>
<div class="grid g2 section">
  <div class="card"><div class="card-h"><h2>Recent warnings and errors (messages.log)</h2><a class="small" href="SysPerf.UI.Ops.cls?v=logs">System logs ›</a></div><div id="log"></div></div>
  <div class="card"><h2>Go to</h2><div class="grid g2" id="links"></div></div>
</div>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, hist = { refs: [], phy: [] }, prev = null;
	  function statGrid(d) {
	    var host = SP.clear($('#stat'));
	    function st(label, val, cls, href) {
	      var v = SP.el('div', { cls: 'v' }, [cls ? SP.el('span', { cls: 'dot ' + cls }) : null, String(val == null || val === '' ? '–' : val)]);
	      var box = SP.el(href ? 'a' : 'div', { href: href || null, cls: href ? 'tile-link' : null }, [SP.el('div', { cls: 'l', text: label }), v]);
	      host.appendChild(box);
	    }
	    st('Uptime', String(d.SystemUpTime || '').replace(/\s+/g, ' '));
	    st('Processes', d.Processes, '', 'SysPerf.UI.Ops.cls?v=processes');
	    st('Web sessions', d.CSPSessions);
	    st('License units', (d.licenseUsed != null ? d.licenseUsed : d.LicenseCurrent) + ' / ' + (d.licenseLimit || d.LicenseLimit), (d.LicenseCurrentPct > 90 ? 'bad' : d.LicenseCurrentPct > 75 ? 'warn' : 'ok'), 'SysPerf.UI.Ops.cls?v=license');
	    st('Journal', d.JournalStatus, SP.status(d.JournalStatus), 'SysPerf.UI.Ops.cls?v=journals');
	    st('Journal space', d.JournalSpace, SP.status(d.JournalSpace));
	    st('Database space', d.DatabaseSpace, SP.status(d.DatabaseSpace), 'SysPerf.UI.Ops.cls?v=databases');
	    st('Write daemon', d.WriteDaemon, SP.status(d.WriteDaemon));
	    st('Lock table', d.LockTable, SP.status(d.LockTable), 'SysPerf.UI.Ops.cls?v=locks');
	    st('Serious alerts', d.SeriousAlerts, +d.SeriousAlerts > 0 ? 'bad' : 'ok', 'SysPerf.UI.Ops.cls?v=logs');
	    st('Application errors', d.ApplicationErrors, +d.ApplicationErrors > 0 ? 'warn' : 'ok', 'SysPerf.UI.Ops.cls?v=apperrors');
	    st('Last backup', d.LastBackup || 'none recorded', d.LastBackup ? 'ok' : 'warn');
	    if (d.mirrorMember) st('Mirror', (d.mirrorType || '') + ' ' + (d.mirrorStatus || ''), SP.status(d.mirrorStatus), 'SysPerf.UI.Ops.cls?v=mirror');
	  }
	  function poll() {
	    SP.live('counters').then(function (c) {
	      if (prev) {
	        var dt = (c.ms - prev.ms) / 1000;
	        if (dt > 0) {
	          var t = Date.now();
	          hist.refs.push([t, Math.max(0, (c.gloRefs - prev.gloRefs) / dt)]);
	          hist.phy.push([t, Math.max(0, (c.physReads - prev.physReads) / dt)]);
	          if (hist.refs.length > 120) { hist.refs.shift(); hist.phy.shift(); }
	          SP.lineChart($('#cRefs'), { series: [{ name: 'refs/s', pts: hist.refs, color: 'var(--s1)' }], unit: '/s', height: 170, zoom: false, hint: false });
	          SP.lineChart($('#cPhy'), { series: [{ name: 'reads/s', pts: hist.phy, color: 'var(--s2)' }], unit: '/s', height: 170, zoom: false, hint: false });
	        }
	      }
	      prev = c;
	    }).catch(function () {});
	  }
	  document.addEventListener('DOMContentLoaded', function () {
	    SP.live('portal').then(function (p) {
	      var d = p.sys;
	      $('#hTitle').textContent = d.instance + ' on ' + d.host;
	      $('#hSub').textContent = d.version;
	      statGrid(d);
	      var sb = SP.clear($('#spBody'));
	      if (p.lastRun) {
	        sb.classList.remove('muted');
	        sb.appendChild(SP.el('div', { cls: 'flex' }, [SP.score(p.lastRun.health), SP.el('span', { text: p.lastRun.sys })]));
	        sb.appendChild(SP.el('p', { cls: 'bigsub', text: 'Latest run ' + p.lastRun.start + ' · ' + p.lastRun.crit + ' critical, ' + p.lastRun.warn + ' warnings · ' + p.runs + ' runs loaded' }));
	        $('#tSP').href = 'SysPerf.UI.Run.cls?id=' + p.lastRun.id;
	      } else sb.appendChild(SP.el('p', { text: 'Load a ^SystemPerformance report to see trends and bottlenecks.' }));
	      var pb = SP.clear($('#pmBody'));
	      if (p.lastPM) {
	        pb.classList.remove('muted');
	        pb.appendChild(SP.el('div', { cls: 'flex' }, [SP.score(p.lastPM.health), SP.el('span', { text: p.lastPM.sys })]));
	        pb.appendChild(SP.el('p', { cls: 'bigsub', text: 'Latest collection ' + p.lastPM.ts + ' · ' + p.lastPM.crit + ' critical, ' + p.lastPM.warn + ' warnings · ' + p.collections + ' collections' }));
	        $('#tPM').href = 'SysPerf.UI.PMRun.cls?id=' + p.lastPM.id;
	      } else pb.appendChild(SP.el('p', { text: 'Run a PERFMON timed collection to see which globals, routines and processes drive the load.' }));
	    }).catch(function (e) { SP.fail($('#stat'), e); });
	    SP.live('interop').then(function (j) {
	      var b = SP.clear($('#intBody')); b.classList.remove('muted');
	      var withProd = j.namespaces.filter(function (n) { return n.production; });
	      if (!withProd.length) { b.appendChild(SP.el('p', { cls: 'muted', text: j.namespaces.length ? 'No productions configured.' : 'No interoperability namespaces.' })); return; }
	      withProd.forEach(function (n) {
	        var cls = n.state === 1 ? 'ok' : n.state === 4 || n.state === 3 ? 'bad' : 'warn';
	        b.appendChild(SP.el('div', { cls: 'flex', style: 'margin:4px 0' }, [SP.el('span', { cls: 'dot ' + cls }), SP.el('b', { text: n.namespace }), SP.el('span', { cls: 'bigsub', text: n.stateText + ' · ' + SP.fmt(n.queued) + ' queued · ' + SP.fmt(n.errors24h) + ' errors 24h' })]));
	      });
	    }).catch(function (e) { SP.fail($('#intBody'), e); });
	    SP.live('log', { lines: 3000, min: 2 }).then(function (j) {
	      SP.table($('#log'), { rows: j.lines.slice(0, 12), page: 12, search: false, csv: false, columns: [{ k: 'ts', l: 'Time', cls: 'nowrap' }, { k: 'sev', l: 'Sev', num: true, dec: 0 }, { k: 'src', l: 'Source' }, { k: 'text', l: 'Message', cls: 'wrap' }], empty: 'No warnings or errors in the recent log.' });
	    }).catch(function (e) { SP.fail($('#log'), e); });
	    var L = [['System Dashboard', 'SysPerf.UI.Live.cls'], ['Application Error Log', 'SysPerf.UI.Ops.cls?v=apperrors'], ['Processes', 'SysPerf.UI.Ops.cls?v=processes'], ['Databases', 'SysPerf.UI.Ops.cls?v=databases'], ['Journals', 'SysPerf.UI.Ops.cls?v=journals'], ['Productions', 'SysPerf.UI.Interop.cls?v=productions'], ['Event Log', 'SysPerf.UI.Interop.cls?v=events'], ['SystemPerformance trends', 'SysPerf.UI.Home.cls'], ['PERFMON collections', 'SysPerf.UI.PMHome.cls'], ['Run PERFMON collection', 'SysPerf.UI.PMHome.cls?tab=collect'], ['Load SystemPerformance files', 'SysPerf.UI.Upload.cls'], ['Load PERFMON files', 'SysPerf.UI.PMLoad.cls']];
	    L.forEach(function (x) { $('#links').appendChild(SP.el('a', { cls: 'btn', href: x[1], text: x[0] })); });
	    poll(); setInterval(poll, 5000);
	  });
	})();
}

}
