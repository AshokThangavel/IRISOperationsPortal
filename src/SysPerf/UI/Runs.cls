/// All loaded runs with filters; select two to compare; admins can delete / re-analyse.
Class SysPerf.UI.Runs Extends SysPerf.UI.Base
{

Parameter NAVID = "runs";

Parameter PAGETITLE = "Runs - IRIS Operations Portal";

ClassMethod OnPost() [ ServerOnly = 1 ]
{
	set %response.Redirect="SysPerf.UI.Runs.cls"
	if '..IsAdmin() { do ..Flash("err","This action requires the SysPerfAdmin role.") quit }
	set tOp=..P("op"),tIds=..P("ids"),(tOK,tErr)=0
	for i=1:1:$l(tIds,",") {
		set tId=$p(tIds,",",i) continue:tId'?1.N
		if tOp="delete" { set tSC=##class(SysPerf.Data.Run).Purge(tId) }
		elseif tOp="reanalyze" { set tSC=##class(SysPerf.Loader).Reanalyze(tId) }
		else { continue }
		if $$$ISOK(tSC) { set tOK=tOK+1 } else { set tErr=tErr+1 }
	}
	if tOp="reanalyzeall" { set tSC=##class(SysPerf.Loader).Reanalyze() set tOK=$s($$$ISOK(tSC):"all",1:0) }
	do ..Flash($s(tErr:"err",1:"ok"),$case(tOp,"delete":"Deleted",:"Re-analysed")_" "_tOK_" run(s)"_$s(tErr:", "_tErr_" failed",1:"")_".")
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set tCsrf=..H(..CSRF())
	&html<
<h1>Runs</h1><p class="sub">Every loaded ^SystemPerformance report. Tick two runs to compare them.</p>
<div class="sp-filters">
  <label>System<select id="fSys"><option value="">All systems</option></select></label>
  <label>From<input type="date" id="fFrom"></label><label>To<input type="date" id="fTo"></label>
  <button class="btn" id="btnCompare" disabled>Compare selected</button>
  <span id="adminTools" class="flex"></span>
</div>
<div class="card"><div id="runs"></div></div>
<form id="f" method="post" class="hide"><input type="hidden" name="csrf" value="#(tCsrf)#"><input type="hidden" name="op" id="fOp"><input type="hidden" name="ids" id="fIds"></form>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, sel = {}, tbl = null, all = [];
	  function post(op) { $('#fOp').value = op; $('#fIds').value = Object.keys(sel).filter(function (k) { return sel[k]; }).join(','); $('#f').submit(); }
	  function upd() {
	    var ids = Object.keys(sel).filter(function (k) { return sel[k]; });
	    $('#btnCompare').disabled = ids.length !== 2;
	    SP.$$('#adminTools button[data-need]').forEach(function (b) { b.disabled = !ids.length; });
	  }
	  function load() {
	    SP.api('runs', { sys: $('#fSys').value, from: $('#fFrom').value, to: $('#fTo').value }).then(function (j) {
	      all = j.runs; sel = {}; upd();
	      tbl = SP.table($('#runs'), {
	        rows: all, page: 50, csv: 'runs', sort: { k: 'startTS', dir: 'desc' },
	        columns: [
	          { k: 'id', l: '', nosort: true, render: function (v) { var cb = SP.el('input', { type: 'checkbox', 'aria-label': 'Select run ' + v }); cb.checked = !!sel[v]; cb.addEventListener('change', function () { sel[v] = cb.checked; upd(); }); return cb; } },
	          { k: 'startTS', l: 'Start', link: function (r) { return 'SysPerf.UI.Run.cls?id=' + r.id; } },
	          { k: 'endTS', l: 'End' },
	          { k: 'sys', l: 'System' },
	          { k: 'profile', l: 'Profile' },
	          { k: 'intervalSec', l: 'Interval s', num: true },
	          { k: 'samples', l: 'Samples', num: true },
	          { k: 'health', l: 'Health', num: true, render: function (v) { return SP.score(v); } },
	          { k: 'crit', l: 'Critical', num: true }, { k: 'warn', l: 'Warning', num: true }, { k: 'info', l: 'Info', num: true },
	          { k: 'errors', l: 'Collector errors', cls: 'wrap' },
	          { k: 'fileName', l: 'File' }, { k: 'loadedTS', l: 'Loaded' }
	        ]
	      });
	    }).catch(function (e) { SP.fail($('#runs'), e); });
	  }
	  document.addEventListener('DOMContentLoaded', function () {
	    SP.api('systems').then(function (j) { j.systems.forEach(function (s) { $('#fSys').appendChild(SP.el('option', { value: s.sys, text: s.sys })); }); var q = SP.qs('sys'); if (q) $('#fSys').value = q; load(); });
	    ['#fSys', '#fFrom', '#fTo'].forEach(function (s) { $(s).addEventListener('change', load); });
	    $('#btnCompare').addEventListener('click', function () {
	      var ids = Object.keys(sel).filter(function (k) { return sel[k]; });
	      var a = all.filter(function (r) { return String(r.id) === ids[0]; })[0], b = all.filter(function (r) { return String(r.id) === ids[1]; })[0];
	      if (a && b && a.startTS > b.startTS) { var t = a; a = b; b = t; }
	      location.href = 'SysPerf.UI.Compare.cls?a=' + a.id + '&b=' + b.id;
	    });
	    if (window.SP_CFG.admin) {
	      var t = $('#adminTools');
	      t.appendChild(SP.el('button', { cls: 'btn', 'data-need': '1', text: 'Re-analyse selected', disabled: 'disabled', onclick: function () { post('reanalyze'); } }));
	      t.appendChild(SP.el('button', { cls: 'btn', text: 'Re-analyse all', onclick: function () { if (confirm('Re-run the analyzer for every run with the current thresholds?')) post('reanalyzeall'); } }));
	      t.appendChild(SP.el('button', { cls: 'btn danger', 'data-need': '1', text: 'Delete selected', disabled: 'disabled', onclick: function () { if (confirm('Delete the selected runs and all their data?')) post('delete'); } }));
	    }
	  });
	})();
}

}
