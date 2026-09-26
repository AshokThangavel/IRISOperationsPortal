/// Static assets (CSS / JavaScript) for the SysPerf UI, served from class XData so the
/// application deploys as classes only. URL: SysPerf.UI.Assets.cls?f=app.css | app.js
/// Source files: web/app.css, web/app.js (embedded by build_assets.py).
Class SysPerf.UI.Assets Extends %CSP.Page
{

Parameter SECURITYRESOURCE = "SysPerf_Viewer";

ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	set tF=$g(%request.Data("f",1))
	set %response.ContentType=$case(tF,"app.css":"text/css","app.js":"application/javascript",:"text/plain")
	set %response.CharSet="utf-8"
	do %response.SetHeader("X-Content-Type-Options","nosniff")
	do %response.SetHeader("Cache-Control","private, max-age=3600")
	// version in the URL busts the cache after an upgrade
	quit 1
}

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
	set tF=$g(%request.Data("f",1))
	set tX=$case(tF,"app.css":"CSS","app.js":"JS",:"")
	quit:tX="" $$$OK
	set tXD=##class(%Dictionary.CompiledXData).%OpenId($classname()_"||"_tX,0)
	quit:'$isobject(tXD) $$$OK
	while 'tXD.Data.AtEnd {
		set tL=tXD.Data.ReadLine()
		if $e(tL)=$c(9) set tL=$e(tL,2,*)
		write tL,!
	}
	quit $$$OK
}

