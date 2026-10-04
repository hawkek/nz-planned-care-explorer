/* NZ Planned Care Explorer front end.
 *
 * Every number shown is computed by the R pipeline (run_pipeline.R) and read
 * from site/data/*.json. This file only lays out controls, charts and tables.
 * Charts use Observable Plot (vendored in assets/, ISC licence).
 */
(function () {
  "use strict";

  const OFFSET = (document.querySelector('meta[name="quarto:offset"]') || {}).content || "./";
  const dataUrl = (f) => `${OFFSET}data/${f}`;
  const cache = {};
  const load = (f) => (cache[f] = cache[f] || fetch(dataUrl(f)).then((r) => {
    if (!r.ok) throw new Error(`Could not load ${f}`);
    return r.json();
  }));

  // ---- Formatting -----------------------------------------------------------

  const nf = new Intl.NumberFormat("en-NZ", { maximumFractionDigits: 0 });
  const fmtInt = (x) => (x == null || Number.isNaN(x) ? "unknown" : nf.format(Math.round(x)));
  const fmtRange = (lo, hi) => (lo == null ? "unknown" : lo === hi ? fmtInt(lo) : `${fmtInt(lo)} to ${fmtInt(hi)}`);
  const fmtPct = (p, d = 0) => (p == null ? "unknown" : `${(100 * p).toFixed(d)}%`);
  const fmtPctRange = (lo, hi, d = 0) => {
    const a = fmtPct(lo, d), b = fmtPct(hi, d);
    return a === b ? a : `${a} to ${b}`;
  };
  // Headline figure: exact when known, rounded when a few suppressed cells
  // make it a narrow range.
  function headline(lo, hi) {
    if (lo === hi) return fmtInt(lo);
    const mid = (lo + hi) / 2;
    if ((hi - lo) / Math.max(mid, 1) <= 0.05 && mid >= 1000) {
      // Same rule as fmt_count_range() in R/text.R: nearest 100 from 10,000,
      // nearest 10 below. The exact range is in the data tables.
      const step = mid >= 10000 ? 100 : 10;
      return `about ${fmtInt(Math.round(mid / step) * step)}`;
    }
    return fmtRange(lo, hi);
  }
  // Same rule as fmt_change() in R/text.R.
  function fmtChange(a, b) {
    const mid = (a + b) / 2;
    if (a === b) return fmtInt(a);
    if ((b - a) / Math.max(mid, 1) <= 0.05 && mid >= 100) return `about ${fmtInt(Math.round(mid / 10) * 10)}`;
    return fmtRange(a, b);
  }
  const parseMonth = (m) => new Date(Date.UTC(+m.slice(0, 4), +m.slice(5, 7) - 1, 1));
  const monthLabel = (d) => d.toLocaleDateString("en-NZ", { month: "long", year: "numeric", timeZone: "UTC" });
  const monthShort = (d) => d.toLocaleDateString("en-NZ", { month: "short", year: "numeric", timeZone: "UTC" });
  const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  const defLink = (code) => `${OFFSET}methods.html#${code.toLowerCase()}`;
  const DISPLAY = { ESPI1: "ESPI 1", ESPI2: "ESPI 2", ESPI3: "ESPI 3", ESPI5: "ESPI 5", ESPI8: "ESPI 8" };

  // ---- DOM helpers ----------------------------------------------------------

  function el(tag, attrs = {}, ...children) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null) continue;
      if (k === "class") e.className = v;
      else if (k === "html") e.innerHTML = v;
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v);
    }
    for (const c of children.flat()) if (c != null) e.append(c.nodeType ? c : document.createTextNode(c));
    return e;
  }

  function hashState() {
    return new URLSearchParams(location.hash.slice(1));
  }
  function setHash(key, value) {
    const s = hashState();
    s.set(key, value);
    history.replaceState(null, "", `#${s.toString()}`);
  }

  function selectControl(label, options, value, onChange) {
    const sel = el("select", { onchange: (e) => onChange(e.target.value) },
      options.map((o) => el("option", { value: o, ...(o === value ? { selected: "" } : {}) }, o)));
    return el("label", {}, label, sel);
  }

  function segmented(label, options, value, onChange) {
    const wrap = el("div", { class: "seg", role: "group", "aria-label": label });
    for (const [key, text] of options) {
      const b = el("button", { type: "button", "aria-pressed": String(key === value) }, text);
      b.addEventListener("click", () => {
        wrap.querySelectorAll("button").forEach((x) => x.setAttribute("aria-pressed", "false"));
        b.setAttribute("aria-pressed", "true");
        onChange(key);
      });
      wrap.append(b);
    }
    return el("label", {}, label, wrap);
  }

  function dataTable(columns, rows, caption) {
    const thead = el("thead", {}, el("tr", {}, columns.map((c) => el("th", { scope: "col" }, c.label))));
    const tbody = el("tbody", {}, rows.map((r) => el("tr", {}, columns.map((c) => el("td", {}, c.value(r))))));
    return el("details", { class: "data-table" },
      el("summary", {}, caption || "Show the data behind this chart"),
      el("div", { class: "table-wrap" }, el("table", {}, thead, tbody)));
  }

  function legend(items) {
    return el("div", { class: "legend", "aria-hidden": "true" }, items.map(([kind, color, text, cls]) =>
      el("span", { class: cls || null }, el("span", { class: `key ${kind}`, style: kind === "band" || kind === "dot" ? `background:${color}` : `border-color:${color}` }), text)));
  }

  // A card: takeaway sentence, optional subtitle, responsive chart, legend, table.
  function card({ takeaway, sub, draw, legendItems, table, alt, primary }) {
    const chart = el("div", { class: "chart", role: "img", "aria-label": alt || takeaway });
    const c = el("section", { class: primary ? "card-viz primary" : "card-viz" },
      takeaway ? el("p", { class: "takeaway" }, takeaway) : null,
      sub ? el("p", { class: "chart-sub", html: sub }) : null,
      chart,
      legendItems ? legend(legendItems) : null,
      table || null);
    let lastW = 0;
    const render = () => {
      const w = Math.floor(chart.clientWidth);
      if (!w || w === lastW) return;
      lastW = w;
      chart.replaceChildren();
      try {
        const svg = draw(w);
        svg.setAttribute("aria-hidden", "true");
        chart.append(svg);
      } catch (err) {
        chart.append(el("p", {}, "This chart could not be drawn. The data table below has the same numbers."));
        console.error(err);
      }
    };
    new ResizeObserver(render).observe(chart);
    requestAnimationFrame(render);
    return c;
  }

  function errorBox(target, err) {
    target.replaceChildren(el("p", { class: "caveat" }, `Sorry, the data could not be loaded (${err.message}).`));
  }

  // ---- Chart builders -------------------------------------------------------

  const plotStyle = () => ({ background: "transparent", color: css("--text-secondary"), fontSize: "12px", overflow: "visible" });
  const chartHeight = (w, big) => (big ? (w < 480 ? 315 : 380) : (w < 480 ? 260 : 290));
  const labelWidth = (labels) => Math.max(0, ...labels.map((t) => String(t).length)) * 6.6 + 12;

  // Line chart with optional comparison lines, target rule and direct labels
  // at the right-hand end, so lines are identified by label and line style as
  // well as colour.
  function lineChart(w, { series, isPct, trend, annotations, yLabel, projection, fitted, targetLine, compare, label, big }) {
    const s1 = css("--series-1"), ink = css("--text-primary"), muted = css("--text-muted"), accent = css("--accent");
    // Missing values (e.g. a district that did not report) become gaps, never zero.
    const val = (d) => {
      const a = isPct ? d.plo : d.nlo, b = isPct ? d.phi : d.nhi;
      return a == null || b == null ? NaN : (a + b) / 2;
    };
    const lo = (d) => (isPct ? d.plo : d.nlo);
    const hi = (d) => (isPct ? d.phi : d.nhi);
    const marks = [];
    const t0 = series[0].date, t1 = series[series.length - 1].date;
    for (const a of (annotations || []).filter((a) => new Date(a.end) >= t0 && new Date(a.start) <= t1)) {
      marks.push(Plot.rect([a], { x1: (d) => new Date(d.start), x2: (d) => new Date(d.end), fill: css("--annotation") }));
    }
    if (trend) {
      marks.push(Plot.areaY(series, { x: "date", y1: "flo", y2: "fhi", fill: css("--uncertainty") }));
      marks.push(Plot.lineY(series, { x: "date", y: "fit", stroke: css("--trend"), strokeWidth: 1.25 }));
    }
    if (projection) {
      marks.push(Plot.areaY(projection, { x: "date", y1: "lo", y2: "hi", fill: s1, fillOpacity: 0.12 }));
      marks.push(Plot.lineY(projection, { x: "date", y: "fit", stroke: s1, strokeWidth: 2, strokeDasharray: "5,4" }));
    }
    if (fitted) marks.push(Plot.lineY(fitted, { x: "date", y: "fit", stroke: muted, strokeWidth: 1.5 }));
    // Comparison series (same units only): drawn underneath, in muted ink.
    const endLabels = [];
    for (const c of compare || []) {
      marks.push(Plot.lineY(c.series, { x: "date", y: val, stroke: c.stroke || css("--series-2"), strokeWidth: 1.5 }));
      const cl = c.series.filter((d) => !Number.isNaN(val(d))).pop();
      if (cl) endLabels.push({ date: cl.date, y: val(cl), text: c.label, fill: css("--text-secondary") });
    }
    marks.push(Plot.areaY(series, { x: "date", y1: lo, y2: hi, fill: s1, fillOpacity: 0.25 }));
    marks.push(Plot.lineY(series, { x: "date", y: val, stroke: s1, strokeWidth: 2.25, strokeLinejoin: "round", strokeLinecap: "round" }));
    marks.push(Plot.ruleY([0], { stroke: css("--axis") }));
    if (targetLine != null) {
      marks.push(Plot.ruleY([targetLine], { stroke: accent, strokeWidth: 1.5, strokeDasharray: "5,4" }));
      endLabels.push({ date: series[series.length - 1].date, y: targetLine, text: `Target ${Math.round(targetLine * 100)}%`, fill: css("--text-secondary") });
    }
    const last = series.filter((d) => !Number.isNaN(val(d))).pop();
    if (last) marks.push(Plot.dot([last], { x: "date", y: val, r: 4, fill: s1, stroke: css("--surface-1"), strokeWidth: 2 }));
    if (last && label) endLabels.push({ date: last.date, y: val(last), text: label, fill: ink, weight: 600 });
    // Nudge end labels apart vertically so they do not overlap.
    const h = chartHeight(w, big);
    const yMax = isPct ? 1 : Math.max(...series.map((d) => (Number.isNaN(val(d)) ? 0 : hi(d) || 0)), ...(compare || []).flatMap((c) => c.series.map((d) => (Number.isNaN(val(d)) ? 0 : val(d)))), targetLine || 0);
    const minGap = (14 / Math.max(1, h - 50)) * yMax;
    endLabels.sort((a, b) => b.y - a.y).forEach((l, i, arr) => { l.ly = i === 0 ? l.y : Math.min(l.y, arr[i - 1].ly - minGap); });
    const marginRight = endLabels.length ? Math.min(w * 0.38, labelWidth(endLabels.map((l) => l.text)) * (w < 480 ? 0.92 : 1)) : 16;
    for (const l of endLabels) {
      marks.push(Plot.text([l], { x: "date", y: "ly", text: "text", dx: 6, textAnchor: "start", fill: l.fill, fontWeight: l.weight || 400, fontSize: w < 480 ? 11 : 12 }));
    }
    marks.push(Plot.ruleX(series, Plot.pointerX({ x: "date", stroke: css("--axis") })));
    const cmpAt = (d) => (compare || []).map((c) => {
      const r = c.series.find((x) => x.date.getTime() === d.date.getTime());
      return r && !Number.isNaN(val(r)) ? `\n${c.label}: ${isPct ? fmtPctRange(r.plo, r.phi, 1) : fmtRange(r.nlo, r.nhi)}` : "";
    }).join("");
    marks.push(Plot.tip(series, Plot.pointerX({
      x: "date", y: val,
      title: (d) => `${monthLabel(d.date)}\n${Number.isNaN(val(d)) ? "Not reported" : isPct ? fmtPctRange(d.plo, d.phi, 1) : fmtRange(d.nlo, d.nhi) + " patients"}` +
        (d.fit != null ? `\nSmoothed trend: ${fmtInt(d.fit)}` : "") + cmpAt(d),
    })));
    return Plot.plot({
      width: w, height: h, marginLeft: isPct ? 44 : 56, marginRight, style: plotStyle(),
      // Explicit year intervals so narrow screens do not crowd the axis.
      x: { type: "utc", label: null, ticks: d3.utcYear.every(w < 480 ? 4 : 2) },
      y: { label: yLabel, grid: true, zero: true, domain: isPct ? [0, 1] : undefined, tickFormat: isPct ? (d) => `${Math.round(d * 100)}%` : "~s" },
      marks,
    });
  }

  function barChart(w, rows, { label, lo, hi, isPct, tip, target, xmax, highlight }) {
    const s1 = css("--series-1");
    const bar = Math.min(24, 18);
    const height = Math.max(120, rows.length * (bar + 10) + 40);
    const longest = Math.max(...rows.map((r) => String(r[label]).length));
    const marginLeft = Math.min(w * 0.45, 8 + longest * 6.6);
    // On narrow screens long names are shortened; the tooltip and the data
    // table keep the full name.
    const maxChars = Math.floor((marginLeft - 8) / 6.6);
    const short = (t) => (t.length > maxChars ? `${t.slice(0, maxChars - 1)}\u2026` : t);
    const order = rows.map((r) => r[label]);
    return Plot.plot({
      width: w, height, marginLeft, marginRight: 56, style: plotStyle(),
      x: { grid: true, label: null, domain: xmax ? [0, xmax] : undefined, tickFormat: isPct ? (d) => `${Math.round(d * 100)}%` : "~s", ticks: w < 480 ? 3 : 6 },
      y: { domain: order, label: null, tickSize: 0, padding: 0.35, tickFormat: short },
      marks: [
        // The selected area keeps full colour; others are lighter, so it stands out.
        Plot.barX(rows, { y: label, x: lo, fill: s1, fillOpacity: (r) => (!highlight || highlight === "New Zealand" || r[label] === highlight ? 1 : 0.55), rx: 4, insetTop: 0, insetBottom: 0 }),
        Plot.barX(rows, { y: label, x1: lo, x2: hi, fill: s1, fillOpacity: 0.35 }),
        Plot.text(rows, {
          y: label, x: hi, dx: 6, textAnchor: "start", fill: css("--text-secondary"),
          text: (r) => (isPct ? fmtPctRange(r[lo], r[hi]) : fmtRange(r[lo], r[hi])),
        }),
        Plot.ruleX([0], { stroke: css("--axis") }),
        ...(target != null ? [Plot.ruleX([target], { stroke: css("--accent"), strokeWidth: 1.5, strokeDasharray: "5,4" })] : []),
        Plot.tip(rows, Plot.pointerY({ y: label, x: hi, title: tip })),
      ],
    });
  }

  // ---- Shared pieces --------------------------------------------------------

  function withDates(rows) {
    return rows.map((r) => ({ ...r, date: parseMonth(r.m) }));
  }

  function yearEarlier(series) {
    const last = series[series.length - 1];
    const target = new Date(Date.UTC(last.date.getUTCFullYear() - 1, last.date.getUTCMonth(), 1)).getTime();
    return series.find((d) => d.date.getTime() === target);
  }

  // Same neutral wording for rises and falls.
  function diffText(now, then, suffix) {
    const chLo = now.nlo - then.nhi, chHi = now.nhi - then.nlo;
    if (chLo > 0) return `${fmtChange(chLo, chHi)} more than ${suffix}`;
    if (chHi < 0) return `${fmtChange(-chHi, -chLo)} fewer than ${suffix}`;
    return `about the same as ${suffix}`;
  }

  function changeText(now, prev, isPct) {
    if (!prev) return "";
    if (isPct) return now.plo == null ? "Not reported this month" : `${fmtPctRange(prev.plo, prev.phi)} a year earlier`;
    return diffText(now, prev, "a year earlier");
  }

  // Change since the first month of the series (January 2019), with the
  // relative change when it is meaningful.
  function sinceStartText(series) {
    const first = series[0], now = series[series.length - 1];
    const base = (first.nlo + first.nhi) / 2, cur = (now.nlo + now.nhi) / 2;
    const rel = base >= 500 ? `, ${(cur / base).toFixed(1)} times that level` : "";
    return `${diffText(now, first, `in ${monthLabel(first.date)}`)}${rel}`;
  }

  function tile(meta, code, series, rank) {
    const ind = meta.indicators.find((i) => i.indicator === code);
    const isPct = code === "ESPI1" || code === "ESPI8";
    const now = series[series.length - 1];
    return el("div", { class: "tile" },
      el("p", { class: "label" }, `${ind.short_name} (${DISPLAY[code]}), ${monthLabel(now.date)}`),
      el("a", { class: "value", href: defLink(code), title: "What this number means" },
        isPct ? (now.plo == null ? "not reported" : fmtPctRange(now.plo, now.phi)) : headline(now.nlo, now.nhi)),
      el("p", { class: "delta" }, changeText(now, yearEarlier(series), isPct)),
      isPct ? null : el("p", { class: "delta" }, sinceStartText(series)),
      rank ? el("p", { class: "delta" },
        el("a", { href: `${OFFSET}index.html#comparison`, title: "How districts compare" },
          `${ordinal(rank.rank)} smallest share of ${rank.of} districts`),
        ` (${fmtPctRange(now.plo, now.phi)} of the list)`) : null);
  }

  function ordinal(n) {
    const s = ["th", "st", "nd", "rd"], v = n % 100;
    return n + (s[(v - 20) % 10] || s[v] || s[0]);
  }

  function seriesTable(series, isPct, code) {
    const cols = [{ label: "Month", value: (r) => monthShort(r.date) }];
    if (isPct) {
      cols.push({ label: code === "ESPI1" ? "Services meeting expectation" : "Prioritised with national tools", value: (r) => fmtPctRange(r.plo, r.phi, 1) });
      cols.push({ label: code === "ESPI1" ? "Services" : "Patients treated", value: (r) => fmtRange(r.dlo, r.dhi) });
    } else {
      cols.push({ label: "Patients", value: (r) => fmtRange(r.nlo, r.nhi) });
      cols.push({ label: "Share of list", value: (r) => fmtPctRange(r.plo, r.phi, 1) });
      if (series[0] && series[0].fit != null) cols.push({ label: "Smoothed trend", value: (r) => fmtInt(r.fit) });
    }
    return dataTable(cols, series.slice().reverse());
  }

  function indicatorCard(meta, code, block, opts = {}) {
    const ind = meta.indicators.find((i) => i.indicator === code);
    const isPct = code === "ESPI1" || code === "ESPI8";
    const series = withDates(block.series);
    const hasTrend = series[0] && series[0].fit != null;
    const items = [["", css("--series-1"), isPct ? "Monthly percentage" : "Monthly count"]];
    if (!isPct && series.some((d) => d.nlo !== d.nhi)) items.push(["band", css("--wash"), "Range from suppressed small counts"]);
    if (hasTrend) items.push(["", css("--text-muted"), "Smoothed trend with 95% interval"]);
    const inRange = (opts.annotations || []).filter((a) => new Date(a.start) <= series[series.length - 1].date);
    if (inRange.length) items.push(["band", css("--annotation"), inRange.map((a) => `${a.label} (${monthShort(new Date(a.start))})`).join("; ")]);
    return card({
      takeaway: block.takeaway,
      sub: `<a href="${defLink(code)}">${DISPLAY[code]}: ${ind.name}</a>`,
      draw: (w) => lineChart(w, { series, isPct, trend: hasTrend, annotations: opts.annotations, yLabel: isPct ? (code === "ESPI1" ? "% of services" : "% of patients") : "Patients" }),
      legendItems: items,
      table: seriesTable(series, isPct, code),
    });
  }

  // ---- Pages ----------------------------------------------------------------

  let META = null;
  const MEASURES = [["FSA", "First specialist assessment"], ["Treatment", "Planned treatment"]];
  const MEASURE_FILE = { FSA: "explore_fsa.json", Treatment: "explore_treatment.json" };
  const MEASURE_NOUN = { FSA: "a first specialist assessment", Treatment: "planned treatment" };

  // Rows for one explorer series. Months with no data are omitted from tables
  // and become gaps in charts, never zeros.
  function explorerRows(ex, key) {
    const s = ex.series[key];
    if (!s) return [];
    return ex.months.map((m, i) => {
      if (s.o[i] == null) return { m, date: parseMonth(m), nlo: null, nhi: null, plo: null, phi: null };
      const nlo = s.o[i], nhi = s.o[i] + s.od[i], tlo = s.t[i], thi = s.t[i] + s.td[i];
      const plo = thi > 0 ? nlo / thi : null, phi = tlo > 0 ? Math.min(1, nhi / tlo) : null;
      return {
        m, date: parseMonth(m), nlo, nhi, tlo, thi, plo, phi,
        // Share waiting under four months (the health target measure).
        ulo: phi == null ? null : 1 - phi, uhi: plo == null ? null : 1 - plo,
      };
    });
  }

  const latestRow = (rows) => rows.filter((r) => r.nlo != null).pop();
  const cap = (t) => t.charAt(0).toUpperCase() + t.slice(1);
  // Change with an arrow and words, never colour: "↓ about 7,900 (11%) since June 2025".
  function changeArrow(now, then, when, short) {
    const a = (now.nlo + now.nhi) / 2, b = (then.nlo + then.nhi) / 2;
    const chLo = now.nlo - then.nhi, chHi = now.nhi - then.nlo;
    if (chLo <= 0 && chHi >= 0) return short ? "about the same" : `About the same as ${when}`;
    const up = chLo > 0;
    const size = up ? fmtChange(chLo, chHi) : fmtChange(-chHi, -chLo);
    const pct = b >= 20 ? ` (${Math.round(Math.abs(a - b) / b * 100)}%)` : "";
    return short ? `${up ? "↑" : "↓"} ${size}${b >= 500 ? `, ${(a / b).toFixed(1)}×` : ""}` : `${up ? "↑" : "↓"} ${size}${pct} ${up ? "more" : "fewer"} than ${when}`;
  }
  // Only annotations that fall inside the data shown get a legend entry.
  const annIn = (ann, months) => ann.filter((a) => new Date(a.start) <= parseMonth(months[months.length - 1]) && new Date(a.end) >= parseMonth(months[0]));
  const annLegend = (ann) => (ann.length ? [["band", css("--annotation"), `Shaded: ${ann.map((a) => a.label.replace(/^COVID-19 /, "")).join("; ")} (COVID-19)`, "long"]] : []);
  const midP = (r) => (r.plo + r.phi) / 2;

  function rankOf(ex, area, spec) {
    const latest = ex.months.length - 1;
    const shares = ex.areas.filter((a) => a !== "New Zealand").map((a) => {
      const r = explorerRows(ex, `${a}|${spec}`)[latest];
      return r && r.plo != null ? { a, p: midP(r) } : null;
    }).filter(Boolean).sort((x, y) => x.p - y.p);
    const i = shares.findIndex((x) => x.a === area);
    return i < 0 ? null : { rank: i + 1, of: shares.length };
  }

  function downloadCsv(filename, columns, rows) {
    const esc = (v) => (v == null ? "" : /[",\n]/.test(String(v)) ? `"${String(v).replace(/"/g, '""')}"` : String(v));
    const text = [columns.map((c) => c.label).join(","), ...rows.map((r) => columns.map((c) => esc(c.raw(r))).join(","))].join("\n");
    const a = el("a", { href: URL.createObjectURL(new Blob([text], { type: "text/csv" })), download: filename });
    document.body.append(a); a.click(); a.remove();
  }

  async function pageHome() {
    const [meta, findings, fsa, tx] = await Promise.all([load("meta.json"), load("findings.json"), load(MEASURE_FILE.FSA), load(MEASURE_FILE.Treatment)]);
    const ex = { FSA: fsa, Treatment: tx };
    META = meta;
    const ann = annIn(meta.annotations.filter((a) => a.scope === "National"), fsa.months);
    const f = document.getElementById("findings");
    if (f) renderFindings(f, findings, ex, ann);
    const e = document.getElementById("explorer");
    if (e) renderExplorer(e, meta, ex, ann);
    const c = document.getElementById("comparison");
    if (c) renderComparison(c, await load("funnel_extract.json"));
  }

  function renderFindings(root, findings, ex, ann) {
    const vintage = (s) => s.replace(/^(\d{4})-(\d{2})-(Q\d)$/, "$1/$2 $3");
    root.replaceChildren(el("p", { class: "meta-line" },
      `Source: Health NZ waitlist extract ${vintage(META.extract.latest_vintage)}. Counts of 1 to 4 are suppressed by Health NZ, so some totals are ranges. `,
      el("a", { href: `${OFFSET}methods.html#measures` }, "Definitions and methods")), ...findings.map((fd, i) => {
      const head = el("h3", { class: "finding-title" }, el("span", { class: "finding-num" }, `${i + 1}`), fd.title);
      if (fd.bars) {
        const bars = fd.bars.map((b) => ({ ...b }));
        return el("div", { class: "finding" }, head, card({
          takeaway: fd.text,
          draw: (w) => barChart(w, bars, { label: "d", lo: "ulo", hi: "uhi", isPct: true, target: 0.95, xmax: 1,
            tip: (r) => `${r.d}\n${fmtPctRange(r.ulo, r.uhi, 1)} waiting under four months` }),
          legendItems: [["band", css("--series-1"), "Share waiting under four months"], ["dash", css("--accent"), "Health target: 95% by 2030"]],
          table: dataTable([{ label: "District", value: (r) => r.d }, { label: "Waiting under four months", value: (r) => fmtPctRange(r.ulo, r.uhi, 1) }], bars),
        }));
      }
      const x = ex[fd.measure];
      const rows = explorerRows(x, fd.series).map((r, j) => ({ ...r, fit: x.trend.fit[j], flo: x.trend.lo[j], fhi: x.trend.hi[j] }));
      return el("div", { class: "finding" }, head, card({
        takeaway: fd.text,
        draw: (w) => lineChart(w, { series: rows, trend: true, annotations: ann, yLabel: "People waiting over 4 months", label: "New Zealand" }),
        legendItems: [["", css("--series-1"), "Waiting more than four months"], ["", css("--text-muted"), "Smoothed trend with 95% interval"], ...annLegend(ann)],
        table: dataTable([{ label: "Month", value: (r) => monthShort(r.date) }, { label: "Waiting over 4 months", value: (r) => fmtRange(r.nlo, r.nhi) }], rows.filter((r) => r.nlo != null).reverse()),
      }));
    }));
  }

  function renderExplorer(root, meta, ex, ann) {
    const h = hashState();
    let measure = h.get("measure") === "Treatment" ? "Treatment" : "FSA";
    let area = h.get("area") || "New Zealand";
    let spec = h.get("specialty") || "All";
    let barMode = "count";
    let compareWith = h.get("compare") || "";
    const controls = el("div", { class: "controls controls-sticky" });
    const body = el("div");
    root.replaceChildren(controls, body);

    function drawControls() {
      const x = ex[measure];
      if (!x.areas.includes(area)) area = "New Zealand";
      if (spec !== "All" && !x.specialties.includes(spec)) spec = "All";
      controls.replaceChildren(
        segmented("Waiting for", MEASURES, measure, (v) => { measure = v; setHash("measure", v); drawControls(); draw(); }),
        selectControl("Area", x.areas, area, (v) => { area = v; setHash("area", v); draw(); }),
        selectControl("Specialty", ["All specialties", ...x.specialties], spec === "All" ? "All specialties" : spec,
          (v) => { spec = v === "All specialties" ? "All" : v; setHash("specialty", spec); draw(); }),
        selectControl("Compare with", ["No comparison", ...x.areas], compareWith || "No comparison",
          (v) => { compareWith = v === "No comparison" ? "" : v; setHash("compare", compareWith); draw(); }));
    }

    function draw() {
      const x = ex[measure];
      const key = `${area}|${spec}`;
      const rows = explorerRows(x, key);
      const now = latestRow(rows);
      const where = `${spec === "All" ? "" : `${spec}, `}${area}`;
      if (!now) {
        body.replaceChildren(el("p", { class: "caveat" }, `No ${MEASURES.find((m) => m[0] === measure)[1].toLowerCase()} waitlist is reported for ${where}.`));
        return;
      }
      const i19 = x.months.indexOf("2019-01");
      const r19 = i19 >= 0 ? rows[i19] : null;
      const prev = yearEarlier(rows.filter((r) => r.nlo != null));
      const rank = area !== "New Zealand" ? rankOf(x, area, spec) : null;
      // 1. The question, 2. the answer, 3. supporting figures.
      // The selection, spelled out above the result so nobody has to read it
      // back from the controls.
      const listName = MEASURES.find((m) => m[0] === measure)[1];
      const question = el("p", { class: "ex-question", "aria-live": "polite" },
        ...[area, listName, spec === "All" ? "All specialties" : spec].flatMap((t, k) => (k ? [el("span", { class: "sep", "aria-hidden": "true" }, " · "), el("span", { class: "part" }, t)] : [el("span", { class: "part" }, t)])),
        cmpArea0() ? el("span", { class: "ex-compare" }, ` compared with ${cmpArea0()}`) : null);
      const answer = el("h2", { class: "ex-answer" },
        el("a", { class: "num", href: `${OFFSET}methods.html#measures`, title: "What this number means" }, cap(headline(now.nlo, now.nhi))),
        el("span", { class: "rest" }, ` people had waited more than four months in ${monthLabel(now.date)}`));
      const delta = el("p", { class: "ex-delta" }, prev ? changeArrow(now, prev, `${monthLabel(prev.date)}`) : "",
        now.nlo !== now.nhi ? ` · exact range ${fmtRange(now.nlo, now.nhi)}` : "");
      const peak = rows.filter((r) => r.nlo != null).reduce((a, r) => (r.nlo + r.nhi > a.nlo + a.nhi ? r : a));
      const stat = (label, val, sub) => el("div", {}, el("p", { class: "label" }, label), el("p", { class: "val" }, val), sub ? el("p", { class: "sub" }, sub) : null);
      const stats = el("div", { class: "stats-secondary" },
        stat("Waiting less than four months", now.ulo == null ? "unknown" : fmtPctRange(now.ulo, now.uhi),
          el("span", {}, `of ${headline(now.tlo, now.thi)} waiting · `, el("a", { href: `${OFFSET}methods.html#health-targets` }, "target 95%"))),
        stat("Since January 2019", r19 && r19.nlo != null ? changeArrow(now, r19, "", true) : "not reported",
          r19 && r19.nlo != null ? `${fmtRange(r19.nlo, r19.nhi)} in January 2019` : null),
        stat("Highest month", headline(peak.nlo, peak.nhi), monthLabel(peak.date)),
        rank ? stat(`Rank among districts${spec === "All" ? "" : ` (${spec})`}`, `${ordinal(rank.rank)} of ${rank.of}`, "1 = smallest share waiting over four months") : null);

      function cmpArea0() { return compareWith && compareWith !== area ? compareWith : ""; }
      const isNZAll = key === "New Zealand|All";
      const cmpArea = compareWith && compareWith !== area ? compareWith : "";
      const cmpRows = cmpArea ? explorerRows(x, `${cmpArea}|${spec}`) : [];
      const cmpPct = cmpRows.map((r) => ({ ...r, nlo: null, nhi: null, plo: r.ulo, phi: r.uhi }));
      const cmpLabel = `${cmpArea}${spec === "All" ? "" : `, ${spec}`}`;
      const trendRows = rows.map((r, j) => (isNZAll ? { ...r, fit: x.trend.fit[j], flo: x.trend.lo[j], fhi: x.trend.hi[j] } : r));
      const countCard = card({
        takeaway: "",
        sub: "Monthly trend",
        primary: true,
        draw: (w) => lineChart(w, { series: trendRows, trend: isNZAll, annotations: ann, yLabel: "People", label: area, big: true }),
        legendItems: [["", css("--series-1"), "Waited more than four months"], ...(isNZAll ? [["", css("--text-muted"), "Smoothed trend with 95% interval"]] : []), ...annLegend(ann)],
        table: null,
      });
      const pctRows = rows.map((r) => ({ ...r, nlo: null, nhi: null, plo: r.ulo, phi: r.uhi }));
      const hasCmp = cmpPct.some((r) => r.plo != null);
      const pctCard = card({
        takeaway: `Share waiting under four months${hasCmp ? `, compared with ${cmpLabel}` : ""}`,
        sub: cmpArea && !hasCmp ? `${cmpLabel} has no data for this list.` : null,
        draw: (w) => lineChart(w, { series: pctRows, isPct: true, annotations: ann, yLabel: "Waiting under 4 months", targetLine: 0.95, label: area,
          compare: hasCmp ? [{ series: cmpPct, label: cmpArea }] : [] }),
        legendItems: [["", css("--series-1"), where], ...(hasCmp ? [["thin", css("--series-2"), cmpLabel]] : []), ["dash", css("--accent"), "Health target: 95% by 2030"]],
      });

      const tableCols = [
        { label: "Month", value: (r) => monthShort(r.date), raw: (r) => r.m },
        { label: "Waited over 4 months", value: (r) => fmtRange(r.nlo, r.nhi), raw: (r) => (r.nlo === r.nhi ? r.nlo : `${r.nlo}-${r.nhi}`) },
        { label: "Total waiting", value: (r) => fmtRange(r.tlo, r.thi), raw: (r) => (r.tlo === r.thi ? r.tlo : `${r.tlo}-${r.thi}`) },
        { label: "Under 4 months", value: (r) => fmtPctRange(r.ulo, r.uhi, 1), raw: (r) => (r.ulo == null ? "" : `${(100 * r.ulo).toFixed(1)}-${(100 * r.uhi).toFixed(1)}`) },
      ];
      const shown = rows.filter((r) => r.nlo != null).reverse();
      const tableBlock = el("div", {},
        dataTable(tableCols, shown, "Show the data for this selection"),
        el("p", {}, el("button", { type: "button", class: "btn-link", onclick: () => downloadCsv(`waitlist_${measure}_${area}_${spec}.csv`.replace(/[^\w.-]+/g, "_"), tableCols, shown) }, "Download this selection (CSV)")));

      const vintage = meta.extract.latest_vintage.replace(/^(\d{4})-(\d{2})-(Q\d)$/, "$1/$2 $3");
      const note = el("p", { class: "meta-line quiet" }, `Source: Health NZ waitlist extract ${vintage}, ${monthLabel(parseMonth(x.months[0]))} to ${monthLabel(parseMonth(x.months[x.months.length - 1]))}. Historical figures may be revised by Health NZ; `,
        el("a", { href: `${OFFSET}methods.html#revisions` }, "see revisions"), ".");
      body.replaceChildren(question, answer, delta, countCard, note, stats, pctCard, tableBlock, breakdown());

      function breakdown() {
        const latest = x.months.length - 1;
        let title, items;
        if (spec === "All" && area !== "New Zealand") {
          title = `Specialties in ${area}`;
          items = x.specialties.map((s) => ({ label: s, r: explorerRows(x, `${area}|${s}`)[latest] }));
        } else {
          title = spec === "All" ? "Districts" : `Districts: ${spec}`;
          items = x.areas.filter((a) => a !== "New Zealand").map((a) => ({ label: a, r: explorerRows(x, `${a}|${spec}`)[latest] }));
        }
        const wrap = el("div");
        const drawBars = () => {
          const isShare = barMode === "share";
          let bars = items.filter((it) => it.r && it.r.nlo != null && (isShare ? it.r.ulo != null : it.r.nhi > 0))
            .map((it) => ({ label: it.label, ...it.r }));
          bars.sort((a, b) => (isShare ? (b.ulo + b.uhi) - (a.ulo + a.uhi) : (b.nlo + b.nhi) - (a.nlo + a.nhi)));
          wrap.replaceChildren(bars.length === 0 ? el("p", {}, "Nothing to show for this selection.") : card({
            takeaway: `${monthLabel(parseMonth(x.months[latest]))}: ${isShare ? "share waiting under four months" : "waited more than four months"}`,
            draw: (w) => barChart(w, bars, {
              label: "label", lo: isShare ? "ulo" : "nlo", hi: isShare ? "uhi" : "nhi", isPct: isShare,
              target: isShare ? 0.95 : null, xmax: isShare ? 1 : null, highlight: area,
              tip: (r) => `${r.label}\n${fmtRange(r.nlo, r.nhi)} waited over 4 months\n${fmtPctRange(r.ulo, r.uhi)} waiting under 4 months`,
            }),
            legendItems: [["band", css("--series-1"), isShare ? "Share under four months" : "People"], ["band", css("--wash"), "Range from suppressed small counts"], ...(isShare ? [["dash", css("--accent"), "Health target: 95%"]] : [])],
            table: dataTable([
              { label: spec === "All" && area !== "New Zealand" ? "Specialty" : "District", value: (r) => r.label },
              { label: "Waited over 4 months", value: (r) => fmtRange(r.nlo, r.nhi) },
              { label: "Total waiting", value: (r) => fmtRange(r.tlo, r.thi) },
              { label: "Under 4 months", value: (r) => fmtPctRange(r.ulo, r.uhi) },
            ], bars),
          }));
        };
        drawBars();
        return el("div", {}, el("h3", {}, title),
          el("div", { class: "controls" }, segmented("Show", [["count", "People"], ["share", "Share under 4 months"]], barMode, (v) => { barMode = v; drawBars(); })),
          wrap);
      }
    }
    drawControls();
    draw();
  }

  function renderComparison(root, fu) {
    let code = "FSA";
    const body = el("div");
    root.replaceChildren(
      el("p", {}, "Each dot is a district. Bigger waiting lists sit further right. If every district had the same underlying share waiting over four months, dots would scatter inside the funnel by chance. Dots outside the outer lines differ by more than chance and the usual variation between districts. This is not adjusted for need, such as age, deprivation or use of private care."),
      el("div", { class: "controls" }, segmented("Waiting for", MEASURES, code, (v) => { code = v; draw(); })),
      body);
    function draw() {
      const f = fu[code];
      const pts = f.points;
      body.replaceChildren(card({
        takeaway: f.takeaway,
        sub: `${monthLabel(parseMonth(f.latest))}. National share waiting over four months ${fmtPct(f.target, 1)}. Limits allow for overdispersion (factor ${Math.round(f.phi)}); see <a href="${OFFSET}methods.html#district-comparison">methods</a>.`,
        draw: (w) => {
          const s1 = css("--series-1"), axis = css("--axis"), muted = css("--text-muted");
          return Plot.plot({
            width: w, height: chartHeight(w) + 40, marginLeft: 48, marginRight: 16, marginBottom: 40, style: plotStyle(),
            x: { type: "log", label: "People on the waiting list (log scale)", tickFormat: "~s", ticks: w < 480 ? 3 : 6 },
            y: { label: "Share waiting over 4 months", grid: true, tickFormat: (d) => `${Math.round(d * 100)}%`, domain: [0, Math.min(1, Math.max(...pts.map((p) => p.y), ...f.limits.map((l) => l.hi998)) * 1.05)] },
            marks: [
              Plot.line(f.limits, { x: "size", y: "lo998", stroke: muted, strokeWidth: 1 }),
              Plot.line(f.limits, { x: "size", y: "hi998", stroke: muted, strokeWidth: 1 }),
              Plot.line(f.limits, { x: "size", y: "lo95", stroke: axis, strokeWidth: 1 }),
              Plot.line(f.limits, { x: "size", y: "hi95", stroke: axis, strokeWidth: 1 }),
              Plot.ruleY([f.target], { stroke: css("--text-secondary"), strokeWidth: 1 }),
              Plot.dot(pts, { x: "size", y: "y", r: 5, fill: (p) => (p.status.includes("99.8") ? s1 : muted), stroke: css("--surface-1"), strokeWidth: 2 }),
              Plot.text(pts.filter((p) => p.status !== "within limits"), { x: "size", y: "y", text: "d", dy: -10, fill: css("--text-primary"), fontSize: 11 }),
              Plot.tip(pts, Plot.pointer({ x: "size", y: "y", title: (p) => `${p.d}\n${fmtPct(p.y, 1)} of ${fmtInt(p.size)} waiting over 4 months\n${p.status}` })),
            ],
          });
        },
        legendItems: [["dot", css("--series-1"), "Outside the 99.8% limits"], ["dot", css("--text-muted"), "Within the 99.8% limits"], ["", css("--text-muted"), "99.8% limits"], ["", css("--axis"), "95% limits"], ["", css("--text-secondary"), "National share"]],
        table: dataTable([
          { label: "District", value: (r) => r.d },
          { label: "On the list", value: (r) => fmtInt(r.size) },
          { label: "Waited over 4 months", value: (r) => fmtRange(r.nlo, r.nhi) },
          { label: "Share", value: (r) => fmtPct(r.y, 1) },
          { label: "Compared with limits", value: (r) => r.status },
        ], pts.slice().sort((a, b) => b.y - a.y)),
      }));
    }
    draw();
  }

  // ESPI 1, 3 and 8 from the OIA release (2019 to 2025).
  async function pageContext(root) {
    const [meta, nat, dd] = await Promise.all([load("meta.json"), load("national.json"), load("districts.json")]);
    const ann = meta.annotations.filter((a) => a.scope === "National");
    const names = ["New Zealand", ...Object.keys(dd.districts)];
    let area = names.includes(hashState().get("area")) ? hashState().get("area") : "New Zealand";
    const body = el("div");
    root.append(el("div", { class: "controls" }, selectControl("Area", names, area, (v) => { area = v; setHash("area", v); draw(); })), body);
    function draw() {
      const src = area === "New Zealand" ? nat : dd.districts[area].indicators;
      body.replaceChildren(...["ESPI1", "ESPI3", "ESPI8"].filter((c) => src[c]).map((c) => indicatorCard(meta, c, src[c], { annotations: ann })));
    }
    draw();
  }

  async function pageTarget(root) {
    const [meta, tg] = await Promise.all([load("meta.json"), load("target.json")]);
    let code = "ESPI2";
    let area = hashState().get("area") || "New Zealand";
    const controls = el("div", { class: "controls" });
    const body = el("div");
    root.append(
      el("p", { class: "caveat" }, "Illustrative only. Real waiting lists change with funding, staffing, strikes, winter illness and policy. A projection is shown only where the last 24 months show a clear fall and enough patients for a stable trend."),
      controls, body);

    function drawControls() {
      const names = Object.keys(tg[code]);
      if (!names.includes(area)) area = "New Zealand";
      controls.replaceChildren(
        segmented("Measure", [["ESPI2", "First assessment"], ["ESPI5", "Treatment"]], code, (v) => { code = v; drawControls(); draw(); }),
        selectControl("Area", names, area, (v) => { area = v; setHash("area", v); draw(); }));
    }

    function yrs(m) {
      if (m == null) return "";
      if (m > 120) return "more than 10 years";
      return m < 24 ? `${Math.round(m)} months` : `${(m / 12).toFixed(1)} years`;
    }

    function draw() {
      const t = tg[code][area];
      const hist = withDates(t.history);
      const fitted = t.fitted ? withDates(t.fitted) : null;
      const path = t.path ? withDates(t.path).filter((d) => d.date <= new Date(Date.UTC(hist[hist.length - 1].date.getUTCFullYear() + 5, 11, 1))) : null;
      const items = [["", css("--series-1"), "Monthly count"]];
      if (fitted) items.push(["", css("--text-muted"), "24-month trend"]);
      if (path) items.push(["dash", css("--series-1"), "If the trend continued (95% interval shaded)"]);
      const statusLabel = { falling: "Falling", rising: "Rising", "no clear trend": "No clear trend", "not shown": "Not shown" };
      body.replaceChildren(card({
        takeaway: t.takeaway,
        sub: `<a href="${defLink(code)}">${DISPLAY[code]}</a>, ${area}. Last 36 months shown.`,
        draw: (w) => lineChart(w, { series: hist, fitted, projection: path, yLabel: "Patients" }),
        legendItems: items,
        table: dataTable([
          { label: "Month", value: (r) => monthShort(r.date) },
          { label: "Patients", value: (r) => (r.nlo != null ? fmtRange(r.nlo, r.nhi) : "") },
          { label: "Trend or projection", value: (r) => (r.fit != null ? fmtInt(r.fit) : "") },
          { label: "95% interval", value: (r) => (r.lo != null ? `${fmtInt(r.lo)} to ${fmtInt(r.hi)}` : "") },
        ], [...hist.map((h) => ({ ...h, fit: (fitted || []).find((f) => f.m === h.m)?.fit })), ...(path || [])].reverse()),
      }),
      el("h2", {}, "All areas"),
      el("div", { class: "table-wrap" }, el("table", {},
        el("thead", {}, el("tr", {}, ["Area", "Last 24 months", "Fewer than one patient in (if trend continued)"].map((h) => el("th", { scope: "col" }, h)))),
        el("tbody", {}, Object.entries(tg[code]).map(([name, v]) => el("tr", {},
          el("td", {}, name),
          el("td", {}, el("span", { class: "status-pill" }, statusLabel[v.status])),
          el("td", {}, v.months ? `${yrs(v.months.mid)} (${yrs(v.months.lo)} to ${yrs(v.months.hi)})` : "")))))));
    }
    drawControls();
    draw();
  }

  async function pageMethods() {
    const meta = await load("meta.json");
    const checks = document.getElementById("checks-table");
    if (checks) {
      checks.replaceChildren(el("table", {},
        el("thead", {}, el("tr", {}, ["Check", "Type", "Result", "Note"].map((h) => el("th", { scope: "col" }, h)))),
        el("tbody", {}, meta.checks.map((c) => el("tr", {},
          el("td", {}, c.check), el("td", {}, c.severity),
          el("td", {}, /^Not applicable/.test(c.detail || "") ? "Not applicable" : c.passed ? "Passed" : `${c.n_failing} rows flagged`),
          el("td", {}, c.detail || ""))))));
    }
    const revs = document.getElementById("revisions-table");
    if (revs) {
      const rows = (meta.extract && meta.extract.revisions) || [];
      const name = (m) => (m === "FSA" ? "First specialist assessment" : "Planned treatment");
      revs.replaceChildren(rows.length === 0 ? el("p", {}, "Only one extract is held, so there is nothing to compare yet.") : el("table", {},
        el("thead", {}, el("tr", {}, ["From", "To", "List", "Months compared", "Average change", "Largest change"].map((h) => el("th", { scope: "col" }, h)))),
        el("tbody", {}, rows.map((r) => el("tr", {},
          el("td", {}, r.from.replace(/^(\d{4})-(\d{2})-(Q\d)$/, "$1/$2 $3")), el("td", {}, r.to.replace(/^(\d{4})-(\d{2})-(Q\d)$/, "$1/$2 $3")),
          el("td", {}, name(r.measure)), el("td", {}, fmtInt(r.months)),
          el("td", {}, `${fmtInt(r.mean_abs)} people`),
          el("td", {}, r.max_abs === 0 ? "none" : `${fmtInt(r.max_abs)} people (${monthShort(parseMonth(r.max_month))})`))))));
    }
    const sources = document.getElementById("sources-table");
    if (sources) {
      sources.replaceChildren(el("table", {},
        el("thead", {}, el("tr", {}, ["Source", "Retrieved", "Months", "Rows"].map((h) => el("th", { scope: "col" }, h)))),
        el("tbody", {}, meta.sources.map((s) => el("tr", {},
          el("td", {}, s.source), el("td", {}, s.retrieved), el("td", {}, `${s.first} to ${s.last}`), el("td", {}, fmtInt(s.rows)))))));
    }
  }

  // ---- Boot -----------------------------------------------------------------

  async function boot() {
    load("meta.json").then((meta) => {
      const v = document.getElementById("data-version");
      if (v) v.textContent = `Waiting lists to ${monthLabel(parseMonth(meta.extract.latest_month))} (extract ${meta.extract.latest_vintage.replace(/^(\d{4})-(\d{2})-(Q\d)$/, "$1/$2 $3")}); version ${meta.data_version}, built ${meta.built}.`;
    }).catch(() => {});
    const pages = { "page-context": pageContext, "page-target": pageTarget };
    for (const [id, fn] of Object.entries(pages)) {
      const root = document.getElementById(id);
      if (root) fn(root).catch((e) => errorBox(root, e));
    }
    if (document.getElementById("explorer")) {
      pageHome().catch((e) => errorBox(document.getElementById("explorer"), e));
    }
    if (document.getElementById("checks-table")) pageMethods().catch(console.error);
  }

  // Redraw charts when the colour scheme changes, so colours follow the theme.
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => location.reload());
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
