/// Compare two runs: key metrics side by side with change %, overlaid time-series (elapsed time),
/// findings that are new / resolved / changed, and CPF parameters that differ.
Class SysPerf.UI.Compare Extends SysPerf.UI.Base
{

Parameter NAVID = "compare";

Parameter PAGETITLE = "Compare runs - IRIS Operations Portal";

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	&html<
<h1>Compare two runs</h1><p class="sub">Baseline (A) against another run (B) - same system before / after a change, or two different servers.</p>
<div class="sp-filters">
  <label>Run A (baseline)<select id="fA"></select></label>
  <label>Run B<select id="fB"></select></label>
  <button class="btn primary" id="go">Compare</button>
</div>
<div id="out" class="hide">
  <div class="grid g2"><div class="card" id="briefA"></div><div class="card" id="briefB"></div></div>
  <div class="card section"><div class="card-h"><h2>Overlay</h2><div class="card-tools"><select id="ovMetric"></select></div></div><div id="ov"></div><p class="muted small">x = minutes since the start of each run, so runs of different days line up.</p></div>
  <div class="card section"><h2>Key metrics</h2><div id="metrics"></div></div>
  <div class="grid g2 section">
    <div class="card"><h2>Findings</h2><div id="findings"></div></div>
    <div class="card"><h2>Configuration differences (CPF)</h2><div id="cpf"></div></div>
  </div>
</div>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, DATA = null;
	  function brief(host, r, tag) {
	    SP.clear(host);
	    host.appendChild(SP.el('div', { cls: 'card-h' }, [SP.el('h2', { text: tag + ': ' + r.sys }), SP.score(r.health)]));
	    var dl = SP.el('dl', { cls: 'kv' });
	    [['Run', r.runId], ['Start', r.start], ['Duration', r.dur != null ? Math.round(r.dur / 60) + ' min' : ''], ['Profile', r.profile], ['IRIS', r.version], ['CPUs', r.cpus], ['Memory MB', r.memMB], ['Global buffers MB', r.gbMB]].forEach(function (p) { if (p[1] === '' || p[1] == null) return; dl.appendChild(SP.el('dt', { text: p[0] })); dl.appendChild(SP.el('dd', { text: String(p[1]) })); });
	    host.appendChild(dl);
	    host.appendChild(SP.el('a', { cls: 'btn sm', href: 'SysPerf.UI.Run.cls?id=' + r.id, text: 'Open run' }));
	  }
	  function pct(a, b) { if (a == null || b == null || a === 0) return null; return (b - a) / Math.abs(a) * 100; }
	  function run() {
	    var a = $('#fA').value, b = $('#fB').value;
	    if (!a || !b || a === b) return;
	    history.replaceState(null, '', '?a=' + a + '&b=' + b);
	    SP.api('compare', { a: a, b: b }).then(function (j) {
	      DATA = j; $('#out').classList.remove('hide');
	      brief($('#briefA'), j.runA, 'A'); brief($('#briefB'), j.runB, 'B');
	      var rows = j.metrics.map(function (m) { var d = pct(m.aAvg, m.bAvg); return Object.assign({ dAvg: d, dP95: pct(m.aP95, m.bP95) }, m); });
	      SP.table($('#metrics'), { rows: rows, page: 60, csv: 'compare_' + a + '_' + b, rowCls: function (r) { if (r.dAvg == null || Math.abs(r.dAvg) < 20) return ''; var worse = r.better === 'L' ? r.dAvg > 0 : r.better === 'H' ? r.dAvg < 0 : false; return worse ? 'hl' : ''; },
	        columns: [{ k: 'cat', l: 'Category' }, { k: 'label', l: 'Metric' }, { k: 'unit', l: 'Unit' }, { k: 'aAvg', l: 'A avg', num: true }, { k: 'bAvg', l: 'B avg', num: true }, { k: 'dAvg', l: 'Δ avg %', num: true, fmt: function (v) { return v == null ? '–' : (v > 0 ? '+' : '') + SP.fmt(v, 1) + '%'; } }, { k: 'aP95', l: 'A p95', num: true }, { k: 'bP95', l: 'B p95', num: true }, { k: 'dP95', l: 'Δ p95 %', num: true, fmt: function (v) { return v == null ? '–' : (v > 0 ? '+' : '') + SP.fmt(v, 1) + '%'; } }, { k: 'aMax', l: 'A max', num: true }, { k: 'bMax', l: 'B max', num: true }] });
	      SP.table($('#findings'), { rows: j.findings, page: 50, csv: false, sort: { k: 'status', dir: 'asc' }, columns: [{ k: 'status', l: 'Status' }, { k: 'code', l: 'Rule' }, { k: 'a', l: 'A' }, { k: 'b', l: 'B' }, { k: 'titleB', l: 'Detail (B, else A)', fmt: function (v, r) { return v || r.titleA; } }] });
	      SP.table($('#cpf'), { rows: j.cpf, page: 50, csv: 'cpf_diff_' + a + '_' + b, empty: 'Identical configuration', columns: [{ k: 'section', l: 'Section' }, { k: 'name', l: 'Parameter' }, { k: 'a', l: 'A', cls: 'wrap' }, { k: 'b', l: 'B', cls: 'wrap' }] });
	      var ov = SP.clear($('#ovMetric'));
	      j.metrics.forEach(function (m) { ov.appendChild(SP.el('option', { value: m.metric, text: m.label + ' (' + m.unit + ')' })); });
	      ov.value = j.metrics.some(function (m) { return m.metric === 'Glorefs'; }) ? 'Glorefs' : (j.metrics[0] || {}).metric;
	      overlay();
	    }).catch(function (e) { SP.fail($('#metrics'), e); $('#out').classList.remove('hide'); });
	  }
	  function overlay() {
	    var code = $('#ovMetric').value, m = DATA.metrics.filter(function (x) { return x.metric === code; })[0];
	    if (!m) return;
	    var t = m.table, col = m.col;
	    function one(id, start) {
	      var p = { id: id, t: t, cols: col };
	      if (t === 'OSStat') p.src = '';
	      return SP.api('rseries', p).then(function (j) { var s = j.series[0] || { pts: [] }, t0 = SP.ts(start); return s.pts.map(function (x) { return [(SP.ts(x[0]) - t0) / 60000, x[1]]; }); });
	    }
	    Promise.all([one(DATA.runA.id, DATA.runA.start), one(DATA.runB.id, DATA.runB.start)]).then(function (r) {
	      SP.lineChart($('#ov'), { series: [{ name: 'A ' + DATA.runA.start.slice(0, 16), pts: r[0], color: 'var(--s1)' }, { name: 'B ' + DATA.runB.start.slice(0, 16), pts: r[1], color: 'var(--s2)' }], xType: 'num', xLabel: 'min', unit: m ? m.unit : '', height: 260 });
	    });
	  }
	  document.addEventListener('DOMContentLoaded', function () {
	    SP.api('runs', {}).then(function (j) {
	      j.runs.forEach(function (r) { var t = r.startTS + '  ' + r.sys + '  ' + (r.profile || ''); $('#fA').appendChild(SP.el('option', { value: r.id, text: t })); $('#fB').appendChild(SP.el('option', { value: r.id, text: t })); });
	      var a = SP.qs('a'), b = SP.qs('b');
	      if (a) $('#fA').value = a; else if (j.runs[1]) $('#fA').value = j.runs[1].id;
	      if (b) $('#fB').value = b; else if (j.runs[0]) $('#fB').value = j.runs[0].id;
	      if (j.runs.length < 2) $('#out').parentNode.insertBefore(SP.el('div', { cls: 'notice', text: 'Load at least two reports to compare.' }), $('#out'));
	      else run();
	    });
	    $('#go').addEventListener('click', run);
	    $('#ovMetric').addEventListener('change', overlay);
	  });
	})();
}

}
