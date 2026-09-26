/// Dashboard: per system trends by day / week / month / custom range, KPIs vs previous period,
/// recurring findings, hour-of-week heatmap, database growth and run list.
Class SysPerf.UI.Home Extends SysPerf.UI.Base
{

Parameter NAVID = "home";

Parameter PAGETITLE = "Dashboard - IRIS Operations Portal";

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	&html<
<div class="flex" style="align-items:baseline">
  <div><h1>Performance dashboard</h1><p class="sub" id="subtitle">Trends and bottlenecks from loaded ^SystemPerformance reports.</p></div>
</div>
<div class="sp-filters" id="filters">
  <label>System<select id="fSys" aria-label="System"></select></label>
  <label>Period<span id="fRange"></span></label>
  <label id="lFrom" class="hide">From<input type="date" id="fFrom"></label>
  <label id="lTo" class="hide">To<input type="date" id="fTo"></label>
  <label>Granularity<span id="fGran"></span></label>
  <span class="muted small" id="fInfo"></span>
</div>
<div id="empty" class="hide"></div>
<div id="dash">
  <div class="kpis" id="kpis"></div>

  <div class="grid g2 section">
    <div class="card"><div class="card-h"><h2>CPU busy</h2><span class="muted small">avg and p95 per bucket</span></div><div id="cCPU"></div></div>
    <div class="card"><div class="card-h"><h2>Global references / updates</h2><span class="muted small">per second</span></div><div id="cGlo"></div></div>
    <div class="card"><div class="card-h"><h2>Physical database reads / writes</h2><span class="muted small">per second</span></div><div id="cPhy"></div></div>
    <div class="card"><div class="card-h"><h2>Global buffer cache hit</h2><span class="muted small">% of references served from memory</span></div><div id="cHit"></div></div>
    <div class="card"><div class="card-h"><h2>Disk latency (worst device)</h2><span class="muted small">milliseconds</span></div><div id="cDisk"></div></div>
    <div class="card"><div class="card-h"><h2>Available memory</h2><span class="muted small">MB</span></div><div id="cMem"></div></div>
    <div class="card"><div class="card-h"><h2>Journal and WIJ writes</h2><span class="muted small">per second</span></div><div id="cJrn"></div></div>
    <div class="card"><div class="card-h"><h2>Write daemon queue</h2><span class="muted small">blocks (max per bucket)</span></div><div id="cWD"></div></div>
    <div class="card"><div class="card-h"><h2>Routine loads / saves</h2><span class="muted small">per second (routine cache misses)</span></div><div id="cRou"></div></div>
    <div class="card"><div class="card-h"><h2>IRIS processes</h2><span class="muted small">from %SS samples</span></div><div id="cProc"></div></div>
  </div>

  <div class="card section">
    <div class="card-h"><h2>Explore any metric</h2>
      <div class="card-tools"><select id="xMetric" aria-label="Metric"></select><select id="xEnt" class="hide" aria-label="Device"></select><span id="xStat"></span></div></div>
    <div id="cX"></div>
  </div>

  <div class="grid g2 section">
    <div class="card"><div class="card-h"><h2>When is the system busiest?</h2>
      <div class="card-tools"><select id="hmMetric" aria-label="Heatmap metric"></select><select id="hmStat" aria-label="Statistic"><option value="avg">average</option><option value="p95">p95</option><option value="max">max</option></select></div></div>
      <div id="cHM"></div><p class="muted small">Day of week × hour of day over the selected period. Use it to schedule batch jobs, purges and backups away from peaks.</p></div>
    <div class="card"><div class="card-h"><h2>Health score per run</h2><span class="muted small">100 − 15 per critical − 5 per warning</span></div><div id="cHealth"></div></div>
  </div>

  <div class="card section"><div class="card-h"><h2>Bottlenecks and recommendations in this period</h2><span class="muted small" id="fCount"></span></div><div id="findings"></div></div>

  <div class="grid g2 section">
    <div class="card"><div class="card-h"><h2>Database growth</h2><span class="muted small">size at the end of each run (MB)</span></div><div id="cDB"></div></div>
    <div class="card"><div class="card-h"><h2>Runs in this period</h2><button class="btn sm" id="btnHourly">Download hourly data (CSV)</button></div><div id="runs"></div></div>
  </div>
</div>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var S = { sys: '', preset: '7d', from: '', to: '', gran: 'auto', systems: [], metrics: [], anchor: '' };
	  var $ = SP.$;
	  var charts = {};
	  try { S.sys = localStorage.getItem('sysperf.sys') || ''; S.preset = localStorage.getItem('sysperf.preset') || '7d'; } catch (e) {}

	  function addDays(d, n) { var t = SP.ts(d + ' 00:00:00'); var x = new Date(t); x.setDate(x.getDate() + n); return SP.dstr(x.getTime()); }
	  function period() {
	    var a = S.anchor || SP.dstr(Date.now());
	    if (S.preset === 'custom') return { from: S.from || addDays(a, -6), to: S.to || a };
	    var days = { '1d': 1, '7d': 7, '30d': 30, '90d': 90, '365d': 365 }[S.preset] || 7;
	    if (S.preset === 'mtd') return { from: a.slice(0, 8) + '01', to: a };
	    return { from: addDays(a, -(days - 1)), to: a };
	  }
	  function gran(p) {
	    if (S.gran !== 'auto') return S.gran;
	    var days = (SP.ts(p.to + ' 00:00:00') - SP.ts(p.from + ' 00:00:00')) / 864e5 + 1;
	    return days > 31 ? 'day' : 'hour';
	  }

	  function init() {
	    SP.seg($('#fRange'), [{ v: '1d', l: 'Day' }, { v: '7d', l: 'Week' }, { v: '30d', l: 'Month' }, { v: 'mtd', l: 'Month to date' }, { v: '90d', l: '90 days' }, { v: '365d', l: 'Year' }, { v: 'custom', l: 'Custom' }], S.preset, function (v) {
	      S.preset = v; try { localStorage.setItem('sysperf.preset', v); } catch (e) {}
	      $('#lFrom').classList.toggle('hide', v !== 'custom'); $('#lTo').classList.toggle('hide', v !== 'custom');
	      if (v === 'custom') { var p = period(); $('#fFrom').value = p.from; $('#fTo').value = p.to; }
	      load();
	    });
	    SP.seg($('#fGran'), [{ v: 'auto', l: 'Auto' }, { v: 'hour', l: 'Hourly' }, { v: 'day', l: 'Daily' }], S.gran, function (v) { S.gran = v; load(); });
	    $('#lFrom').classList.toggle('hide', S.preset !== 'custom'); $('#lTo').classList.toggle('hide', S.preset !== 'custom');
	    $('#fFrom').addEventListener('change', function () { S.from = this.value; load(); });
	    $('#fTo').addEventListener('change', function () { S.to = this.value; load(); });
	    $('#fSys').addEventListener('change', function () { S.sys = this.value; try { localStorage.setItem('sysperf.sys', S.sys); } catch (e) {} setAnchor(); load(); });
	    $('#xMetric').addEventListener('change', function () { explore(); });
	    $('#xEnt').addEventListener('change', function () { explore(); });
	    $('#hmMetric').addEventListener('change', heat); $('#hmStat').addEventListener('change', heat);
	    $('#btnHourly').addEventListener('click', function () {
	      var p = period();
	      SP.api('hourly', { sys: S.sys, from: p.from, to: p.to }).then(function (j) {
	        SP.csv('hourly_' + S.sys + '_' + p.from + '_' + p.to, [{ k: 'HourTS', l: 'Hour' }, { k: 'Metric', l: 'Metric' }, { k: 'Entity', l: 'Entity' }, { k: 'Cnt', l: 'Samples' }, { k: 'AvgV', l: 'Avg' }, { k: 'MinV', l: 'Min' }, { k: 'MaxV', l: 'Max' }, { k: 'P95', l: 'P95' }, { k: 'Run', l: 'Run ID' }], j.rows);
	      });
	    });
	    Promise.all([SP.api('systems'), SP.api('metrics')]).then(function (r) {
	      S.systems = r[0].systems; S.metrics = r[1].metrics;
	      if (!S.systems.length) {
	        $('#dash').classList.add('hide'); $('#filters').classList.add('hide');
	        var e = $('#empty'); e.classList.remove('hide');
	        e.appendChild(SP.el('div', { cls: 'notice' }, ['No reports loaded yet. ', SP.el('a', { href: 'SysPerf.UI.Upload.cls', text: 'Load a ^SystemPerformance report' }), ' or configure the inbox folder so the daily task picks them up.']));
	        return;
	      }
	      var sel = $('#fSys');
	      S.systems.forEach(function (s) { sel.appendChild(SP.el('option', { value: s.sys, text: s.sys + '  (' + s.runs + ' run' + (s.runs === 1 ? '' : 's') + ')' })); });
	      if (!S.systems.some(function (s) { return s.sys === S.sys; })) S.sys = S.systems[0].sys;
	      sel.value = S.sys;
	      var xm = $('#xMetric'), hm = $('#hmMetric'), cat = '';
	      var og = null;
	      S.metrics.forEach(function (m) {
	        if (m.cat !== cat) { cat = m.cat; og = SP.el('optgroup', { label: cat }); xm.appendChild(og); }
	        og.appendChild(SP.el('option', { value: m.code, text: m.label + ' (' + m.unit + ')' }));
	        if (m.table !== 'DiskStat') hm.appendChild(SP.el('option', { value: m.code, text: m.label }));
	      });
	      xm.value = 'Glorefs'; hm.value = 'Glorefs';
	      setAnchor(); load();
	    }).catch(function (e) { SP.fail($('#dash'), e); });
	  }
	  function setAnchor() {
	    var s = S.systems.filter(function (x) { return x.sys === S.sys; })[0];
	    S.anchor = s && s.lastTS ? s.lastTS.slice(0, 10) : SP.dstr(Date.now());
	  }
	  function metric(code) { return S.metrics.filter(function (m) { return m.code === code; })[0] || { label: code, unit: '' }; }
	  function toPts(series, idx) { return (series.pts || []).map(function (p) { return [SP.ts(p[0]), p[idx]]; }); }

	  function load() {
	    var p = period(), g = gran(p);
	    $('#fInfo').textContent = p.from + ' → ' + p.to + ' · data up to ' + (S.anchor || '–');
	    $('#subtitle').textContent = S.sys + ' · ' + p.from + ' to ' + p.to;
	    SP.$$('.chart').forEach(function (c) { c.classList.add('loading'); });
	    var common = { sys: S.sys, from: p.from, to: p.to, gran: g };
	    kpis(common);
	    SP.api('series', Object.assign({ metrics: 'CPUBusyPct,Glorefs,Gloupds,PhyRds,PhyWrs,CacheHitPct,DiskMaxReadLatMs,DiskMaxWriteLatMs,MemAvailMB,Jrnwrts,WIJwri,WDQsz,RouLaS,IRISProcesses' }, common)).then(function (j) {
	      var by = {}; j.series.forEach(function (s) { by[s.metric] = s; });
	      var dOnly = g === 'day';
	      function single(host, code, opts) {
	        var s = by[code] || { pts: [] };
	        var ser = [{ name: 'avg', pts: toPts(s, 1), color: 'var(--s1)' }];
	        if (opts.p95 !== false) ser.push({ name: opts.p95Name || 'p95', pts: toPts(s, opts.p95Idx || 2), color: 'var(--s1)', dash: true, width: 1.5 });
	        SP.lineChart($(host), Object.assign({ series: ser, unit: s.unit || metric(code).unit, dateOnly: dOnly, height: 210 }, opts));
	      }
	      function multi(host, codes, idx, opts) {
	        var ser = codes.map(function (c, i) { var s = by[c] || { pts: [] }; return { name: (s.label || metric(c).label), pts: toPts(s, idx || 1), color: SP.color(i) }; });
	        SP.lineChart($(host), Object.assign({ series: ser, dateOnly: dOnly, height: 210 }, opts || {}));
	      }
	      single('#cCPU', 'CPUBusyPct', { refs: [{ v: 70, label: 'warn 70%' }, { v: 85, label: 'crit 85%' }], yMax: 100, empty: 'No OS CPU data (perfmon / vmstat / sar not collected)' });
	      multi('#cGlo', ['Glorefs', 'Gloupds'], 1, { unit: '/s' });
	      multi('#cPhy', ['PhyRds', 'PhyWrs'], 1, { unit: '/s' });
	      single('#cHit', 'CacheHitPct', { p95: true, p95Idx: 4, p95Name: 'min', yZero: false, refs: [{ v: 99, label: 'warn 99%' }] });
	      multi('#cDisk', ['DiskMaxReadLatMs', 'DiskMaxWriteLatMs'], 1, { unit: 'ms', refs: [{ v: 10, label: '10 ms' }], empty: 'No disk data (perfmon / iostat / sar -d not collected)' });
	      single('#cMem', 'MemAvailMB', { p95Idx: 4, p95Name: 'min', empty: 'No OS memory time-series' });
	      multi('#cJrn', ['Jrnwrts', 'WIJwri'], 1, { unit: '/s' });
	      single('#cWD', 'WDQsz', { p95: true, p95Idx: 3, p95Name: 'max' });
	      single('#cRou', 'RouLaS', { p95Idx: 3, p95Name: 'max' });
	      single('#cProc', 'IRISProcesses', { p95Idx: 3, p95Name: 'max' });
	    }).catch(function (e) { SP.fail($('#cCPU'), e); });
	    explore(); heat();
	    SP.api('findings', common).then(function (j) {
	      var list = j.findings.sort(function (a, b) { return (b.rank - a.rank) || (b.count - a.count); });
	      $('#fCount').textContent = list.length + ' distinct finding' + (list.length === 1 ? '' : 's') + ' across runs';
	      list.forEach(function (f) { f.title = f.title + (f.count > 1 ? '  (in ' + f.count + ' runs)' : ''); f.last = f.lastTS ? 'last seen ' + f.lastTS : ''; });
	      SP.findings($('#findings'), list, { linkRun: true });
	    }).catch(function (e) { SP.fail($('#findings'), e); });
	    SP.api('runs', common).then(function (j) {
	      SP.table($('#runs'), {
	        rows: j.runs, page: 10, csv: 'runs', sort: { k: 'startTS', dir: 'desc' },
	        columns: [
	          { k: 'startTS', l: 'Start', link: function (r) { return 'SysPerf.UI.Run.cls?id=' + r.id; } },
	          { k: 'profile', l: 'Profile' },
	          { k: 'samples', l: 'Samples', num: true },
	          { k: 'health', l: 'Health', num: true, render: function (v) { return SP.score(v); } },
	          { k: 'crit', l: 'Crit', num: true }, { k: 'warn', l: 'Warn', num: true }
	        ]
	      });
	      var pts = j.runs.slice().reverse().map(function (r) { return [SP.ts(r.startTS), r.health]; });
	      SP.lineChart($('#cHealth'), { series: [{ name: 'health', pts: pts, color: 'var(--s1)' }], yMax: 100, height: 200, refs: [{ v: 80, label: 'good ≥ 80' }], zoom: false, onClick: function (x) {
	        var best = null; j.runs.forEach(function (r) { var d = Math.abs(SP.ts(r.startTS) - x); if (!best || d < best.d) best = { d: d, id: r.id }; });
	        if (best) location.href = 'SysPerf.UI.Run.cls?id=' + best.id;
	      } });
	      $('#cHealth').appendChild(SP.el('div', { cls: 'muted small', text: 'Click a point to open the run.' }));
	    }).catch(function (e) { SP.fail($('#runs'), e); });
	    SP.api('dbgrowth', common).then(function (j) {
	      var dbs = j.dbs.map(function (d) { return { name: d.name, pts: d.pts.map(function (p) { return [SP.ts(p[0]), p[1]]; }), last: d.pts.length ? d.pts[d.pts.length - 1][1] : 0 }; });
	      dbs.sort(function (a, b) { return b.last - a.last; });
	      var top = dbs.slice(0, 8);
	      top.sort(function (a, b) { return a.name < b.name ? -1 : 1; });
	      SP.lineChart($('#cDB'), { series: top.map(function (d, i) { return { name: d.name, pts: d.pts, color: SP.color(i) }; }), unit: 'MB', height: 230 });
	      if (dbs.length > 8) $('#cDB').appendChild(SP.el('div', { cls: 'muted small', text: 'Showing the 8 largest of ' + dbs.length + ' databases. All sizes are on each run\'s Databases tab.' }));
	    }).catch(function (e) { SP.fail($('#cDB'), e); });
	  }

	  function kpis(common) {
	    SP.api('kpis', common).then(function (j) {
	      var host = SP.clear($('#kpis'));
	      var by = {}; j.kpis.forEach(function (k) { by[k.metric] = k; });
	      function delta(cur, prev, better) {
	        if (cur == null || prev == null || prev === 0) return SP.el('span', { text: prev == null ? 'no previous period' : '' });
	        var pct = (cur - prev) / Math.abs(prev) * 100, up = pct >= 0;
	        var good = better === 'H' ? up : better === 'L' ? !up : null;
	        var cls = good === null ? '' : (up ? (good ? 'up-good' : 'up-bad') : (good ? 'down-good' : 'down-bad'));
	        return SP.el('span', { cls: cls, text: (up ? '▲ ' : '▼ ') + SP.fmt(Math.abs(pct), 1) + '% vs previous' });
	      }
	      function tile(label, val, unit, sub, dnode, st) {
	        var t = SP.el('div', { cls: 'kpi' + (st ? ' st-' + st : '') }, [SP.el('div', { cls: 'k-l', text: label, title: label }), SP.el('div', { cls: 'k-v' }, [val, unit ? SP.el('small', { text: unit }) : null]), SP.el('div', { cls: 'k-d' }, [sub ? SP.el('span', { text: sub + '  ' }) : null, dnode || null])]);
	        host.appendChild(t);
	      }
	      var hs = j.healthAvg;
	      tile('Health (avg of ' + (j.runs || 0) + ' runs)', hs == null ? '–' : String(hs), '', 'worst ' + (j.healthMin == null ? '–' : j.healthMin) + ' · ' + (j.crit || 0) + ' crit / ' + (j.warn || 0) + ' warn', delta(hs, j.prevHealth, 'H'), hs == null ? '' : hs >= 80 ? 'OK' : hs >= 55 ? 'W' : 'C');
	      function mk(code, which, label, better, st) {
	        var k = by[code] || {}, v = k[which], prev = which === 'p95' ? k.prevP95 : k.prevAvg;
	        tile(label, SP.fmt(v), k.unit, which === 'avg' && k.p95 != null ? 'peak-hour p95 ' + SP.fmt(k.p95) : (which === 'min' ? '' : (k.max != null ? 'max ' + SP.fmt(k.max) : '')), which === 'min' ? null : delta(v, prev, better), st ? st(v) : '');
	      }
	      mk('CPUBusyPct', 'avg', 'CPU busy (avg)', 'L', function (v) { return v == null ? '' : v > 85 ? 'C' : v > 70 ? 'W' : 'OK'; });
	      mk('Glorefs', 'avg', 'Global refs /s (avg)', null);
	      mk('PhyRds', 'avg', 'Physical reads /s (avg)', 'L');
	      mk('CacheHitPct', 'avg', 'Cache hit % (avg)', 'H', function (v) { return v == null ? '' : v < 95 ? 'C' : v < 99 ? 'W' : 'OK'; });
	      mk('DiskMaxReadLatMs', 'p95', 'Disk read latency (peak-hour p95)', 'L', function (v) { return v == null ? '' : v > 20 ? 'C' : v > 10 ? 'W' : 'OK'; });
	      mk('DiskMaxWriteLatMs', 'p95', 'Disk write latency (peak-hour p95)', 'L', function (v) { return v == null ? '' : v > 20 ? 'C' : v > 10 ? 'W' : 'OK'; });
	      mk('MemAvailMB', 'min', 'Available memory (min)', 'H');
	      mk('Jrnwrts', 'avg', 'Journal writes /s (avg)', null);
	    }).catch(function (e) { SP.fail($('#kpis'), e); });
	  }

	  function explore() {
	    var p = period(), g = gran(p), code = $('#xMetric').value || 'Glorefs', m = metric(code);
	    var entSel = $('#xEnt');
	    if (m.table === 'DiskStat') {
	      entSel.classList.remove('hide');
	      if (!entSel.options.length) entSel.appendChild(SP.el('option', { value: '*', text: 'All devices' }));
	    } else entSel.classList.add('hide');
	    var ent = m.table === 'DiskStat' ? (entSel.value || '*') : '-';
	    if (!S.xStat) { S.xStat = 'avg'; SP.seg($('#xStat'), [{ v: 'avg', l: 'Avg' }, { v: 'p95', l: 'P95' }, { v: 'max', l: 'Max' }], 'avg', function (v) { S.xStat = v; explore(); }); }
	    var idx = { avg: 1, p95: 2, max: 3 }[S.xStat];
	    SP.api('series', { sys: S.sys, from: p.from, to: p.to, gran: g, metrics: code, entity: ent }).then(function (j) {
	      if (m.table === 'DiskStat' && entSel.options.length <= 1) j.series.forEach(function (s) { entSel.appendChild(SP.el('option', { value: s.entity, text: s.entity })); });
	      var ser = j.series.slice(0, 8).map(function (s, i) { return { name: s.entity !== '-' ? s.entity : S.xStat, pts: toPts(s, idx), color: SP.color(i) }; });
	      SP.lineChart($('#cX'), { series: ser, unit: m.unit, dateOnly: g === 'day', height: 240 });
	    }).catch(function (e) { SP.fail($('#cX'), e); });
	  }
	  function heat() {
	    var p = period();
	    SP.api('heatmap', { sys: S.sys, from: p.from, to: p.to, metric: $('#hmMetric').value || 'Glorefs', stat: $('#hmStat').value }).then(function (j) {
	      SP.heatmap($('#cHM'), { cells: j.cells, unit: j.unit });
	    }).catch(function (e) { SP.fail($('#cHM'), e); });
	  }
	  document.addEventListener('DOMContentLoaded', init);
	})();
}

}