XData CSS [ MimeType = text/css ]
{
	:root {
	  color-scheme: light;
	  --page: #f9f9f7;
	  --surface: #fcfcfb;
	  --surface-2: #f3f2ee;
	  --ink: #0b0b0b;
	  --ink-2: #52514e;
	  --muted: #898781;
	  --grid: #e1e0d9;
	  --axis: #c3c2b7;
	  --border: rgba(11,11,11,0.10);
	  --accent: #2a78d6;
	  --accent-ink: #ffffff;
	  --s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a; --s4: #eda100;
	  --s5: #e87ba4; --s6: #008300; --s7: #4a3aa7; --s8: #e34948;
	  --good: #0ca30c; --warning: #fab219; --serious: #ec835a; --critical: #d03b3b;
	  --good-ink: #006300; --crit-ink: #b42b2b; --warn-ink: #8a5a00;
	  --seq-0: #f0efec; --seq-1: #cde2fb; --seq-2: #9ec5f4; --seq-3: #6da7ec; --seq-4: #3987e5; --seq-5: #256abf; --seq-6: #184f95; --seq-7: #0d366b;
	  --shadow: 0 1px 2px rgba(0,0,0,.05);
	}
	@media (prefers-color-scheme: dark) {
	  :root:where(:not([data-theme="light"])) {
	    color-scheme: dark;
	    --page: #0d0d0d; --surface: #1a1a19; --surface-2: #232321;
	    --ink: #ffffff; --ink-2: #c3c2b7; --muted: #898781; --grid: #2c2c2a; --axis: #383835;
	    --border: rgba(255,255,255,0.10); --accent: #3987e5;
	    --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500;
	    --s5: #d55181; --s6: #008300; --s7: #9085e9; --s8: #e66767;
	    --good-ink: #0ca30c; --crit-ink: #e66767; --warn-ink: #fab219;
	    --seq-0: #383835; --seq-1: #0d366b; --seq-2: #104281; --seq-3: #184f95; --seq-4: #1c5cab; --seq-5: #2a78d6; --seq-6: #5598e7; --seq-7: #9ec5f4;
	  }
	}
	:root[data-theme="dark"] {
	  color-scheme: dark;
	  --page: #0d0d0d; --surface: #1a1a19; --surface-2: #232321;
	  --ink: #ffffff; --ink-2: #c3c2b7; --muted: #898781; --grid: #2c2c2a; --axis: #383835;
	  --border: rgba(255,255,255,0.10); --accent: #3987e5;
	  --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500;
	  --s5: #d55181; --s6: #008300; --s7: #9085e9; --s8: #e66767;
	  --good-ink: #0ca30c; --crit-ink: #e66767; --warn-ink: #fab219;
	  --seq-0: #383835; --seq-1: #0d366b; --seq-2: #104281; --seq-3: #184f95; --seq-4: #1c5cab; --seq-5: #2a78d6; --seq-6: #5598e7; --seq-7: #9ec5f4;
	}
	* { box-sizing: border-box; }
	html, body { margin: 0; padding: 0; }
	body { background: var(--page); color: var(--ink); font: 14px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
	a { color: var(--accent); text-decoration: none; }
	a:hover { text-decoration: underline; }
	code, pre, .mono { font-family: ui-monospace, SFMono-Regular, Consolas, "Liberation Mono", monospace; font-size: 12.5px; }
	.num { font-variant-numeric: tabular-nums; text-align: right; }

	/* ---------- header / nav ---------- */
	.sp-top { position: sticky; top: 0; z-index: 20; background: var(--surface); border-bottom: 1px solid var(--border); }
	.sp-top-in { max-width: 1480px; margin: 0 auto; padding: 0 16px; display: flex; align-items: center; gap: 18px; height: 52px; }
	.sp-brand { font-weight: 650; font-size: 15px; color: var(--ink); white-space: nowrap; display: flex; align-items: center; gap: 8px; }
	.sp-brand svg { width: 22px; height: 22px; }
	.sp-nav { display: flex; gap: 2px; overflow-x: auto; }
	.sp-nav a { color: var(--ink-2); padding: 6px 10px; border-radius: 6px; white-space: nowrap; }
	.sp-nav a.on { color: var(--ink); background: var(--surface-2); font-weight: 600; }
	.sp-nav a:hover { text-decoration: none; background: var(--surface-2); }
	.sp-spacer { flex: 1; }
	.sp-user { color: var(--muted); font-size: 12.5px; white-space: nowrap; }
	.sp-icon-btn { background: none; border: 1px solid var(--border); color: var(--ink-2); border-radius: 6px; padding: 4px 8px; cursor: pointer; font: inherit; }
	.sp-main { max-width: 1480px; margin: 0 auto; padding: 18px 16px 60px; }
	h1 { font-size: 20px; margin: 0 0 4px; font-weight: 650; }
	h2 { font-size: 15px; margin: 0 0 10px; font-weight: 650; }
	h3 { font-size: 13.5px; margin: 0 0 8px; font-weight: 650; color: var(--ink-2); }
	.sub { color: var(--ink-2); margin: 0 0 16px; }
	.muted { color: var(--muted); }
	.small { font-size: 12.5px; }

	/* ---------- filter row ---------- */
	.sp-filters { display: flex; flex-wrap: wrap; gap: 10px; align-items: flex-end; margin: 4px 0 18px; }
	.sp-filters label { display: flex; flex-direction: column; gap: 3px; font-size: 12px; color: var(--ink-2); }
	select, input[type=text], input[type=date], input[type=number], input[type=search], textarea {
	  font: inherit; color: var(--ink); background: var(--surface); border: 1px solid var(--axis); border-radius: 6px; padding: 5px 8px; min-height: 32px; }
	textarea { width: 100%; min-height: 70px; }
	.seg { display: inline-flex; border: 1px solid var(--axis); border-radius: 7px; overflow: hidden; background: var(--surface); }
	.seg button { border: 0; background: none; padding: 6px 11px; font: inherit; color: var(--ink-2); cursor: pointer; border-right: 1px solid var(--border); min-height: 32px; }
	.seg button:last-child { border-right: 0; }
	.seg button.on { background: var(--accent); color: var(--accent-ink); font-weight: 600; }
	.btn { font: inherit; border: 1px solid var(--axis); background: var(--surface); color: var(--ink); padding: 6px 12px; border-radius: 6px; cursor: pointer; min-height: 32px; display: inline-flex; align-items: center; gap: 6px; }
	.btn:hover { background: var(--surface-2); text-decoration: none; }
	.btn.primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); font-weight: 600; }
	.btn.danger { color: var(--crit-ink); border-color: var(--crit-ink); }
	.btn.sm { padding: 3px 8px; min-height: 26px; font-size: 12.5px; }
	.btn[disabled] { opacity: .5; cursor: default; }

	/* ---------- cards / grid ---------- */
	.grid { display: grid; gap: 14px; }
	.g2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
	.g3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
	.g4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }
	@media (max-width: 1100px) { .g3, .g4 { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
	@media (max-width: 720px) { .g2, .g3, .g4 { grid-template-columns: minmax(0, 1fr); } }
	.card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; box-shadow: var(--shadow); min-width: 0; }
	.card + .card { margin-top: 0; }
	.section { margin-top: 18px; }
	.card-h { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; margin-bottom: 8px; }
	.card-h h2 { margin: 0; }
	.card-tools { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }

	/* ---------- KPI tiles ---------- */
	.kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 12px; }
	.kpi { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 12px 14px; min-width: 0; }
	.kpi .k-l { font-size: 12px; color: var(--ink-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.kpi .k-v { font-size: 24px; font-weight: 650; margin-top: 2px; }
	.kpi .k-v small { font-size: 13px; color: var(--ink-2); font-weight: 500; margin-left: 2px; }
	.kpi .k-d { font-size: 12px; color: var(--muted); margin-top: 2px; }
	.kpi .k-d .up-bad, .kpi .k-d .down-bad { color: var(--crit-ink); }
	.kpi .k-d .up-good, .kpi .k-d .down-good { color: var(--good-ink); }
	.kpi.st-C { border-left: 3px solid var(--critical); }
	.kpi.st-W { border-left: 3px solid var(--warning); }
	.kpi.st-OK { border-left: 3px solid var(--good); }

	/* ---------- status badges ---------- */
	.badge { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; font-weight: 600; padding: 1px 8px 1px 6px; border-radius: 999px; border: 1px solid var(--border); background: var(--surface-2); color: var(--ink); white-space: nowrap; }
	.badge i { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
	.badge.C i { background: var(--critical); } .badge.W i { background: var(--warning); } .badge.I i { background: var(--s1); } .badge.OK i { background: var(--good); }
	.score { display: inline-flex; align-items: center; justify-content: center; min-width: 38px; height: 24px; border-radius: 6px; font-weight: 700; font-size: 13px; padding: 0 6px; border: 1px solid var(--border); }
	.score.good { color: var(--good-ink); } .score.warn { color: var(--warn-ink); } .score.bad { color: var(--crit-ink); }

	/* ---------- findings ---------- */
	.finding { border: 1px solid var(--border); border-radius: 9px; background: var(--surface); margin-bottom: 10px; }
	.finding > summary { list-style: none; cursor: pointer; padding: 10px 14px; display: flex; gap: 10px; align-items: center; }
	.finding > summary::-webkit-details-marker { display: none; }
	.finding > summary .f-t { flex: 1; font-weight: 600; min-width: 0; }
	.finding > summary .f-c { color: var(--muted); font-size: 12px; white-space: nowrap; }
	.finding.C { border-left: 4px solid var(--critical); } .finding.W { border-left: 4px solid var(--warning); } .finding.I { border-left: 4px solid var(--s1); } .finding.OK { border-left: 4px solid var(--good); }
	.finding .f-b { padding: 0 14px 12px 14px; }
	.finding .f-b p { margin: 6px 0; }
	.finding .f-lab { font-size: 12px; font-weight: 650; color: var(--ink-2); margin-top: 10px; text-transform: uppercase; letter-spacing: .03em; }
	.finding pre { white-space: pre-wrap; background: var(--surface-2); padding: 8px 10px; border-radius: 6px; margin: 4px 0; max-height: 260px; overflow: auto; }
	.rec { white-space: pre-wrap; }
	.ack { color: var(--good-ink); font-size: 12px; }

	/* ---------- tabs ---------- */
	.tabs { display: flex; gap: 2px; border-bottom: 1px solid var(--border); margin: 16px 0 14px; overflow-x: auto; }
	.tabs button { background: none; border: 0; border-bottom: 2px solid transparent; padding: 8px 12px; font: inherit; color: var(--ink-2); cursor: pointer; white-space: nowrap; }
	.tabs button.on { color: var(--ink); border-bottom-color: var(--accent); font-weight: 600; }
	.tabs button .cnt { font-size: 11px; color: var(--muted); margin-left: 4px; }
	.tabpane { display: none; }
	.tabpane.on { display: block; }

	/* ---------- tables ---------- */
	.tbl-wrap { overflow: auto; max-width: 100%; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); }
	table.t { border-collapse: collapse; width: 100%; font-size: 13px; }
	table.t th, table.t td { padding: 6px 10px; border-bottom: 1px solid var(--grid); text-align: left; vertical-align: top; }
	table.t th { position: sticky; top: 0; background: var(--surface-2); font-weight: 600; color: var(--ink-2); white-space: nowrap; cursor: pointer; user-select: none; z-index: 1; }
	table.t th.nosort { cursor: default; }
	table.t th .arr { color: var(--muted); font-size: 10px; margin-left: 3px; }
	table.t tbody tr:hover { background: var(--surface-2); }
	table.t td.num, table.t th.num { text-align: right; font-variant-numeric: tabular-nums; }
	table.t td.wrap { white-space: pre-wrap; word-break: break-word; min-width: 220px; }
	table.t td.nowrap { white-space: nowrap; }
	table.t tr.hl td { background: color-mix(in srgb, var(--warning) 14%, transparent); }
	.tbl-bar { display: flex; gap: 8px; align-items: center; margin: 0 0 8px; flex-wrap: wrap; }
	.tbl-bar .grow { flex: 1; }
	.tbl-foot { display: flex; gap: 8px; align-items: center; justify-content: flex-end; padding: 6px 2px; font-size: 12px; color: var(--muted); }
	.kv { display: grid; grid-template-columns: minmax(140px, max-content) 1fr; gap: 4px 16px; font-size: 13px; }
	.kv dt { color: var(--ink-2); }
	.kv dd { margin: 0; word-break: break-word; }

	/* ---------- charts ---------- */
	.chart { position: relative; width: 100%; min-height: 60px; }
	.chart svg { display: block; width: 100%; overflow: visible; }
	.chart .ax text { fill: var(--muted); font-size: 11px; font-variant-numeric: tabular-nums; }
	.chart .ax line, .chart .ax path { stroke: var(--axis); }
	.chart .gl line { stroke: var(--grid); }
	.chart .xh { stroke: var(--ink-2); stroke-width: 1; stroke-dasharray: 3 3; }
	.chart.loading { opacity: .45; transition: opacity .15s; }
	.chart .empty { color: var(--muted); font-size: 13px; padding: 26px 0; text-align: center; }
	.legend { display: flex; flex-wrap: wrap; gap: 4px 14px; font-size: 12px; color: var(--ink-2); margin: 2px 0 6px; }
	.legend span { display: inline-flex; align-items: center; gap: 6px; cursor: pointer; }
	.legend span.off { opacity: .4; }
	.legend i { width: 14px; height: 2px; display: inline-block; border-radius: 2px; }
	.legend i.box { height: 10px; width: 10px; border-radius: 2px; }
	.tip { position: fixed; z-index: 100; pointer-events: none; background: var(--surface); color: var(--ink); border: 1px solid var(--border); border-radius: 8px; padding: 8px 10px; font-size: 12px; box-shadow: 0 4px 16px rgba(0,0,0,.15); min-width: 140px; max-width: 360px; display: none; }
	.tip .tt { color: var(--ink-2); margin-bottom: 4px; font-weight: 600; }
	.tip .tr { display: flex; align-items: center; gap: 8px; white-space: nowrap; }
	.tip .tr i { width: 12px; height: 2px; display: inline-block; }
	.tip .tr b { font-variant-numeric: tabular-nums; }
	.tip .tr span { color: var(--ink-2); overflow: hidden; text-overflow: ellipsis; }
	.hm-legend { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--muted); margin-top: 6px; }
	.hm-legend .ramp { display: flex; height: 8px; width: 160px; border-radius: 4px; overflow: hidden; }
	.hm-legend .ramp i { flex: 1; }

	/* ---------- misc ---------- */
	.notice { border: 1px solid var(--border); border-left: 4px solid var(--s1); background: var(--surface); padding: 10px 14px; border-radius: 8px; margin: 10px 0; }
	.notice.err { border-left-color: var(--critical); }
	.notice.ok { border-left-color: var(--good); }
	.notice.warn { border-left-color: var(--warning); }
	.meta { display: flex; flex-wrap: wrap; gap: 6px 18px; color: var(--ink-2); font-size: 13px; margin: 6px 0 4px; }
	.meta b { color: var(--ink); font-weight: 600; }
	.pill { display: inline-block; padding: 1px 8px; border-radius: 999px; background: var(--surface-2); border: 1px solid var(--border); font-size: 12px; color: var(--ink-2); }
	.raw { white-space: pre; overflow: auto; max-height: 70vh; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 10px 12px; font-size: 12px; line-height: 1.35; }
	.flex { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
	.right { margin-left: auto; }
	.hide { display: none !important; }
	.drop { border: 2px dashed var(--axis); border-radius: 10px; padding: 28px; text-align: center; background: var(--surface); }
	.drop.over { border-color: var(--accent); background: var(--surface-2); }
	.checks { display: flex; flex-wrap: wrap; gap: 4px 12px; max-height: 160px; overflow: auto; padding: 6px 8px; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); font-size: 12.5px; }
	.checks label { display: inline-flex; align-items: center; gap: 5px; white-space: nowrap; }
	.sep { height: 1px; background: var(--border); margin: 14px 0; }
	@media print { .sp-top, .sp-filters, .tabs, .btn { display: none !important; } .tabpane { display: block !important; } body { background: #fff; } }
	@media (forced-colors: active) { .badge i, .legend i { forced-color-adjust: none; } }

	/* ================= portal shell ================= */
	body.pt { min-height: 100vh; }
	.pt-top { position: sticky; top: 0; z-index: 30; height: 52px; display: flex; align-items: center; gap: 14px; padding: 0 16px; background: var(--surface); border-bottom: 1px solid var(--border); }
	.pt-brand { display: flex; align-items: center; gap: 8px; font-weight: 650; font-size: 15px; color: var(--ink); white-space: nowrap; }
	.pt-brand:hover { text-decoration: none; }
	.pt-brand svg { width: 22px; height: 22px; }
	.pt-inst { color: var(--ink-2); font-size: 12.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding-left: 14px; border-left: 1px solid var(--border); }
	.pt-inst b { color: var(--ink); }
	.pt-chips { display: flex; gap: 6px; flex-wrap: nowrap; overflow: hidden; }
	.pt-chip { font-size: 11.5px; padding: 2px 8px; border-radius: 999px; border: 1px solid var(--border); background: var(--surface-2); color: var(--ink-2); white-space: nowrap; display: inline-flex; gap: 5px; align-items: center; }
	.pt-chip i { width: 7px; height: 7px; border-radius: 50%; background: var(--good); display: inline-block; }
	.pt-chip.warn i { background: var(--warning); } .pt-chip.bad i { background: var(--critical); }
	.pt-burger { display: none; background: none; border: 1px solid var(--border); border-radius: 6px; color: var(--ink); font-size: 16px; padding: 2px 8px; cursor: pointer; }
	.pt-wrap { display: flex; align-items: stretch; }
	.pt-side { position: sticky; top: 52px; align-self: flex-start; width: 232px; flex: 0 0 232px; height: calc(100vh - 52px); overflow-y: auto; background: var(--surface); border-right: 1px solid var(--border); padding: 10px 8px 20px; display: flex; flex-direction: column; }
	.pt-grp { margin-bottom: 10px; }
	.pt-gh { font-size: 11px; font-weight: 700; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; padding: 8px 10px 4px; }
	.pt-side a { display: block; padding: 6px 10px; border-radius: 6px; color: var(--ink-2); font-size: 13.5px; }
	.pt-side a:hover { background: var(--surface-2); text-decoration: none; color: var(--ink); }
	.pt-side a.on { background: color-mix(in srgb, var(--accent) 14%, transparent); color: var(--ink); font-weight: 600; box-shadow: inset 3px 0 0 var(--accent); }
	.pt-side-foot { margin-top: auto; font-size: 11px; color: var(--muted); padding: 10px; }
	.pt-main { flex: 1; min-width: 0; max-width: none; margin: 0; padding: 18px 22px 40px; }
	.pt-foot { margin-top: 30px; }
	.sp-main.pt-main { max-width: 1600px; }
	@media (max-width: 900px) {
	  .pt-burger { display: inline-block; }
	  .pt-inst, .pt-chips { display: none; }
	  .pt-side { position: fixed; left: 0; top: 52px; z-index: 40; transform: translateX(-100%); transition: transform .15s; box-shadow: 0 8px 24px rgba(0,0,0,.2); }
	  .pt-side.open { transform: none; }
	  .pt-main { padding: 14px 12px 30px; }
	}
	@media print { .pt-top, .pt-side { display: none !important; } }
	.stat { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
	.stat > div, .stat > a { border: 1px solid var(--border); border-radius: 9px; padding: 9px 12px; background: var(--surface); }
	.stat .l { font-size: 11.5px; color: var(--ink-2); }
	.stat .v { font-size: 17px; font-weight: 650; margin-top: 2px; display: flex; align-items: center; gap: 6px; overflow-wrap: anywhere; min-width: 0; }
	.stat > a:hover { border-color: var(--accent); text-decoration: none; }
	.dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; background: var(--muted); flex: 0 0 9px; }
	.dot.ok { background: var(--good); } .dot.warn { background: var(--warning); } .dot.bad { background: var(--critical); }
	.tile-link { display: block; color: inherit; }
	.tile-link:hover { text-decoration: none; border-color: var(--accent); }
	.bigsub { font-size: 12.5px; color: var(--ink-2); }
	.pause { font-size: 12px; }
	table.t tr.row-warn td { background: color-mix(in srgb, var(--warning) 12%, transparent); }
	table.t tr.row-bad td { background: color-mix(in srgb, var(--critical) 12%, transparent); }
	table.t tr.row-bad td:first-child { box-shadow: inset 3px 0 0 var(--critical); }
	table.t tr.row-warn td:first-child { box-shadow: inset 3px 0 0 var(--warning); }
	table.t tr.muted td { color: var(--muted); }
	p.err { color: var(--crit-ink); }
	.nowrap { white-space: nowrap; }
	.iframe-wrap { border: 1px solid var(--border); border-radius: 8px; overflow: hidden; background: #fff; }
	.iframe-wrap iframe { width: 100%; height: 75vh; border: 0; display: block; }
	.form-row { display: flex; flex-wrap: wrap; gap: 12px; align-items: flex-end; }
	.form-row label { display: flex; flex-direction: column; gap: 4px; font-size: 13px; color: var(--ink-2); }
	.progress { height: 8px; border-radius: 4px; background: var(--border); overflow: hidden; margin: 8px 0; }
	.progress > i { display: block; height: 100%; background: var(--s1); transition: width .4s; }
	.sp-filters label.flex { flex-direction: row; align-items: center; gap: 6px; }
	@media (max-width: 520px) { .pt-top .sp-user { display: none; } .pt-brand { font-size: 15px; } .pt-top { gap: 8px; } }
}

XData JS [ MimeType = application/javascript ]
{
	/* SysPerf - IRIS performance analytics UI helpers (no external dependencies) */
	(function () {
	  'use strict';
	  var SP = window.SP = window.SP || {};
	  var CFG = window.SP_CFG || {};
	  var SVGNS = 'http://www.w3.org/2000/svg';
	  var MON = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
	  var DOW = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
	  SP.DOW = DOW;

	  /* ------------------------------------------------------------ basics */
	  SP.$ = function (s, r) { return (r || document).querySelector(s); };
	  SP.$$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
	  SP.el = function (tag, attrs, kids) {
	    var e = document.createElement(tag);
	    if (attrs) for (var k in attrs) {
	      if (!attrs.hasOwnProperty(k) || attrs[k] == null) continue;
	      if (k === 'text') e.textContent = attrs[k];
	      else if (k === 'cls') e.className = attrs[k];
	      else if (k.slice(0, 2) === 'on') e.addEventListener(k.slice(2), attrs[k]);
	      else e.setAttribute(k, attrs[k]);
	    }
	    (kids || []).forEach(function (c) { if (c == null) return; e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
	    return e;
	  };
	  function svg(tag, attrs) { var e = document.createElementNS(SVGNS, tag); for (var k in attrs) if (attrs[k] != null) e.setAttribute(k, attrs[k]); return e; }
	  SP.clear = function (e) { while (e && e.firstChild) e.removeChild(e.firstChild); return e; };
	  SP.fmt = function (v, d) {
	    if (v === null || v === undefined || v === '' || isNaN(v)) return '–';
	    v = +v;
	    if (d === undefined) d = Math.abs(v) >= 100 ? 0 : (Math.abs(v) >= 10 ? 1 : 2);
	    return v.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: d });
	  };
	  SP.big = function (v) {
	    if (v === null || v === undefined || v === '' || isNaN(v)) return '–';
	    v = +v; var a = Math.abs(v);
	    if (a >= 1e9) return (v / 1e9).toFixed(1) + 'G';
	    if (a >= 1e6) return (v / 1e6).toFixed(1) + 'M';
	    if (a >= 1e4) return (v / 1e3).toFixed(1) + 'k';
	    return SP.fmt(v);
	  };
	  SP.ts = function (s) { // "yyyy-mm-dd hh:mm:ss" (local) -> ms
	    if (!s) return NaN;
	    var m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?/.exec(s);
	    if (!m) return NaN;
	    return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0)).getTime();
	  };
	  function p2(n) { return (n < 10 ? '0' : '') + n; }
	  SP.dstr = function (ms) { var d = new Date(ms); return d.getFullYear() + '-' + p2(d.getMonth() + 1) + '-' + p2(d.getDate()); };
	  SP.tstr = function (ms, withSec) { var d = new Date(ms); return p2(d.getHours()) + ':' + p2(d.getMinutes()) + (withSec ? ':' + p2(d.getSeconds()) : ''); };
	  SP.dtstr = function (ms) { var d = new Date(ms); return p2(d.getDate()) + ' ' + MON[d.getMonth()] + ' ' + d.getFullYear() + ' ' + SP.tstr(ms, true); };
	  SP.qs = function (name) { var m = new RegExp('[?&]' + name + '=([^&#]*)').exec(location.search); return m ? decodeURIComponent(m[1].replace(/\+/g, ' ')) : ''; };
	  SP.color = function (i) { return 'var(--s' + ((i % 8) + 1) + ')'; };

	  /* ------------------------------------------------------------ data API */
	  SP.api = function (action, params, endpoint) {
	    var q = ['action=' + encodeURIComponent(action)];
	    params = params || {};
	    for (var k in params) if (params.hasOwnProperty(k) && params[k] !== undefined && params[k] !== null) q.push(encodeURIComponent(k) + '=' + encodeURIComponent(params[k]));
	    return fetch((endpoint || CFG.data || 'SysPerf.UI.Data.cls') + '?' + q.join('&'), { credentials: 'same-origin', headers: { 'Accept': 'application/json' } })
	      .then(function (r) {
	        if (!r.ok) throw new Error('HTTP ' + r.status);
	        return r.json();
	      }).then(function (j) { if (j && j.error) throw new Error(j.error); return j; });
	  };
	  SP.post = function (url, data) {
	    var fd = new FormData();
	    for (var k in data) if (data.hasOwnProperty(k)) fd.append(k, data[k]);
	    fd.append('csrf', CFG.csrf || '');
	    return fetch(url, { method: 'POST', body: fd, credentials: 'same-origin', headers: { 'X-CSRF-Token': CFG.csrf || '' } })
	      .then(function (r) { return r.json(); }).then(function (j) { if (j && j.error) throw new Error(j.error); return j; });
	  };
	  SP.fail = function (host, err) {
	    if (!host) return;
	    SP.clear(host).appendChild(SP.el('div', { cls: 'notice err', text: 'Could not load data: ' + (err && err.message ? err.message : err) }));
	  };

	  /* ------------------------------------------------------------ tooltip */
	  var tipEl = null;
	  function tip() { if (!tipEl) { tipEl = SP.el('div', { cls: 'tip', role: 'tooltip' }); document.body.appendChild(tipEl); } return tipEl; }
	  SP.tipShow = function (x, y, title, rows) {
	    var t = tip(); SP.clear(t);
	    if (title) t.appendChild(SP.el('div', { cls: 'tt', text: title }));
	    rows.forEach(function (r) {
	      var line = SP.el('div', { cls: 'tr' });
	      if (r.color) { var i = SP.el('i'); i.style.background = r.color; line.appendChild(i); }
	      line.appendChild(SP.el('b', { text: r.value }));
	      if (r.label) line.appendChild(SP.el('span', { text: r.label }));
	      t.appendChild(line);
	    });
	    t.style.display = 'block';
	    var w = t.offsetWidth, h = t.offsetHeight;
	    var left = x + 14, top = y + 14;
	    if (left + w > window.innerWidth - 8) left = x - w - 14;
	    if (top + h > window.innerHeight - 8) top = y - h - 14;
	    t.style.left = Math.max(4, left) + 'px'; t.style.top = Math.max(4, top) + 'px';
	  };
	  SP.tipHide = function () { if (tipEl) tipEl.style.display = 'none'; };

	  /* ------------------------------------------------------------ scales */
	  function niceNum(range, round) {
	    if (range <= 0) return 1;
	    var exp = Math.floor(Math.log10(range)), f = range / Math.pow(10, exp), nf;
	    if (round) nf = f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10; else nf = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
	    return nf * Math.pow(10, exp);
	  }
	  function niceTicks(min, max, n) {
	    if (min === max) { max = min + (min === 0 ? 1 : Math.abs(min) * 0.1); }
	    var range = niceNum(max - min, false), step = niceNum(range / (n - 1), true);
	    var lo = Math.floor(min / step) * step, hi = Math.ceil(max / step) * step, out = [];
	    for (var v = lo; v <= hi + step / 2; v += step) out.push(+v.toFixed(10));
	    return out;
	  }
	  var TSTEPS = [60e3, 300e3, 900e3, 1800e3, 3600e3, 10800e3, 21600e3, 43200e3, 864e5, 1728e5, 6048e5, 2592e6];
	  function timeTicks(t0, t1, n) {
	    var span = t1 - t0, step = TSTEPS[TSTEPS.length - 1];
	    for (var i = 0; i < TSTEPS.length; i++) if (span / TSTEPS[i] <= n) { step = TSTEPS[i]; break; }
	    var d = new Date(t0), start;
	    if (step >= 864e5) { start = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); }
	    else { var off = new Date(t0).getTimezoneOffset() * 60e3; start = Math.floor((t0 - off) / step) * step + off; }
	    var out = [];
	    for (var t = start; t <= t1; t += step) if (t >= t0) out.push(t);
	    return { ticks: out, step: step };
	  }
	  function timeLabel(t, step, span) {
	    var d = new Date(t);
	    if (step >= 864e5) return p2(d.getDate()) + ' ' + MON[d.getMonth()];
	    if (span > 864e5 && d.getHours() === 0 && d.getMinutes() === 0) return p2(d.getDate()) + ' ' + MON[d.getMonth()];
	    return SP.tstr(t);
	  }

	  /* ------------------------------------------------------------ line chart
	     opts: { series:[{name, pts:[[x,y],...], color, dash, band:[[x,lo,hi]]}], unit, height, xType:'time'|'num',
	             xLabel, yZero:true, refs:[{v,label}], zoom:true, title } */
	  SP.lineChart = function (host, opts) {
	    host.classList.add('chart');
	    var state = { hidden: {}, zoom: null };
	    function draw() {
	      SP.clear(host);
	      var series = (opts.series || []).filter(function (s) { return s.pts && s.pts.length; });
	      if (!series.length) { host.appendChild(SP.el('div', { cls: 'empty', text: opts.empty || 'No data for this selection' })); return; }
	      var multi = series.length > 1;
	      if (multi) {
	        var lg = SP.el('div', { cls: 'legend' });
	        series.forEach(function (s, i) {
	          var c = s.color || SP.color(i), it = SP.el('i'); it.style.background = c;
	          if (s.dash) it.style.background = 'repeating-linear-gradient(90deg,' + c + ' 0 4px,transparent 4px 6px)';
	          var sp = SP.el('span', { cls: state.hidden[s.name] ? 'off' : '', title: 'Show / hide', onclick: function () { state.hidden[s.name] = !state.hidden[s.name]; draw(); } }, [it, s.name]);
	          lg.appendChild(sp);
	        });
	        host.appendChild(lg);
	      }
	      var vis = series.filter(function (s) { return !state.hidden[s.name]; });
	      var W = Math.max(280, host.clientWidth || 600), H = opts.height || 220;
	      var labelRoom = (multi && vis.length <= 4 && W > 520) ? 78 : 12;
	      var m = { l: 52, r: labelRoom, t: 8, b: 24 };
	      var x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
	      vis.forEach(function (s) {
	        s.pts.forEach(function (p) { if (p[0] < x0) x0 = p[0]; if (p[0] > x1) x1 = p[0]; });
	      });
	      if (state.zoom) { x0 = state.zoom[0]; x1 = state.zoom[1]; }
	      vis.forEach(function (s) {
	        s.pts.forEach(function (p) { if (p[0] < x0 || p[0] > x1 || p[1] == null) return; if (p[1] < y0) y0 = p[1]; if (p[1] > y1) y1 = p[1]; });
	        (s.band || []).forEach(function (b) { if (b[0] < x0 || b[0] > x1) return; if (b[2] != null && b[2] > y1) y1 = b[2]; if (b[1] != null && b[1] < y0) y0 = b[1]; });
	      });
	      (opts.refs || []).forEach(function (r) { if (r.v > y1 && r.v < y1 * 1.6) y1 = r.v; });
	      if (!isFinite(y0)) { y0 = 0; y1 = 1; }
	      if (opts.yZero !== false && y0 > 0) y0 = 0;
	      if (opts.yMax != null && y1 < opts.yMax) y1 = Math.max(y1, Math.min(opts.yMax, y1 * 1.05));
	      if (x0 === x1) { x0 -= 30e3; x1 += 30e3; }
	      var yt = niceTicks(y0, y1, 5); y0 = yt[0]; y1 = yt[yt.length - 1];
	      var pw = W - m.l - m.r, ph = H - m.t - m.b;
	      var X = function (v) { return m.l + (v - x0) / (x1 - x0) * pw; };
	      var Y = function (v) { return m.t + ph - (v - y0) / (y1 - y0) * ph; };
	      var s = svg('svg', { viewBox: '0 0 ' + W + ' ' + H, height: H, role: 'img', 'aria-label': opts.title || 'chart' });
	      var gl = svg('g', { 'class': 'gl' }), ax = svg('g', { 'class': 'ax' });
	      yt.forEach(function (v) {
	        gl.appendChild(svg('line', { x1: m.l, x2: W - m.r, y1: Y(v), y2: Y(v) }));
	        var tx = svg('text', { x: m.l - 6, y: Y(v) + 4, 'text-anchor': 'end' }); tx.textContent = SP.big(v); ax.appendChild(tx);
	      });
	      if (opts.unit) { var ut = svg('text', { x: 2, y: m.t + 2, 'text-anchor': 'start', 'dominant-baseline': 'hanging' }); ut.textContent = opts.unit; ut.setAttribute('transform', 'translate(0,' + (ph / 2) + ')'); }
	      ax.appendChild(svg('line', { x1: m.l, x2: W - m.r, y1: Y(y0), y2: Y(y0) }));
	      if (opts.xType === 'num') {
	        niceTicks(x0, x1, 7).forEach(function (v) { if (v < x0 || v > x1) return; var tx = svg('text', { x: X(v), y: H - 6, 'text-anchor': 'middle' }); tx.textContent = SP.fmt(v) + (opts.xLabel ? ' ' + opts.xLabel : ''); ax.appendChild(tx); });
	      } else {
	        var tt = timeTicks(x0, x1, Math.max(3, Math.floor(pw / 90)));
	        tt.ticks.forEach(function (t) { var tx = svg('text', { x: X(t), y: H - 6, 'text-anchor': 'middle' }); tx.textContent = timeLabel(t, tt.step, x1 - x0); ax.appendChild(tx); gl.appendChild(svg('line', { x1: X(t), x2: X(t), y1: m.t, y2: m.t + ph, 'stroke-opacity': 0.5 })); });
	      }
	      s.appendChild(gl); s.appendChild(ax);
	      var refLabels = [];
	      (opts.refs || []).forEach(function (r) {
	        if (r.v < y0 || r.v > y1) return;
	        s.appendChild(svg('line', { x1: m.l, x2: W - m.r, y1: Y(r.v), y2: Y(r.v), stroke: r.color || 'var(--muted)', 'stroke-dasharray': '4 4', 'stroke-width': 1 }));
	        var rt = svg('text', { x: m.l + 4, y: Y(r.v) - 4, 'text-anchor': 'start', fill: 'var(--ink-2)', 'font-size': 10, stroke: 'var(--surface)', 'stroke-width': 3, 'paint-order': 'stroke' }); rt.textContent = r.label || ''; refLabels.push(rt);
	      });
	      var clipId = 'c' + Math.random().toString(36).slice(2);
	      var defs = svg('defs', {}), cp = svg('clipPath', { id: clipId }); cp.appendChild(svg('rect', { x: m.l, y: m.t - 2, width: pw, height: ph + 4 })); defs.appendChild(cp); s.appendChild(defs);
	      var plot = svg('g', { 'clip-path': 'url(#' + clipId + ')' });
	      var endLabels = [];
	      series.forEach(function (sr, idx) {
	        if (state.hidden[sr.name]) return;
	        var c = sr.color || SP.color(idx);
	        var gap = gapOf(sr.pts);
	        if (sr.band && sr.band.length) {
	          var segsB = split(sr.band, gap);
	          segsB.forEach(function (seg) {
	            var d = '';
	            seg.forEach(function (b, i) { d += (i ? 'L' : 'M') + X(b[0]).toFixed(1) + ',' + Y(b[2]).toFixed(1); });
	            for (var i = seg.length - 1; i >= 0; i--) d += 'L' + X(seg[i][0]).toFixed(1) + ',' + Y(seg[i][1]).toFixed(1);
	            plot.appendChild(svg('path', { d: d + 'Z', fill: c, 'fill-opacity': 0.13, stroke: 'none' }));
	          });
	        }
	        var segs = split(sr.pts, gap);
	        segs.forEach(function (seg) {
	          if (seg.length === 1) { plot.appendChild(svg('circle', { cx: X(seg[0][0]), cy: Y(seg[0][1]), r: 2.5, fill: c })); return; }
	          var d = '';
	          seg.forEach(function (p, i) { d += (i ? 'L' : 'M') + X(p[0]).toFixed(1) + ',' + Y(p[1]).toFixed(1); });
	          plot.appendChild(svg('path', { d: d, fill: 'none', stroke: c, 'stroke-width': sr.width || 2, 'stroke-linejoin': 'round', 'stroke-linecap': 'round', 'stroke-dasharray': sr.dash ? '5 4' : null }));
	        });
	        if (labelRoom > 12) {
	          var last = null;
	          for (var i = sr.pts.length - 1; i >= 0; i--) if (sr.pts[i][0] <= x1 && sr.pts[i][1] != null) { last = sr.pts[i]; break; }
	          if (last) endLabels.push({ y: Y(last[1]), name: sr.name, c: c });
	        }
	      });
	      s.appendChild(plot);
	      // direct labels with simple collision avoidance
	      endLabels.sort(function (a, b) { return a.y - b.y; });
	      for (var i = 1; i < endLabels.length; i++) if (endLabels[i].y - endLabels[i - 1].y < 12) endLabels[i].y = endLabels[i - 1].y + 12;
	      endLabels.forEach(function (l) {
	        var t = svg('text', { x: W - m.r + 6, y: l.y + 4, fill: 'var(--ink-2)', 'font-size': 11 });
	        t.textContent = l.name.length > 11 ? l.name.slice(0, 10) + '…' : l.name; s.appendChild(t);
	      });
	      refLabels.forEach(function (t) { s.appendChild(t); });
	      // interaction layer
	      var xh = svg('line', { 'class': 'xh', y1: m.t, y2: m.t + ph, visibility: 'hidden' });
	      var dots = svg('g', {}), sel = svg('rect', { y: m.t, height: ph, fill: 'var(--accent)', 'fill-opacity': 0.12, visibility: 'hidden' });
	      s.appendChild(xh); s.appendChild(dots); s.appendChild(sel);
	      var hit = svg('rect', { x: m.l, y: m.t, width: pw, height: ph, fill: 'transparent', style: 'cursor:crosshair' });
	      s.appendChild(hit);
	      var drag = null;
	      function toX(ev) { var r = s.getBoundingClientRect(); return (ev.clientX - r.left) * (W / r.width); }
	      hit.addEventListener('pointerdown', function (ev) { if (opts.zoom === false) return; drag = toX(ev); hit.setPointerCapture(ev.pointerId); });
	      hit.addEventListener('pointermove', function (ev) {
	        var px = toX(ev);
	        if (drag != null) { var a = Math.min(drag, px), b = Math.max(drag, px); sel.setAttribute('x', a); sel.setAttribute('width', b - a); sel.setAttribute('visibility', 'visible'); }
	        var xv = x0 + (px - m.l) / pw * (x1 - x0), rows = [], best = null;
	        SP.clear(dots);
	        series.forEach(function (sr, idx) {
	          if (state.hidden[sr.name]) return;
	          var p = nearest(sr.pts, xv); if (!p) return;
	          if (best === null || Math.abs(p[0] - xv) < Math.abs(best - xv)) best = p[0];
	        });
	        if (best === null) return;
	        series.forEach(function (sr, idx) {
	          if (state.hidden[sr.name]) return;
	          var p = nearest(sr.pts, best); if (!p || Math.abs(p[0] - best) > gapOf(sr.pts)) return;
	          var c = sr.color || SP.color(idx);
	          if (p[1] != null) dots.appendChild(svg('circle', { cx: X(p[0]), cy: Y(p[1]), r: 4, fill: c, stroke: 'var(--surface)', 'stroke-width': 2 }));
	          var b = sr.band ? nearest(sr.band, best) : null;
	          rows.push({ color: c, value: SP.fmt(p[1]) + (opts.unit ? ' ' + opts.unit : ''), label: sr.name + (b && b[0] === p[0] ? '  (' + (sr.bandLabel || 'range') + ' ' + SP.fmt(b[1]) + '–' + SP.fmt(b[2]) + ')' : '') });
	        });
	        xh.setAttribute('x1', X(best)); xh.setAttribute('x2', X(best)); xh.setAttribute('visibility', 'visible');
	        var title = opts.xType === 'num' ? SP.fmt(best) + (opts.xLabel ? ' ' + opts.xLabel : '') : (opts.dateOnly ? SP.dstr(best) : SP.dtstr(best));
	        SP.tipShow(ev.clientX, ev.clientY, title, rows);
	      });
	      hit.addEventListener('pointerup', function (ev) {
	        if (drag == null) return;
	        var px = toX(ev), a = Math.min(drag, px), b = Math.max(drag, px); drag = null; sel.setAttribute('visibility', 'hidden');
	        if (b - a < 8) { if (opts.onClick) { var xv = x0 + (px - m.l) / pw * (x1 - x0); opts.onClick(xv); } return; }
	        state.zoom = [x0 + (a - m.l) / pw * (x1 - x0), x0 + (b - m.l) / pw * (x1 - x0)];
	        SP.tipHide(); draw();
	      });
	      hit.addEventListener('pointerleave', function () { xh.setAttribute('visibility', 'hidden'); SP.clear(dots); SP.tipHide(); });
	      host.appendChild(s);
	      if (state.zoom) host.appendChild(SP.el('button', { cls: 'btn sm', text: 'Reset zoom', onclick: function () { state.zoom = null; draw(); } }));
	      else if (opts.zoom !== false && opts.hint !== false) host.appendChild(SP.el('div', { cls: 'muted small', text: 'Drag across the chart to zoom' }));
	    }
	    function gapOf(pts) {
	      if (pts.length < 3) return Infinity;
	      var d = [];
	      for (var i = 1; i < pts.length && i < 400; i++) d.push(pts[i][0] - pts[i - 1][0]);
	      d.sort(function (a, b) { return a - b; });
	      return (d[Math.floor(d.length / 2)] || 1) * 3.5;
	    }
	    function split(pts, gap) {
	      var out = [], cur = [];
	      pts.forEach(function (p, i) {
	        if (p[1] == null) { if (cur.length) out.push(cur); cur = []; return; }
	        if (cur.length && p[0] - cur[cur.length - 1][0] > gap) { out.push(cur); cur = []; }
	        cur.push(p);
	      });
	      if (cur.length) out.push(cur);
	      return out;
	    }
	    function nearest(pts, x) {
	      if (!pts || !pts.length) return null;
	      var lo = 0, hi = pts.length - 1;
	      while (hi - lo > 1) { var mid = (lo + hi) >> 1; if (pts[mid][0] < x) lo = mid; else hi = mid; }
	      return Math.abs(pts[lo][0] - x) <= Math.abs(pts[hi][0] - x) ? pts[lo] : pts[hi];
	    }
	    draw();
	    if (window.ResizeObserver) { var lw = host.clientWidth; new ResizeObserver(function () { if (Math.abs(host.clientWidth - lw) > 20) { lw = host.clientWidth; draw(); } }).observe(host); }
	    return { redraw: draw };
	  };

	  /* ------------------------------------------------------------ horizontal bar chart
	     opts: { rows:[{label, value, sub, color}], unit, max } */
	  SP.barChart = function (host, opts) {
	    host.classList.add('chart'); SP.clear(host);
	    var rows = opts.rows || [];
	    if (!rows.length) { host.appendChild(SP.el('div', { cls: 'empty', text: opts.empty || 'No data' })); return; }
	    var W = Math.max(280, host.clientWidth || 500), rh = 26, lw = Math.min(260, Math.max(90, W * 0.34)), H = rows.length * rh + 6;
	    var max = opts.max || Math.max.apply(null, rows.map(function (r) { return +r.value || 0; })) || 1;
	    var s = svg('svg', { viewBox: '0 0 ' + W + ' ' + H, height: H });
	    rows.forEach(function (r, i) {
	      var y = i * rh + 3, bw = Math.max(2, (W - lw - 70) * (+r.value || 0) / max);
	      var t = svg('text', { x: lw - 8, y: y + 15, 'text-anchor': 'end', fill: 'var(--ink-2)', 'font-size': 12 }); var mc = Math.max(8, Math.floor((lw - 12) / 6.6)); t.textContent = r.label.length > mc ? r.label.slice(0, mc - 1) + '…' : r.label; s.appendChild(t);
	      var bar = svg('rect', { x: lw, y: y + 4, width: bw, height: rh - 10, rx: 3, fill: r.color || 'var(--s1)' });
	      s.appendChild(bar);
	      var v = svg('text', { x: lw + bw + 6, y: y + 15, fill: 'var(--ink)', 'font-size': 12 }); v.textContent = SP.fmt(r.value) + (opts.unit ? ' ' + opts.unit : ''); s.appendChild(v);
	      var hit = svg('rect', { x: 0, y: y, width: W, height: rh, fill: 'transparent' });
	      hit.addEventListener('pointermove', function (ev) { bar.setAttribute('fill-opacity', 0.8); SP.tipShow(ev.clientX, ev.clientY, r.label, [{ value: SP.fmt(r.value) + (opts.unit ? ' ' + opts.unit : ''), label: r.sub || '' }]); });
	      hit.addEventListener('pointerleave', function () { bar.removeAttribute('fill-opacity'); SP.tipHide(); });
	      if (r.href) { hit.style.cursor = 'pointer'; hit.addEventListener('click', function () { location.href = r.href; }); }
	      s.appendChild(hit);
	    });
	    host.appendChild(s);
	  };

	  /* ------------------------------------------------------------ heatmap (day of week x hour)
	     opts: { cells:[{dow:1..7, hour:0..23, value, n}], unit } */
	  SP.heatmap = function (host, opts) {
	    host.classList.add('chart'); SP.clear(host);
	    var cells = opts.cells || [];
	    if (!cells.length) { host.appendChild(SP.el('div', { cls: 'empty', text: 'No data for this selection' })); return; }
	    var map = {}, vmin = Infinity, vmax = -Infinity;
	    cells.forEach(function (c) { map[c.dow + ':' + c.hour] = c; if (c.value < vmin) vmin = c.value; if (c.value > vmax) vmax = c.value; });
	    var W = Math.max(300, host.clientWidth || 600), lw = 36, th = 18, cw = (W - lw) / 24, ch = Math.max(16, Math.min(28, cw * 0.8)), H = th + ch * 7;
	    var s = svg('svg', { viewBox: '0 0 ' + W + ' ' + H, height: H });
	    for (var h = 0; h < 24; h += (cw < 22 ? 3 : 1)) { var t = svg('text', { x: lw + h * cw + cw / 2, y: 12, 'text-anchor': 'middle', fill: 'var(--muted)', 'font-size': 10 }); t.textContent = p2(h); s.appendChild(t); }
	    for (var d = 1; d <= 7; d++) {
	      var dl = svg('text', { x: lw - 6, y: th + (d - 1) * ch + ch / 2 + 4, 'text-anchor': 'end', fill: 'var(--muted)', 'font-size': 11 }); dl.textContent = DOW[d - 1]; s.appendChild(dl);
	      for (var hh = 0; hh < 24; hh++) {
	        (function (d, hh) {
	          var c = map[d + ':' + hh], fill = 'var(--seq-0)';
	          if (c) { var k = vmax > vmin ? (c.value - vmin) / (vmax - vmin) : 0.5; fill = 'var(--seq-' + (1 + Math.min(6, Math.floor(k * 6.999))) + ')'; }
	          var r = svg('rect', { x: lw + hh * cw + 1, y: th + (d - 1) * ch + 1, width: cw - 2, height: ch - 2, rx: 2, fill: fill });
	          r.addEventListener('pointermove', function (ev) { r.setAttribute('stroke', 'var(--ink)'); SP.tipShow(ev.clientX, ev.clientY, DOW[d - 1] + ' ' + p2(hh) + ':00–' + p2(hh) + ':59', [{ value: c ? SP.fmt(c.value) + (opts.unit ? ' ' + opts.unit : '') : 'no data', label: c ? (c.n + ' hour(s) of data') : '' }]); });
	          r.addEventListener('pointerleave', function () { r.removeAttribute('stroke'); SP.tipHide(); });
	          s.appendChild(r);
	        })(d, hh);
	      }
	    }
	    host.appendChild(s);
	    var lg = SP.el('div', { cls: 'hm-legend' }, [SP.el('span', { text: SP.fmt(vmin) }), (function () { var r = SP.el('div', { cls: 'ramp' }); for (var i = 1; i <= 7; i++) { var x = SP.el('i'); x.style.background = 'var(--seq-' + i + ')'; r.appendChild(x); } return r; })(), SP.el('span', { text: SP.fmt(vmax) + (opts.unit ? ' ' + opts.unit : '') }), SP.el('span', { text: '   grey = no data' })]);
	    host.appendChild(lg);
	  };

	  /* ------------------------------------------------------------ table
	     opts: { columns:[{k,l,num,fmt(v,row),link(row),cls,title(row),nosort}], rows, page:50, search:true, csv:'name', sort:{k,dir}, rowCls(row), empty } */
	  SP.table = function (host, opts) {
	    SP.clear(host);
	    var st = { q: '', sort: opts.sort || null, page: 0 }, size = opts.page || 50;
	    var bar = SP.el('div', { cls: 'tbl-bar' }), wrap = SP.el('div', { cls: 'tbl-wrap' }), foot = SP.el('div', { cls: 'tbl-foot' });
	    if (opts.search !== false) {
	      var inp = SP.el('input', { type: 'search', placeholder: 'Filter rows…', 'aria-label': 'Filter rows' });
	      inp.addEventListener('input', function () { st.q = inp.value.toLowerCase(); st.page = 0; render(); });
	      bar.appendChild(inp);
	    }
	    bar.appendChild(SP.el('div', { cls: 'grow' }));
	    if (opts.tools) opts.tools.forEach(function (t) { bar.appendChild(t); });
	    if (opts.csv !== false) bar.appendChild(SP.el('button', { cls: 'btn sm', text: 'Download CSV', onclick: function () { SP.csv(opts.csv || 'data', opts.columns, filtered()); } }));
	    host.appendChild(bar); host.appendChild(wrap); host.appendChild(foot);
	    function filtered() {
	      var rows = opts.rows || [];
	      if (st.q) rows = rows.filter(function (r) { return opts.columns.some(function (c) { var v = r[c.k]; return v != null && String(v).toLowerCase().indexOf(st.q) >= 0; }); });
	      if (st.sort) {
	        var k = st.sort.k, dir = st.sort.dir === 'desc' ? -1 : 1, col = opts.columns.filter(function (c) { return c.k === k; })[0] || {};
	        rows = rows.slice().sort(function (a, b) {
	          var x = a[k], y = b[k];
	          if (x == null || x === '') return 1; if (y == null || y === '') return -1;
	          if (col.num) return (x - y) * dir;
	          return String(x).localeCompare(String(y), undefined, { numeric: true }) * dir;
	        });
	      }
	      return rows;
	    }
	    function render() {
	      var rows = filtered(), pages = Math.max(1, Math.ceil(rows.length / size));
	      if (st.page >= pages) st.page = pages - 1;
	      var t = SP.el('table', { cls: 't' }), thead = SP.el('thead'), tr = SP.el('tr');
	      opts.columns.forEach(function (c) {
	        var th = SP.el('th', { cls: (c.num ? 'num' : '') + (c.nosort ? ' nosort' : ''), title: c.help || null }, [c.l]);
	        if (st.sort && st.sort.k === c.k) th.appendChild(SP.el('span', { cls: 'arr', text: st.sort.dir === 'desc' ? '▼' : '▲' }));
	        if (!c.nosort) th.addEventListener('click', function () { st.sort = { k: c.k, dir: st.sort && st.sort.k === c.k && st.sort.dir === 'asc' ? 'desc' : 'asc' }; render(); });
	        tr.appendChild(th);
	      });
	      thead.appendChild(tr); t.appendChild(thead);
	      var tb = SP.el('tbody');
	      rows.slice(st.page * size, st.page * size + size).forEach(function (r) {
	        var row = SP.el('tr', { cls: opts.rowCls ? opts.rowCls(r) : null });
	        opts.columns.forEach(function (c) {
	          var v = r[c.k], td = SP.el('td', { cls: (c.num ? 'num ' : '') + (c.cls || '') });
	          if (c.render) { var n = c.render(v, r); if (n != null) td.appendChild(typeof n === 'string' ? document.createTextNode(n) : n); }
	          else {
	            var txt = c.fmt ? c.fmt(v, r) : (c.num ? SP.fmt(v, c.dec) : (v == null ? '' : String(v)));
	            if (c.link) { var href = c.link(r); if (href) td.appendChild(SP.el('a', { href: href, text: txt })); else td.textContent = txt; }
	            else td.textContent = txt;
	          }
	          row.appendChild(td);
	        });
	        tb.appendChild(row);
	      });
	      if (!rows.length) tb.appendChild(SP.el('tr', {}, [SP.el('td', { colspan: opts.columns.length, cls: 'muted', text: opts.empty || 'No rows' })]));
	      t.appendChild(tb);
	      SP.clear(wrap).appendChild(t);
	      SP.clear(foot);
	      foot.appendChild(SP.el('span', { text: rows.length + ' row' + (rows.length === 1 ? '' : 's') + (st.q ? ' (filtered from ' + (opts.rows || []).length + ')' : '') }));
	      if (pages > 1) {
	        foot.appendChild(SP.el('button', { cls: 'btn sm', text: '‹ Prev', disabled: st.page === 0 ? 'disabled' : null, onclick: function () { st.page--; render(); } }));
	        foot.appendChild(SP.el('span', { text: 'Page ' + (st.page + 1) + ' / ' + pages }));
	        foot.appendChild(SP.el('button', { cls: 'btn sm', text: 'Next ›', disabled: st.page >= pages - 1 ? 'disabled' : null, onclick: function () { st.page++; render(); } }));
	      }
	    }
	    render();
	    return { set: function (rows) { opts.rows = rows; st.page = 0; render(); } };
	  };

	  SP.csv = function (name, cols, rows) {
	    function q(v) { v = v == null ? '' : String(v); return /[",\n\r]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }
	    var out = [cols.map(function (c) { return q(c.l); }).join(',')];
	    rows.forEach(function (r) { out.push(cols.map(function (c) { return q(r[c.k]); }).join(',')); });
	    var blob = new Blob(['﻿' + out.join('\r\n')], { type: 'text/csv;charset=utf-8' });
	    var a = SP.el('a', { href: URL.createObjectURL(blob), download: name.replace(/[^\w.-]+/g, '_') + '.csv' });
	    document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 500);
	  };

	  /* ------------------------------------------------------------ tabs & segmented controls */
	  SP.tabs = function (bar, onShow) {
	    var btns = SP.$$('button[data-tab]', bar), shown = {};
	    function show(id, push) {
	      btns.forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-tab') === id); b.setAttribute('aria-selected', b.getAttribute('data-tab') === id); });
	      SP.$$('.tabpane').forEach(function (p) { p.classList.toggle('on', p.id === 'tab-' + id); });
	      if (!shown[id]) { shown[id] = true; if (onShow) onShow(id); }
	      if (push) try { history.replaceState(null, '', location.pathname + location.search.replace(/([?&])tab=[^&]*/, '$1').replace(/[?&]$/, '') + (location.search.replace(/([?&])tab=[^&]*/, '$1').replace(/[?&]$/, '') ? '&' : '?') + 'tab=' + id); } catch (e) {}
	    }
	    btns.forEach(function (b) { b.setAttribute('role', 'tab'); b.addEventListener('click', function () { show(b.getAttribute('data-tab'), true); }); });
	    var first = SP.qs('tab') || (btns[0] && btns[0].getAttribute('data-tab'));
	    if (!btns.some(function (b) { return b.getAttribute('data-tab') === first; })) first = btns[0].getAttribute('data-tab');
	    show(first);
	    return { show: show };
	  };
	  SP.seg = function (host, items, value, onChange) {
	    SP.clear(host); host.classList.add('seg');
	    items.forEach(function (it) {
	      var b = SP.el('button', { type: 'button', cls: it.v === value ? 'on' : '', text: it.l });
	      b.addEventListener('click', function () { SP.$$('button', host).forEach(function (x) { x.classList.remove('on'); }); b.classList.add('on'); onChange(it.v); });
	      host.appendChild(b);
	    });
	  };
	  SP.badge = function (sev) {
	    var lab = { C: 'Critical', W: 'Warning', I: 'Info', OK: 'OK' }[sev] || sev;
	    return SP.el('span', { cls: 'badge ' + sev }, [SP.el('i'), lab]);
	  };
	  SP.score = function (v) {
	    if (v === '' || v == null) return SP.el('span', { cls: 'muted', text: '–' });
	    return SP.el('span', { cls: 'score ' + (v >= 80 ? 'good' : v >= 55 ? 'warn' : 'bad'), title: 'Health score (100 − 15 per critical − 5 per warning)', text: String(v) });
	  };

	  /* ------------------------------------------------------------ theme toggle */
	  SP.initTheme = function () {
	    var t = null; try { t = localStorage.getItem('sysperf.theme'); } catch (e) {}
	    if (t) document.documentElement.setAttribute('data-theme', t);
	    var b = SP.$('#themeBtn');
	    if (b) b.addEventListener('click', function () {
	      var cur = document.documentElement.getAttribute('data-theme') || (window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
	      var nx = cur === 'dark' ? 'light' : 'dark';
	      document.documentElement.setAttribute('data-theme', nx);
	      try { localStorage.setItem('sysperf.theme', nx); } catch (e) {}
	      if (SP.onTheme) SP.onTheme();
	    });
	  };

	  /* ------------------------------------------------------------ findings renderer */
	  SP.findings = function (host, list, opts) {
	    SP.clear(host); opts = opts || {};
	    if (!list.length) { host.appendChild(SP.el('div', { cls: 'notice ok', text: 'No findings.' })); return; }
	    list.forEach(function (f) {
	      var d = SP.el('details', { cls: 'finding ' + f.sev });
	      if (f.sev === 'C' || (f.sev === 'W' && opts.openWarn)) d.open = true;
	      var sum = SP.el('summary', {}, [SP.badge(f.sev), SP.el('span', { cls: 'f-t', text: f.title }), SP.el('span', { cls: 'f-c', text: f.cat + (f.ack ? ' · acknowledged' : '') })]);
	      d.appendChild(sum);
	      var b = SP.el('div', { cls: 'f-b' });
	      if (f.detail) b.appendChild(SP.el('p', { text: f.detail }));
	      if (f.value !== '' && f.value != null) b.appendChild(SP.el('p', { cls: 'muted small', text: 'Value: ' + SP.fmt(f.value) + (f.thr ? '   Threshold: ' + f.thr : '') }));
	      if (f.rec) { b.appendChild(SP.el('div', { cls: 'f-lab', text: 'Recommendation' })); b.appendChild(SP.el('div', { cls: 'rec', text: f.rec })); }
	      if (f.evidence) { b.appendChild(SP.el('div', { cls: 'f-lab', text: 'Evidence' })); b.appendChild(SP.el('pre', { text: f.evidence })); }
	      if (f.first || f.last) b.appendChild(SP.el('p', { cls: 'muted small', text: 'Peak / time: ' + [f.first, f.last].filter(Boolean).join(' · ') }));
	      var tools = SP.el('div', { cls: 'flex' });
	      if (f.drill && opts.onDrill) tools.appendChild(SP.el('button', { cls: 'btn sm', text: 'Show evidence tab', onclick: function () { opts.onDrill(f.drill); } }));
	      if (opts.canAck && f.sev !== 'OK') {
	        if (f.ack) tools.appendChild(SP.el('span', { cls: 'ack', text: '✓ Acknowledged by ' + f.ackBy + ' ' + (f.ackTS || '') + (f.ackNote ? ' – ' + f.ackNote : '') }));
	        else {
	          var box = SP.el('span', { cls: 'flex hide' });
	          var inp = SP.el('input', { type: 'text', placeholder: 'Note (optional)', maxlength: 400, 'aria-label': 'Acknowledge note' });
	          var msg = SP.el('span', { cls: 'muted small' });
	          box.appendChild(inp);
	          box.appendChild(SP.el('button', { cls: 'btn sm primary', text: 'Save', onclick: function () {
	            SP.post(opts.ackUrl || CFG.runPage || 'SysPerf.UI.Run.cls', { op: 'ack', finding: f.id, note: inp.value }).then(function () { location.reload(); }).catch(function (e) { msg.textContent = e.message; });
	          } }));
	          box.appendChild(msg);
	          tools.appendChild(SP.el('button', { cls: 'btn sm', text: 'Acknowledge…', onclick: function (ev) { ev.target.classList.add('hide'); box.classList.remove('hide'); inp.focus(); } }));
	          tools.appendChild(box);
	        }
	      }
	      if (f.run && opts.linkRun) tools.appendChild(SP.el('a', { cls: 'btn sm', href: 'SysPerf.UI.Run.cls?id=' + f.run, text: 'Open run' }));
	      b.appendChild(tools);
	      d.appendChild(b);
	      host.appendChild(d);
	    });
	  };

	  /* ------------------------------------------------------------ portal chrome (header chips, mobile nav) */
	  SP.status = function (v) { // map IRIS dashboard status text to ok / warn / bad
	    v = String(v == null ? '' : v).toLowerCase();
	    if (!v) return '';
	    if (/(fail|trouble|error|full|frozen|stopped|crit|down)/.test(v)) return 'bad';
	    if (/(warn|expand|low|suspend|pause)/.test(v)) return 'warn';
	    return 'ok';
	  };
	  SP.portalChrome = function () {
	    var btn = SP.$('#navBtn'), side = SP.$('#ptSide');
	    if (btn && side) btn.addEventListener('click', function () { side.classList.toggle('open'); });
	    var host = SP.$('#ptChips'); if (!host) return;
	    function render(d) {
	      SP.clear(host);
	      function chip(label, cls, title) { host.appendChild(SP.el('span', { cls: 'pt-chip ' + (cls || ''), title: title || label }, [SP.el('i'), label])); }
	      if (d.SystemUpTime) chip('Up ' + String(d.SystemUpTime).replace(/\s+/g, ' '), '', 'System uptime');
	      if (d.licenseLimit) { var pct = Math.round(d.licenseUsed * 100 / d.licenseLimit); chip('License ' + d.licenseUsed + '/' + d.licenseLimit, pct > 90 ? 'bad' : pct > 75 ? 'warn' : '', 'License units in use'); }
	      if (d.JournalStatus) chip('Journal ' + d.JournalStatus, SP.status(d.JournalStatus) === 'ok' ? '' : SP.status(d.JournalStatus));
	      if (+d.SeriousAlerts > 0) chip(d.SeriousAlerts + ' alert(s)', 'bad', 'Serious alerts in alerts.log');
	      if (d.mirrorMember) chip('Mirror ' + (d.mirrorType || '') + ' ' + (d.mirrorStatus || ''), '');
	    }
	    var cached = null; try { cached = JSON.parse(sessionStorage.getItem('sysperf.sysinfo') || 'null'); } catch (e) {}
	    if (cached && Date.now() - cached.t < 60000) { render(cached.d); return; }
	    SP.live('sysinfo').then(function (d) { try { sessionStorage.setItem('sysperf.sysinfo', JSON.stringify({ t: Date.now(), d: d })); } catch (e) {} render(d); }).catch(function () {});
	  };
	  SP.live = function (action, params) { return SP.api(action, params, CFG.live || 'SysPerf.UI.LiveData.cls'); };
	  SP.pmapi = function (action, params) { return SP.api(action, params, CFG.pm || 'SysPerf.UI.PMData.cls'); };

	  document.addEventListener('DOMContentLoaded', SP.initTheme);
	})();
}

}
