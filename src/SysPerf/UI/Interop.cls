/// Interoperability monitor across every interoperability-enabled namespace:
/// productions and their items, queues, and the event log. Read-only.
Class SysPerf.UI.Interop Extends SysPerf.UI.Base
{

Parameter NAVID = "int-productions";

Parameter PAGETITLE = "Interoperability - IRIS Operations Portal";

ClassMethod View() As %String [ ServerOnly = 1 ]
{
	set v=$g(%request.Data("v",1),"productions")
	quit $s($lf($lb("productions","queues","events"),v):v,1:"productions")
}

ClassMethod Label(v As %String) As %String [ ServerOnly = 1 ]
{
	quit $case(v,"productions":"Productions","queues":"Queues","events":"Event Log",:v)
}

ClassMethod NavId() As %String [ ServerOnly = 1 ]
{
	quit "int-"_..View()
}

ClassMethod Title() As %String [ ServerOnly = 1 ]
{
	quit ..Label(..View())_" - IRIS Operations Portal"
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set v=..View()
	set tSub=$case(v,"productions":"Production state, message volume and errors in every interoperability namespace. Select a namespace to see its items.",
		"queues":"Messages waiting in every queue. Growing queues mean a component cannot keep up or is blocked.",
		"events":"Errors, warnings and alerts from Ens_Util.Log (times are shown in UTC, as stored).",:"")
	&html<
<h1>#(..H(..Label(v)))#</h1><p class="sub">#(..H(tSub))#</p>
<div class="sp-filters">
  <button class="btn" id="btnRefresh" type="button">Refresh</button>
  <label class="flex"><input type="checkbox" id="auto"> Auto-refresh every 15 s</label>
  <span class="muted small" id="lastUpd"></span>
</div>
<div id="view" data-v="#(v)#"></div>
>
	do ..WriteScript()
	quit $$$OK
}

XData Script [ MimeType = application/javascript ]
{
	(function () {
	  var $ = SP.$, V, host, timer = null, sel = SP.qs('ns'), ev = { types: '2,3,6', hours: 24, ns: SP.qs('ns') };
	  function card(title, id) { var c = SP.el('div', { cls: 'card section' }, [title ? SP.el('h2', { text: title }) : null, SP.el('div', { id: id })]); host.appendChild(c); return $('#' + id); }
	  function stateCls(s) { return s === 1 ? 'ok' : s === 3 || s === 4 ? 'bad' : 'warn'; }
	  function qcount(r) { return +(r.Count != null ? r.Count : r.count != null ? r.count : r.QueueCount) || 0; }
	  function kv(target, pairs) {
	    var s = SP.el('div', { cls: 'stat' });
	    pairs.forEach(function (p) { s.appendChild(SP.el('div', {}, [SP.el('div', { cls: 'l', text: p[0] }), SP.el('div', { cls: 'v' }, [p[2] ? SP.el('span', { cls: 'dot ' + p[2] }) : null, p[1] == null || p[1] === '' ? '–' : String(p[1])])])); });
	    target.appendChild(s);
	  }
	  var views = {
	    productions: function () {
	      return SP.live('interop').then(function (j) {
	        SP.clear(host);
	        if (!j.namespaces.length) { card('', 'none').appendChild(SP.el('p', { cls: 'muted', text: 'No interoperability-enabled namespaces on this instance.' })); return; }
	        var t = card('', 'ptbl');
	        SP.table(t, { rows: j.namespaces, search: false, csv: 'productions', columns: [
	          { k: 'namespace', l: 'Namespace', render: function (v) { return SP.el('a', { href: '?v=productions&ns=' + encodeURIComponent(v), text: v }); } },
	          { k: 'production', l: 'Production' },
	          { k: 'stateText', l: 'State', render: function (v, r) { return r.production ? SP.el('span', {}, [SP.el('span', { cls: 'dot ' + stateCls(r.state) }), v]) : SP.el('span', { cls: 'muted', text: 'none' }); } },
	          { k: 'queued', l: 'Queued', num: true, dec: 0 }, { k: 'messagesLastHour', l: 'Messages last hour', num: true, dec: 0, fmt: function (v, r) { return SP.fmt(v, 0) + (r.messagesCapped ? '+' : ''); } }, { k: 'errorMessagesLastHour', l: 'Errored messages last hour', num: true, dec: 0 },
	          { k: 'errors24h', l: 'Errors 24h', num: true, dec: 0 }, { k: 'warnings24h', l: 'Warnings 24h', num: true, dec: 0 }, { k: 'alerts24h', l: 'Alerts 24h', num: true, dec: 0 }, { k: 'error', l: 'Note', cls: 'wrap' }],
	          rowCls: function (r) { return r.production && (r.state === 3 || r.state === 4) ? 'row-bad' : r.errors24h > 0 || r.queued > 100 ? 'row-warn' : null; } });
	        var sNs = sel || (j.namespaces.filter(function (n) { return n.production; })[0] || {}).namespace;
	        if (sNs) return items(sNs);
	      });
	    },
	    queues: function () {
	      return SP.live('queues').then(function (j) {
	        SP.clear(host);
	        var rows = j.rows; rows.forEach(function (r) { r._n = qcount(r); });
	        var total = rows.reduce(function (a, r) { return a + r._n; }, 0), busy = rows.filter(function (r) { return r._n > 0; });
	        kv(card('', 'qsum'), [['Queues', rows.length], ['Messages queued', SP.fmt(total, 0), total > 1000 ? 'bad' : total > 100 ? 'warn' : 'ok'], ['Non-empty queues', busy.length]]);
	        var top = rows.slice().sort(function (a, b) { return b._n - a._n; }).filter(function (r) { return r._n > 0; }).slice(0, 15);
	        if (top.length) SP.barChart(card('Deepest queues', 'qbar'), { rows: top.map(function (r) { return { label: r.Namespace + ' · ' + r.Name, value: r._n, color: r._n > 1000 ? 'var(--critical)' : r._n > 100 ? 'var(--warning)' : 'var(--s1)' }; }) });
	        var cols = [{ k: 'Namespace', l: 'Namespace' }, { k: 'Name', l: 'Queue' }, { k: '_n', l: 'Count', num: true, dec: 0 }];
	        if (rows[0]) Object.keys(rows[0]).forEach(function (k) { if (['Namespace', 'Name', '_n', 'Count', 'count'].indexOf(k) < 0) cols.push({ k: k, l: k }); });
	        SP.table(card('', 'qtbl'), { rows: rows, csv: 'queues', sort: { k: '_n', dir: 'desc' }, columns: cols, rowCls: function (r) { return r._n > 1000 ? 'row-bad' : r._n > 100 ? 'row-warn' : null; }, empty: 'No queues.' });
	      });
	    },
	    events: function () {
	      return SP.live('events', { types: ev.types, hours: ev.hours, ns: ev.ns, max: 2000 }).then(function (j) {
	        SP.clear(host);
	        var bar = SP.el('div', { cls: 'sp-filters' }), f1 = SP.el('div'), f2 = SP.el('div');
	        bar.appendChild(SP.el('label', {}, ['Types', f1])); bar.appendChild(SP.el('label', {}, ['Period', f2]));
	        if (ev.ns) bar.appendChild(SP.el('a', { cls: 'btn sm', href: '?v=events', text: 'Namespace ' + ev.ns + ' ✕' }));
	        host.appendChild(bar);
	        SP.seg(f1, [{ v: '2,3,6', l: 'Errors, warnings, alerts' }, { v: '2', l: 'Errors' }, { v: '3', l: 'Warnings' }, { v: '6', l: 'Alerts' }, { v: '2,3,4,6', l: 'Incl. info' }], ev.types, function (v) { ev.types = v; refresh(); });
	        SP.seg(f2, [{ v: 1, l: '1 h' }, { v: 24, l: '24 h' }, { v: 168, l: '7 days' }], ev.hours, function (v) { ev.hours = v; refresh(); });
	        var rows = j.rows, by = {};
	        rows.forEach(function (r) { var k = (r.Namespace || '') + ' · ' + (r.ConfigName || '(none)'); by[k] = (by[k] || 0) + 1; });
	        var top = Object.keys(by).map(function (k) { return { label: k, value: by[k] }; }).sort(function (a, b) { return b.value - a.value; }).slice(0, 10);
	        if (top.length) SP.barChart(card('Events by component', 'ebar'), { rows: top });
	        SP.table(card('', 'etbl'), { rows: rows, csv: 'event_log', page: 100, columns: [{ k: 'TimeLogged', l: 'Time (UTC)', cls: 'nowrap' }, { k: 'Namespace', l: 'Namespace' }, { k: 'TypeText', l: 'Type' }, { k: 'ConfigName', l: 'Component' }, { k: 'SourceClass', l: 'Class' }, { k: 'SourceMethod', l: 'Method' }, { k: 'SessionId', l: 'Session', num: true, dec: 0 }, { k: 'Text', l: 'Text', cls: 'wrap' }], rowCls: function (r) { return r.Type === 2 || r.Type === 6 ? 'row-bad' : r.Type === 3 ? 'row-warn' : null; }, empty: 'No events in this period.' });
	      });
	    }
	  };
	  function items(ns) {
	    var d = card('Items in ' + ns, 'items'); d.appendChild(SP.el('p', { cls: 'muted', text: 'Loading…' }));
	    return SP.live('items', { ns: ns }).then(function (j) {
	      SP.clear(d);
	      if (j.error) { d.appendChild(SP.el('p', { cls: 'err', text: j.error })); return; }
	      var q = {}, e = {}; (j.queues || []).forEach(function (r) { q[r.Name] = qcount(r); });
	      (j.errors || []).forEach(function (r) { var x = e[r.ConfigName] = e[r.ConfigName] || { err: 0, warn: 0, last: '' }; if (r.Type === 2) x.err = r.N; else x.warn = r.N; if (r.LastTime > x.last) x.last = r.LastTime; });
	      var p = j.production;
	      kv(d, [['Production', p.production], ['State', p.stateText, stateCls(p.state)], ['Items', j.items.length], ['Disabled items', j.items.filter(function (i) { return !+i.Enabled; }).length]]);
	      var rows = j.items.map(function (i) { var x = e[i.Name] || {}; return { Name: i.Name, ClassName: i.ClassName, Category: i.Category, Enabled: +i.Enabled ? 'Yes' : 'No', PoolSize: i.PoolSize, queued: q[i.Name] || 0, err: x.err || 0, warn: x.warn || 0, last: x.last || '', Comment: i.Comment }; });
	      var t = SP.el('div'); d.appendChild(t);
	      SP.table(t, { rows: rows, csv: 'items_' + ns, sort: { k: 'err', dir: 'desc' }, columns: [{ k: 'Name', l: 'Item', render: function (v) { return SP.el('a', { href: '?v=events&ns=' + encodeURIComponent(ns), text: v, title: 'Event log of this namespace' }); } }, { k: 'ClassName', l: 'Class' }, { k: 'Category', l: 'Category' }, { k: 'Enabled', l: 'Enabled' }, { k: 'PoolSize', l: 'Pool', num: true, dec: 0 }, { k: 'queued', l: 'Queued', num: true, dec: 0 }, { k: 'err', l: 'Errors 24h', num: true, dec: 0 }, { k: 'warn', l: 'Warnings 24h', num: true, dec: 0 }, { k: 'last', l: 'Last error/warning (UTC)' }, { k: 'Comment', l: 'Comment', cls: 'wrap' }], rowCls: function (r) { return r.err > 0 || r.queued > 100 ? 'row-bad' : r.warn > 0 || r.queued > 0 ? 'row-warn' : r.Enabled === 'No' ? 'muted' : null; } });
	    }).catch(function (e) { SP.fail(d, e); });
	  }
	  function refresh() { return (views[V] || views.productions)().then(function () { $('#lastUpd').textContent = 'Updated ' + SP.tstr(Date.now(), true); }).catch(function (e) { SP.fail(host, e); }); }
	  document.addEventListener('DOMContentLoaded', function () {
	    host = $('#view'); V = host.getAttribute('data-v');
	    $('#btnRefresh').addEventListener('click', refresh);
	    $('#auto').addEventListener('change', function () { clearInterval(timer); if (this.checked) timer = setInterval(function () { if (!document.hidden) refresh(); }, 15000); });
	    refresh();
	  });
	})();
}

}
