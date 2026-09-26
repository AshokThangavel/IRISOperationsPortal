/// Read-only operations views of the local instance (processes, locks, databases, journals,
/// mirror, task manager, system logs, license). The view is chosen with ?v=
Class SysPerf.UI.Ops Extends SysPerf.UI.Base
{

Parameter NAVID = "ops-processes";

Parameter PAGETITLE = "Operations - IRIS Operations Portal";

ClassMethod View() As %String [ ServerOnly = 1 ]
{
	set v=$g(%request.Data("v",1),"processes")
	quit $s($lf($lb("processes","locks","databases","journals","mirror","tasks","logs","apperrors","license"),v):v,1:"processes")
}

ClassMethod Label(v As %String) As %String [ ServerOnly = 1 ]
{
	quit $case(v,"processes":"Processes","locks":"Locks","databases":"Databases","journals":"Journals","mirror":"Mirror Monitor","tasks":"Task Manager","logs":"System Logs","apperrors":"Application Error Log","license":"License Usage",:v)
}

ClassMethod NavId() As %String [ ServerOnly = 1 ]
{
	quit "ops-"_..View()
}

ClassMethod Title() As %String [ ServerOnly = 1 ]
{
	quit ..Label(..View())_" - IRIS Operations Portal"
}

ClassMethod Body() As %Status [ ServerOnly = 1 ]
{
	set v=..View()
	set tSub=$case(v,
		"processes":"Every process on the instance, sorted by global references. Select a PID for full details.",
		"locks":"Current entries in the lock table. Waiting requests are highlighted.",
		"databases":"Size, free space and journaling of every database.",
		"journals":"Journal state, directories and journal files (newest first).",
		"mirror":"Mirror membership and the status of every member.",
		"tasks":"Scheduled tasks and their recent history.",
		"logs":"Most recent entries of messages.log / alerts.log, newest first.",
		"apperrors":"Errors trapped by the application error log (^ERRORS) in every namespace - the same data as System Operation > System Logs > Application Error Log in the Management Portal. Select an error for its stack and variables.",
		"license":"License key, unit consumption and current users.",:"")
	&html<
<h1>#(..H(..Label(v)))#</h1><p class="sub">#(..H(tSub))#</p>
<div class="sp-filters" id="bar">
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
	  var $ = SP.$, V, host, tbl = null, timer = null, logOpt = { f: 'messages', min: 0 }, aeOpt = { days: 7, ns: '' };
	  function card(title, id, extra) { var c = SP.el('div', { cls: 'card section' }, [title ? SP.el('div', { cls: 'card-h' }, [SP.el('h2', { text: title }), extra || null]) : null, SP.el('div', { id: id })]); host.appendChild(c); return $('#' + id); }
	  function kv(target, pairs) {
	    var s = SP.el('div', { cls: 'stat' });
	    pairs.forEach(function (p) { if (p[1] === undefined) return; var v = p[1] == null || p[1] === '' ? '–' : String(p[1]); s.appendChild(SP.el('div', {}, [SP.el('div', { cls: 'l', text: p[0] }), SP.el('div', { cls: 'v' }, [p[2] ? SP.el('span', { cls: 'dot ' + p[2] }) : null, v])])); });
	    target.appendChild(s);
	  }
	  function mb(v) { return v == null || v === '' ? '' : SP.fmt(+v, 0); }
	  function yes(v) { return v === 1 || v === '1' || v === true ? 'Yes' : v === 0 || v === '0' || v === false ? 'No' : (v == null ? '' : String(v)); }
	  function done() { $('#lastUpd').textContent = 'Updated ' + SP.tstr(Date.now(), true); }

	  var views = {
	    processes: function () {
	      return SP.live('processes').then(function (j) {
	        var rows = j.rows;
	        if (!tbl) {
	          SP.clear(host);
	          var sum = card('', 'psum'); var t = card('', 'ptbl'); card('Process details', 'pdet').appendChild(SP.el('p', { cls: 'muted', text: 'Select a PID above.' }));
	          tbl = SP.table(t, {
	            rows: rows, csv: 'processes', page: 50, sort: { k: 'GlobalReferences', dir: 'desc' },
	            columns: [
	              { k: 'Pid', l: 'PID', render: function (v) { return SP.el('a', { href: '#pdet', text: String(v), onclick: function () { detail(v); } }); } },
	              { k: 'JobNumber', l: 'Job #', num: true, dec: 0 }, { k: 'UserName', l: 'User' }, { k: 'NameSpace', l: 'Namespace' }, { k: 'Routine', l: 'Routine' },
	              { k: 'State', l: 'State' }, { k: 'JobType', l: 'Type' }, { k: 'ClientNodeName', l: 'Client' }, { k: 'ClientIPAddress', l: 'Client IP' }, { k: 'ClientExecutableName', l: 'Client exe' },
	              { k: 'GlobalReferences', l: 'Global refs', num: true, dec: 0 }, { k: 'GlobalUpdates', l: 'Global upd.', num: true, dec: 0 }, { k: 'GlobalDiskReads', l: 'Disk reads', num: true, dec: 0 },
	              { k: 'LinesExecuted', l: 'Lines', num: true, dec: 0 }, { k: 'CommandsExecuted', l: 'Commands', num: true, dec: 0 }, { k: 'CPUTime', l: 'CPU ms', num: true, dec: 0 },
	              { k: 'MemoryUsed', l: 'Memory KB', num: true, dec: 0 }, { k: 'InTransaction', l: 'In TX', fmt: yes }, { k: 'CurrentDevice', l: 'Device' }, { k: 'LastGlobalReference', l: 'Last global ref', cls: 'wrap' }],
	            rowCls: function (r) { return /LOCK|WAIT|HANG/i.test(r.State || '') ? 'row-warn' : null; }
	          });
	        } else tbl.set(rows);
	        var st = {}; rows.forEach(function (r) { var k = r.State || '?'; st[k] = (st[k] || 0) + 1; });
	        var tx = rows.filter(function (r) { return +r.InTransaction; }).length, s = SP.clear($('#psum'));
	        kv(s, [['Processes', rows.length], ['In a transaction', tx, tx ? 'warn' : 'ok']].concat(Object.keys(st).sort().map(function (k) { return ['State ' + k, st[k], /LOCK|WAIT|HANG/i.test(k) ? 'warn' : '']; })));
	      });
	    },
	    locks: function () {
	      return SP.live('locks').then(function (j) {
	        SP.clear(host);
	        var waiting = j.rows.filter(function (r) { return /W/.test(r.Flags || '') || /wait/i.test(r.Mode || ''); });
	        kv(card('', 'lsum'), [['Lock entries', j.rows.length], ['Waiting requests', waiting.length, waiting.length ? 'warn' : 'ok'], ['Distinct owners', Object.keys(j.rows.reduce(function (a, r) { a[r.Owner] = 1; return a; }, {})).length]]);
	        SP.table(card('', 'ltbl'), { rows: j.rows, csv: 'locks', columns: [{ k: 'Owner', l: 'Owner (PID)' }, { k: 'Mode', l: 'Mode' }, { k: 'Flags', l: 'Flags' }, { k: 'Counts', l: 'Counts' }, { k: 'FullReference', l: 'Reference', cls: 'wrap' }, { k: 'Sfn', l: 'SFN', num: true, dec: 0 }], rowCls: function (r) { return waiting.indexOf(r) >= 0 ? 'row-warn' : null; }, empty: 'The lock table is empty.' });
	      });
	    },
	    databases: function () {
	      return SP.live('databases').then(function (j) {
	        SP.clear(host);
	        j.rows.forEach(function (r) {
	          r.pctFree = r.SizeInt ? 100 * (+r.AvailableNum || 0) / +r.SizeInt : null;
	          var max = parseFloat(String(r.MaxSize).replace(/[^\d.]/g, '')) || 0;
	          r.nearMax = max > 0 && +r.SizeInt / (max * (/GB/i.test(r.MaxSize) ? 1024 : /TB/i.test(r.MaxSize) ? 1048576 : 1)) > 0.9;
	        });
	        var bad = j.rows.filter(function (r) { return r.nearMax || /Full|Error|Dismount/i.test(r.Status || ''); }), noJ = j.rows.filter(function (r) { return r.Journal === 2 && !r.ReadOnly && !/IRISTEMP|HSSYSLOCALTEMP|IRISLOCALDATA|CACHETEMP/i.test(r.DatabaseName); });
	        var diskLow = j.rows.filter(function (r) { return r.DiskFreeSpaceNum != null && +r.DiskFreeSpaceNum < 10240; });
	        kv(card('', 'dsum'), [['Databases', j.rows.length], ['Total size MB', SP.fmt(j.rows.reduce(function (a, r) { return a + (+r.SizeInt || 0); }, 0), 0)], ['Near max size / errors', bad.length, bad.length ? 'bad' : 'ok'], ['Not journaled (excl. temp)', noJ.length, noJ.length ? 'warn' : 'ok'], ['Disk < 10 GB free', diskLow.length, diskLow.length ? 'warn' : 'ok']]);
	        var top = j.rows.slice().sort(function (a, b) { return (+b.SizeInt || 0) - (+a.SizeInt || 0); }).slice(0, 12);
	        SP.barChart(card('Largest databases (MB)', 'dbar'), { unit: 'MB', rows: top.map(function (r) { return { label: r.DatabaseName, value: +r.SizeInt || 0, sub: SP.fmt(r.pctFree, 1) + '% free inside the file' }; }) });
	        SP.table(card('', 'dtbl'), { rows: j.rows, csv: 'databases', sort: { k: 'DatabaseName', dir: 'asc' }, columns: [
	          { k: 'DatabaseName', l: 'Database' }, { k: 'Directory', l: 'Directory', cls: 'wrap' }, { k: 'SizeInt', l: 'Size MB', num: true, dec: 0 }, { k: 'MaxSize', l: 'Max size' }, { k: 'ExpansionSize', l: 'Expansion' },
	          { k: 'AvailableNum', l: 'Free MB', num: true, dec: 0 }, { k: 'pctFree', l: '% free', num: true, dec: 1 }, { k: 'DiskFreeSpace', l: 'Disk free' }, { k: 'Status', l: 'Status' },
	          { k: 'Journal', l: 'Journaled', fmt: function (v) { return v === 3 ? 'Yes' : v === 2 ? 'No' : v == null ? '' : String(v); } }, { k: 'Mounted', l: 'Mounted', fmt: yes }, { k: 'ReadOnly', l: 'Read only', fmt: yes }, { k: 'Mirrored', l: 'Mirrored', fmt: yes }, { k: 'Encrypted', l: 'Encrypted', fmt: yes }, { k: 'BlockSize', l: 'Block', num: true, dec: 0 }, { k: 'Resource', l: 'Resource' }],
	          rowCls: function (r) { return bad.indexOf(r) >= 0 ? 'row-bad' : noJ.indexOf(r) >= 0 ? 'row-warn' : null; } });
	      });
	    },
	    journals: function () {
	      return SP.live('journals').then(function (j) {
	        SP.clear(host);
	        kv(card('', 'jsum'), [['State', j.state, SP.status(j.state)], ['Current file', j.current], ['Primary directory', j.primary], ['Primary free MB', mb(j.primaryFreeMB), j.primaryFreeMB != null && j.primaryFreeMB < 10240 ? 'warn' : 'ok'], ['Alternate directory', j.alternate], ['Alternate free MB', mb(j.alternateFreeMB)], ['Frozen', yes(j.frozen), j.frozen ? 'bad' : 'ok'], ['Paused', yes(j.paused), j.paused ? 'warn' : 'ok'], ['I/O error', yes(j.ioError), j.ioError ? 'bad' : 'ok']]);
	        var files = j.files || [], cols = files.length ? Object.keys(files[0]).map(function (k) { return { k: k, l: k, num: typeof files[0][k] === 'number' }; }) : [{ k: 'Name', l: 'Name' }];
	        var sz = files.filter(function (f) { return f.Size != null; }).slice(0, 60).reverse();
	        if (sz.length > 1) SP.barChart(card('Journal file sizes (latest 60, MB)', 'jbar'), { unit: 'MB', rows: sz.slice(-15).map(function (f) { return { label: String(f.Name || f.Filename || '').split(/[\\/]/).pop(), value: Math.round((+f.Size || 0) / 1048576) }; }) });
	        SP.table(card('Journal files', 'jtbl'), { rows: files, csv: 'journal_files', columns: cols });
	      });
	    },
	    mirror: function () {
	      return SP.live('mirror').then(function (j) {
	        SP.clear(host);
	        if (!j.member) { card('', 'mnone').appendChild(SP.el('p', { cls: 'muted', text: 'This instance is not a member of a mirror.' })); return; }
	        kv(card('', 'msum'), [['Mirror', j.name], ['Member type', j.type], ['Status', j.status, SP.status(j.status)], ['Primary', yes(j.isPrimary)], ['Backup', yes(j.isBackup)], ['Async', yes(j.isAsync)], ['Member status', j.memberStatus]]);
	        var m = j.members || []; SP.table(card('Members', 'mtbl'), { rows: m, csv: 'mirror_members', columns: m.length ? Object.keys(m[0]).map(function (k) { return { k: k, l: k }; }) : [{ k: 'x', l: 'Member' }], rowCls: function (r) { var s = JSON.stringify(r); return /fail|down|disconnect|error/i.test(s) ? 'row-bad' : /catchup|wait|behind/i.test(s) ? 'row-warn' : null; } });
	      });
	    },
	    tasks: function () {
	      return SP.live('tasks').then(function (j) {
	        SP.clear(host);
	        function failed(t) { return t.Error && t.Error !== 'Success' && !/expired/i.test(t.Error) && String(t.DisplayStatus) !== '1'; }
	        function expired(t) { return /expired/i.test(t.Error || ''); }
	        var err = j.tasks.filter(failed), susp = j.tasks.filter(function (t) { return +t.Suspended; }), exp = j.tasks.filter(expired);
	        kv(card('', 'tsum'), [['Tasks', j.tasks.length], ['Suspended', susp.length, susp.length ? 'warn' : 'ok'], ['Last run failed', err.length, err.length ? 'bad' : 'ok'], ['Missed runs (expired)', exp.length, exp.length ? 'warn' : 'ok']]);
	        SP.table(card('Scheduled tasks', 'ttbl'), { rows: j.tasks, csv: 'tasks', columns: [{ k: 'ID', l: 'ID', num: true, fmt: String }, { k: 'Name', l: 'Name' }, { k: 'NameSpace', l: 'Namespace' }, { k: 'TaskClass', l: 'Class' }, { k: 'DisplayInterval', l: 'Schedule', cls: 'wrap' }, { k: 'DisplayStarted', l: 'Last started' }, { k: 'DisplayFinished', l: 'Last finished' }, { k: 'DisplayStatus', l: 'Last status' }, { k: 'DisplayNextScheduled', l: 'Next run' }, { k: 'Suspended', l: 'Suspended', fmt: function (v) { return +v === 1 ? 'Yes' : +v === 2 ? 'Yes (on error)' : 'No'; } }, { k: 'RunAsUser', l: 'Run as' }, { k: 'Error', l: 'Last result', cls: 'wrap' }], rowCls: function (r) { return failed(r) ? 'row-bad' : +r.Suspended || expired(r) ? 'row-warn' : null; } });
	        SP.table(card('Task history (latest 300)', 'thist'), { rows: j.history, csv: 'task_history', columns: [{ k: 'Name', l: 'Task' }, { k: 'NameSpace', l: 'Namespace' }, { k: 'DisplayStarted', l: 'Started' }, { k: 'DisplayFinished', l: 'Finished' }, { k: 'DisplayStatus', l: 'Status' }, { k: 'Username', l: 'User' }, { k: 'Error', l: 'Error', cls: 'wrap' }], rowCls: function (r) { return r.Error && r.Error !== 'Success' && String(r.Status) !== '1' ? 'row-bad' : null; } });
	      });
	    },
	    logs: function () {
	      return SP.live('log', { f: logOpt.f, lines: 2000, min: logOpt.min }).then(function (j) {
	        SP.clear(host);
	        var bar = SP.el('div', { cls: 'sp-filters' }), f1 = SP.el('div'), f2 = SP.el('div');
	        bar.appendChild(SP.el('label', {}, ['File', f1])); bar.appendChild(SP.el('label', {}, ['Minimum severity', f2]));
	        bar.appendChild(SP.el('span', { cls: 'muted small', text: j.file + (j.size != null ? ' · ' + SP.fmt(j.size / 1048576, 1) + ' MB' : '') }));
	        host.appendChild(bar);
	        SP.seg(f1, [{ v: 'messages', l: 'messages.log' }, { v: 'alerts', l: 'alerts.log' }], logOpt.f, function (v) { logOpt.f = v; refresh(); });
	        SP.seg(f2, [{ v: 0, l: 'All' }, { v: 1, l: 'Warning+' }, { v: 2, l: 'Severe+' }, { v: 3, l: 'Fatal' }], logOpt.min, function (v) { logOpt.min = v; refresh(); });
	        var n = [0, 0, 0, 0]; j.lines.forEach(function (l) { n[l.sev] = (n[l.sev] || 0) + 1; });
	        kv(card('', 'lgsum'), [['Lines shown', j.lines.length], ['Info (0)', n[0]], ['Warning (1)', n[1], n[1] ? 'warn' : 'ok'], ['Severe (2)', n[2], n[2] ? 'bad' : 'ok'], ['Fatal (3)', n[3], n[3] ? 'bad' : 'ok']]);
	        SP.table(card('', 'lgtbl'), { rows: j.lines, csv: logOpt.f + '_log', page: 100, columns: [{ k: 'ts', l: 'Time', cls: 'nowrap' }, { k: 'pid', l: 'PID' }, { k: 'sev', l: 'Sev', num: true, dec: 0 }, { k: 'src', l: 'Source' }, { k: 'text', l: 'Message', cls: 'wrap' }], rowCls: function (r) { return r.sev >= 2 ? 'row-bad' : r.sev === 1 ? 'row-warn' : null; }, empty: 'No log lines match.' });
	      });
	    },
	    apperrors: function () {
	      return SP.live('apperrors', { days: aeOpt.days, ns: aeOpt.ns }).then(function (j) {
	        SP.clear(host);
	        var bar = SP.el('div', { cls: 'sp-filters' }), f1 = SP.el('div'), sel = SP.el('select', { 'aria-label': 'Namespace' });
	        bar.appendChild(SP.el('label', {}, ['Period', f1])); bar.appendChild(SP.el('label', {}, ['Namespace', sel]));
	        host.appendChild(bar);
	        SP.seg(f1, [{ v: 1, l: 'Today' }, { v: 7, l: '7 days' }, { v: 30, l: '30 days' }, { v: 0, l: 'All' }], aeOpt.days, function (v) { aeOpt.days = v; refresh(); });
	        var nss = {}; j.dates.forEach(function (d) { nss[d.namespace] = (nss[d.namespace] || 0) + d.count; });
	        sel.appendChild(SP.el('option', { value: '', text: 'All namespaces' }));
	        Object.keys(nss).sort().forEach(function (n) { var o = SP.el('option', { value: n, text: n + ' (' + nss[n] + ')' }); if (n === aeOpt.ns) o.selected = true; sel.appendChild(o); });
	        if (aeOpt.ns && !nss[aeOpt.ns]) sel.appendChild(SP.el('option', { value: aeOpt.ns, text: aeOpt.ns, selected: 'selected' }));
	        sel.addEventListener('change', function () { aeOpt.ns = sel.value; refresh(); });
	        var rows = j.rows, total = j.dates.reduce(function (a, d) { return a + d.count; }, 0), today = SP.dstr(Date.now());
	        var byErr = {}; rows.forEach(function (r) { var k = String(r.error).replace(/\s*:.*$/, '').replace(/^(<[A-Z ]+>)[^^]*/, '$1'); byErr[k] = (byErr[k] || 0) + 1; });
	        var kinds = Object.keys(byErr).map(function (k) { return { label: k, value: byErr[k] }; }).sort(function (a, b) { return b.value - a.value; });
	        kv(card('', 'aesum'), [['Errors in period', total, total ? 'warn' : 'ok'], ['Today', j.dates.filter(function (d) { return d.date === today; }).reduce(function (a, d) { return a + d.count; }, 0)], ['Namespaces', Object.keys(nss).length], ['Distinct errors', kinds.length]]);
	        (j.notes || []).forEach(function (n) { host.appendChild(SP.el('div', { cls: 'notice', text: n })); });
	        if (j.capped) host.appendChild(SP.el('div', { cls: 'notice', text: 'Only the most recent errors are listed; narrow the period or namespace.' }));
	        if (j.dates.length > 1) {
	          var perDay = {}; j.dates.forEach(function (d) { perDay[d.date] = (perDay[d.date] || 0) + d.count; });
	          SP.lineChart(card('Errors per day', 'aechart'), { height: 180, dateOnly: true, series: [{ name: 'Errors', pts: Object.keys(perDay).sort().map(function (d) { return [SP.ts(d + ' 00:00:00'), perDay[d]]; }) }] });
	        }
	        if (kinds.length) SP.barChart(card('Most frequent errors', 'aebar'), { rows: kinds.slice(0, 10) });
	        SP.table(card('', 'aetbl'), { rows: rows, csv: 'application_errors', page: 50, columns: [
	          { k: 'date', l: 'Date', cls: 'nowrap' }, { k: 'time', l: 'Time' }, { k: 'namespace', l: 'Namespace' },
	          { k: 'num', l: '#', num: true, dec: 0, render: function (v, r) { return SP.el('a', { href: '#aedet', text: String(v), onclick: function () { aeDetail(r); } }); } },
	          { k: 'error', l: 'Error', cls: 'wrap' }, { k: 'line', l: 'Code line', cls: 'wrap mono' }, { k: 'user', l: 'User' }, { k: 'pid', l: 'PID' }],
	          rowCls: function (r) { return /<(PROTECT|STORE|FRAMESTACK|MAXSTRING|DISKHARD|DATABASE)/.test(r.error) ? 'row-bad' : null; }, empty: 'No application errors in this period.' });
	        card('Error details', 'aedet').appendChild(SP.el('p', { cls: 'muted', text: 'Select an error number above to see its stack, variables, objects and devices.' }));
	      });
	    },
	    license: function () {
	      return SP.live('license').then(function (j) {
	        SP.clear(host);
	        var pct = j.limit ? 100 * j.consumed / j.limit : 0;
	        kv(card('', 'lisum'), [['Customer', j.customer], ['Product', j.product], ['License type', j.type], ['Order', j.order], ['Expires', j.expires], ['Units authorised', j.units], ['Cores licensed', j.cores], ['User limit', j.limit], ['Units consumed', j.consumed, pct > 90 ? 'bad' : pct > 75 ? 'warn' : 'ok'], ['Units available', j.available], ['Max consumed', j.maxConsumed], ['Min available', j.minAvailable], ['Web users', j.cspUsers], ['Max web users', j.maxCspUsers]]);
	        if (j.error) host.appendChild(SP.el('p', { cls: 'err', text: j.error }));
	        var u = j.users || []; SP.table(card('Current license users', 'litbl'), { rows: u, csv: 'license_users', columns: u.length ? Object.keys(u[0]).map(function (k) { return { k: k, l: k }; }) : [{ k: 'x', l: 'User' }], empty: 'No license users.' });
	      });
	    }
	  };
	  function detail(pid) {
	    var d = SP.clear($('#pdet')); d.appendChild(SP.el('p', { cls: 'muted', text: 'Loading PID ' + pid + '…' }));
	    SP.live('process', { pid: pid }).then(function (j) {
	      SP.clear(d);
	      var r = j.rows[0]; if (!r) { d.appendChild(SP.el('p', { cls: 'muted', text: 'Process ' + pid + ' no longer exists.' })); return; }
	      var rows = Object.keys(r).sort().map(function (k) { return { k: k, v: r[k] }; }).filter(function (x) { return x.v !== '' && x.v != null; });
	      SP.table(d, { rows: rows, csv: 'process_' + pid, page: 200, columns: [{ k: 'k', l: 'Property' }, { k: 'v', l: 'Value', cls: 'wrap' }] });
	    }).catch(function (e) { SP.fail(d, e); });
	  }
	  function aeDetail(r) {
	    var d = SP.clear($('#aedet')); d.appendChild(SP.el('p', { cls: 'muted', text: 'Loading error ' + r.num + '…' }));
	    SP.live('apperror', { ns: r.namespace, date: r.dateKey, num: r.num }).then(function (j) {
	      SP.clear(d);
	      d.appendChild(SP.el('p', {}, [SP.el('b', { text: r.namespace + ' · ' + r.date + ' ' + r.time + ' · #' + r.num + ': ' }), String(r.error)]));
	      var secs = {}; j.rows.forEach(function (x) { (secs[x.section] = secs[x.section] || []).push(x); });
	      Object.keys(secs).forEach(function (s) {
	        var t = SP.el('div'); d.appendChild(SP.el('h3', { text: s + ' (' + secs[s].length + ')' })); d.appendChild(t);
	        SP.table(t, { rows: secs[s], csv: 'apperror_' + r.num + '_' + s, page: 100, columns: [{ k: 'name', l: 'Name', cls: 'mono' }, { k: 'value', l: 'Value', cls: 'wrap mono' }, { k: 'extra', l: '' }] });
	      });
	      if (!j.rows.length) d.appendChild(SP.el('p', { cls: 'muted', text: 'No detail recorded for this error.' }));
	    }).catch(function (e) { SP.fail(d, e); });
	  }
	  function refresh() { return (views[V] || views.processes)().then(done).catch(function (e) { SP.fail(host, e); }); }
	  document.addEventListener('DOMContentLoaded', function () {
	    host = $('#view'); V = host.getAttribute('data-v');
	    $('#btnRefresh').addEventListener('click', refresh);
	    $('#auto').addEventListener('change', function () { clearInterval(timer); if (this.checked) timer = setInterval(function () { if (!document.hidden) refresh(); }, 15000); });
	    refresh();
	  });
	})();
}

}
