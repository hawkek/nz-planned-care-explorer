/* NZ Waitlist Tracker front end.
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
    if ((hi - lo) / Math.max(mid, 1) <= 0.02 && mid >= 1000) {
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
    return el("div", { class: "legend", "aria-hidden": "true" }, items.map(([kind, color, text]) =>
      el("span", {}, el("span", { class: `key ${kind}`, style: kind === "band" || kind === "dot" ? `background:${color}` : `border-color:${color}` }), text)));
  }

  // A card: takeaway sentence, optional subtitle, responsive chart, legend, table.
  function card({ takeaway, sub, draw, legendItems, table, alt }) {
    const chart = el("div", { class: "chart", role: "img", "aria-label": alt || takeaway });
    const c = el("section", { class: "card-viz" },
      el("p", { class: "takeaway" }, takeaway),
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
  const chartHeight = (w) => (w < 480 ? 240 : 300);

  function lineChart(w, { series, isPct, trend, annotations, yLabel, projection, fitted, targetLine }) {
    const s1 = css("--series-1"), ink = css("--text-primary"), muted = css("--text-muted");
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
      marks.push(Plot.areaY(series, { x: "date", y1: "flo", y2: "fhi", fill: muted, fillOpacity: 0.15 }));
      marks.push(Plot.lineY(series, { x: "date", y: "fit", stroke: muted, strokeWidth: 1.5 }));
    }
    if (projection) {
      marks.push(Plot.areaY(projection, { x: "date", y1: "lo", y2: "hi", fill: s1, fillOpacity: 0.12 }));
      marks.push(Plot.lineY(projection, { x: "date", y: "fit", stroke: s1, strokeWidth: 2, strokeDasharray: "5,4" }));
    }
    if (fitted) marks.push(Plot.lineY(fitted, { x: "date", y: "fit", stroke: muted, strokeWidth: 1.5 }));
    marks.push(Plot.areaY(series, { x: "date", y1: lo, y2: hi, fill: s1, fillOpacity: 0.25 }));
    marks.push(Plot.lineY(series, { x: "date", y: val, stroke: s1, strokeWidth: 2, strokeLinejoin: "round", strokeLinecap: "round" }));
    if (targetLine != null) marks.push(Plot.ruleY([targetLine], { stroke: css("--axis") }));
    else marks.push(Plot.ruleY([0], { stroke: css("--axis") }));
    const last = series.filter((d) => !Number.isNaN(val(d))).pop();
    if (last) marks.push(Plot.dot([last], { x: "date", y: val, r: 4, fill: s1, stroke: css("--surface-1"), strokeWidth: 2 }));
    marks.push(Plot.ruleX(series, Plot.pointerX({ x: "date", stroke: css("--axis") })));
    marks.push(Plot.tip(series, Plot.pointerX({
      x: "date", y: val,
      title: (d) => `${monthLabel(d.date)}\n${Number.isNaN(val(d)) ? "Not reported" : isPct ? fmtPctRange(d.plo, d.phi, 1) : fmtRange(d.nlo, d.nhi) + " patients"}` +
        (d.fit != null ? `\nSmoothed trend: ${fmtInt(d.fit)}` : ""),
    })));
    return Plot.plot({
      width: w, height: chartHeight(w), marginLeft: isPct ? 44 : 56, marginRight: 16, style: plotStyle(),
      x: { type: "utc", label: null, ticks: w < 480 ? 4 : 7 },
      y: { label: yLabel, grid: true, zero: true, domain: isPct ? [0, 1] : undefined, tickFormat: isPct ? (d) => `${Math.round(d * 100)}%` : "~s" },
      marks,
    });
  }

  function barChart(w, rows, { label, lo, hi, isPct, tip }) {
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
      x: { grid: true, label: null, tickFormat: isPct ? (d) => `${Math.round(d * 100)}%` : "~s", ticks: w < 480 ? 3 : 6 },
      y: { domain: order, label: null, tickSize: 0, padding: 0.35, tickFormat: short },
      marks: [
        Plot.barX(rows, { y: label, x: lo, fill: s1, rx: 4, insetTop: 0, insetBottom: 0 }),
        Plot.barX(rows, { y: label, x1: lo, x2: hi, fill: s1, fillOpacity: 0.35 }),
        Plot.text(rows, {
          y: label, x: hi, dx: 6, textAnchor: "start", fill: css("--text-secondary"),
          text: (r) => (isPct ? fmtPctRange(r[lo] ?? r.plo, r[hi] ?? r.phi) : fmtRange(r[lo], r[hi])),
        }),
        Plot.ruleX([0], { stroke: css("--axis") }),
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

  function changeText(now, prev, isPct) {
    if (!prev) return "";
    if (isPct) return now.plo == null ? "Not reported this month" : `${fmtPctRange(prev.plo, prev.phi)} a year earlier`;
    const chLo = now.nlo - prev.nhi, chHi = now.nhi - prev.nlo;
    if (chLo > 0) return `${fmtChange(chLo, chHi)} more than a year earlier`;
    if (chHi < 0) return `${fmtChange(-chHi, -chLo)} fewer than a year earlier`;
    return "about the same as a year earlier";
  }

  function tile(meta, code, series) {
    const ind = meta.indicators.find((i) => i.indicator === code);
    const isPct = code === "ESPI1" || code === "ESPI8";
    const now = series[series.length - 1];
    return el("div", { class: "tile" },
      el("p", { class: "label" }, `${ind.short_name} (${DISPLAY[code]}), ${monthLabel(now.date)}`),
      el("a", { class: "value", href: defLink(code), title: "What this number means" },
        isPct ? (now.plo == null ? "not reported" : fmtPctRange(now.plo, now.phi)) : headline(now.nlo, now.nhi)),
      el("p", { class: "delta" }, changeText(now, yearEarlier(series), isPct)));
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

  async function pageNational(root) {
    const [meta, nat] = await Promise.all([load("meta.json"), load("national.json")]);
    const ann = meta.annotations.filter((a) => a.scope === "National");
    const tiles = el("div", { class: "tiles" },
      ["ESPI2", "ESPI5"].map((c) => tile(meta, c, withDates(nat[c].series))));
    root.append(tiles,
      el("h2", {}, "Waiting more than four months"),
      indicatorCard(meta, "ESPI2", nat.ESPI2, { annotations: ann }),
      indicatorCard(meta, "ESPI5", nat.ESPI5, { annotations: ann }),
      el("h2", {}, "Context: referrals, thresholds and prioritisation"),
      el("p", {}, "These help interpret the headline measures. If fewer referrals are accepted, the waitlist can shrink without anyone being seen sooner."),
      indicatorCard(meta, "ESPI1", nat.ESPI1, { annotations: ann }),
      indicatorCard(meta, "ESPI3", nat.ESPI3, { annotations: ann }),
      indicatorCard(meta, "ESPI8", nat.ESPI8, { annotations: ann }));
  }

  async function pageDistrict(root) {
    const [meta, dd] = await Promise.all([load("meta.json"), load("districts.json")]);
    const names = Object.keys(dd.districts);
    let district = names.includes(hashState().get("district")) ? hashState().get("district") : names[0];
    let specInd = "ESPI2";
    const body = el("div");
    const controls = el("div", { class: "controls" },
      selectControl("District", names, district, (v) => { district = v; setHash("district", v); draw(); }));
    root.append(controls, body);

    function draw() {
      const d = dd.districts[district];
      const auck = ["Auckland", "Waitemata", "Counties Manukau"].includes(district);
      const ann = meta.annotations.filter((a) => a.scope === "National" || (auck && a.scope === "Auckland region"));
      const specCard = el("div");
      const drawSpec = () => {
        const block = d.specialties[specInd];
        const rows = block.rows.filter((r) => r.nhi > 0);
        specCard.replaceChildren(rows.length === 0 ? el("p", { class: "takeaway" }, block.takeaway) : card({
          takeaway: block.takeaway,
          sub: `<a href="${defLink(specInd)}">${DISPLAY[specInd]}</a>, ${monthLabel(parseMonth(dd.latest))}. Specialties with none waiting are not shown.`,
          draw: (w) => barChart(w, rows, {
            label: "s", lo: "nlo", hi: "nhi",
            tip: (r) => `${r.s}\n${fmtRange(r.nlo, r.nhi)} patients\n${fmtPctRange(r.plo, r.phi)} of the list` + (r.prevlo != null ? `\nA year earlier: ${fmtRange(r.prevlo, r.prevhi)}` : ""),
          }),
          legendItems: [["band", css("--series-1"), "Patients"], ["band", css("--wash"), "Range where counts of 1 to 4 are suppressed"]],
          table: dataTable([
            { label: "Specialty", value: (r) => r.s },
            { label: "Patients", value: (r) => fmtRange(r.nlo, r.nhi) },
            { label: "Share of list", value: (r) => fmtPctRange(r.plo, r.phi) },
            { label: "A year earlier", value: (r) => (r.prevlo == null ? "not reported" : fmtRange(r.prevlo, r.prevhi)) },
          ], block.rows),
        }));
      };
      drawSpec();
      body.replaceChildren(
        el("div", { class: "tiles" }, ["ESPI2", "ESPI5"].filter((c) => d.indicators[c]).map((c) => tile(meta, c, withDates(d.indicators[c].series)))),
        el("h2", {}, `Trends in ${district}`),
        ...["ESPI2", "ESPI5"].filter((c) => d.indicators[c]).map((c) => indicatorCard(meta, c, d.indicators[c], { annotations: ann })),
        el("h2", {}, `Specialties in ${district}`),
        el("div", { class: "controls" }, segmented("Measure", [["ESPI2", "First assessment"], ["ESPI5", "Treatment"]], specInd, (v) => { specInd = v; drawSpec(); })),
        specCard,
        el("h2", {}, "Referral processing"),
        d.indicators.ESPI1 ? indicatorCard(meta, "ESPI1", d.indicators.ESPI1, { annotations: ann }) : null);
    }
    draw();
  }

  async function pageSpecialty(root) {
    const [meta, sp] = await Promise.all([load("meta.json"), load("specialties.json")]);
    let code = hashState().get("measure") === "ESPI5" ? "ESPI5" : "ESPI2";
    let specialty = hashState().get("specialty");
    let measure = "count";
    const body = el("div");
    const controls = el("div", { class: "controls" });
    root.append(controls, body);

    function drawControls() {
      const names = Object.keys(sp.indicators[code]);
      if (!names.includes(specialty)) specialty = names.includes("Orthopaedics") ? "Orthopaedics" : names[0];
      controls.replaceChildren(
        segmented("Measure", [["ESPI2", "First assessment"], ["ESPI5", "Treatment"]], code, (v) => { code = v; setHash("measure", v); drawControls(); draw(); }),
        selectControl("Specialty", names, specialty, (v) => { specialty = v; setHash("specialty", v); draw(); }),
        segmented("Show", [["count", "Patients"], ["share", "Share of list"]], measure, (v) => { measure = v; draw(); }));
    }

    function draw() {
      const block = sp.indicators[code][specialty];
      const isShare = measure === "share";
      let rows = block.districts.filter((r) => (isShare ? r.plo != null : r.nhi > 0));
      rows = rows.slice().sort((a, b) => (isShare ? (b.plo + b.phi) - (a.plo + a.phi) : (b.nlo + b.nhi) - (a.nlo + a.nhi)));
      const natBlock = { series: block.series, takeaway: block.national_takeaway };
      body.replaceChildren(
        rows.length === 0 ? el("p", { class: "takeaway" }, block.takeaway) : card({
          takeaway: block.takeaway,
          sub: `<a href="${defLink(code)}">${DISPLAY[code]}</a>, ${monthLabel(parseMonth(sp.latest))}. ${isShare ? "Share of each district's waiting list for this specialty." : "Districts with none waiting are not shown."}`,
          draw: (w) => barChart(w, rows, {
            label: "d", lo: isShare ? "plo" : "nlo", hi: isShare ? "phi" : "nhi", isPct: isShare,
            tip: (r) => `${r.d}\n${fmtRange(r.nlo, r.nhi)} patients\n${fmtPctRange(r.plo, r.phi)} of ${fmtRange(r.dlo, r.dhi)} on the list`,
          }),
          legendItems: [["band", css("--series-1"), isShare ? "Share of list" : "Patients"], ["band", css("--wash"), "Range where counts of 1 to 4 are suppressed"]],
          table: dataTable([
            { label: "District", value: (r) => r.d },
            { label: "Patients", value: (r) => fmtRange(r.nlo, r.nhi) },
            { label: "On the list", value: (r) => fmtRange(r.dlo, r.dhi) },
            { label: "Share of list", value: (r) => fmtPctRange(r.plo, r.phi) },
            { label: "A year earlier", value: (r) => (r.prevlo == null ? "not reported" : fmtRange(r.prevlo, r.prevhi)) },
          ], block.districts),
        }),
        el("h2", {}, `${specialty} across New Zealand`),
        indicatorCard(meta, code, natBlock));
    }
    drawControls();
    draw();
  }

  async function pageFair(root) {
    const [meta, fu] = await Promise.all([load("meta.json"), load("funnel.json")]);
    let code = "ESPI2";
    const body = el("div");
    root.append(
      el("p", {}, "Each dot is a district. Bigger waiting lists sit further right. If every district had the same underlying share, dots would scatter inside the funnel by chance; dots outside the outer lines differ by more than chance and the usual variation between districts."),
      el("div", { class: "controls" }, segmented("Measure", [["ESPI2", "First assessment"], ["ESPI5", "Treatment"]], code, (v) => { code = v; draw(); })),
      body);

    function draw() {
      const f = fu[code];
      const pts = f.points;
      const out = pts.filter((p) => p.status !== "within limits");
      body.replaceChildren(card({
        takeaway: f.takeaway,
        sub: `<a href="${defLink(code)}">${DISPLAY[code]}</a>, ${monthLabel(parseMonth(fu.latest))}. National share ${fmtPct(f.target, 1)}. Limits allow for overdispersion (factor ${Math.round(f.phi)}); see <a href="${OFFSET}methods.html#fair-comparisons">methods</a>.`,
        draw: (w) => {
          const s1 = css("--series-1"), axis = css("--axis"), muted = css("--text-muted");
          return Plot.plot({
            width: w, height: chartHeight(w) + 40, marginLeft: 48, marginRight: 16, marginBottom: 40, style: plotStyle(),
            x: { type: "log", label: "Patients on the waiting list (log scale)", tickFormat: "~s", ticks: w < 480 ? 3 : 6 },
            y: { label: "Share waiting over 4 months", grid: true, tickFormat: (d) => `${Math.round(d * 100)}%`, domain: [0, Math.min(1, Math.max(...pts.map((p) => p.y), ...f.limits.map((l) => l.hi998)) * 1.05)] },
            marks: [
              Plot.line(f.limits, { x: "size", y: "lo998", stroke: muted, strokeWidth: 1 }),
              Plot.line(f.limits, { x: "size", y: "hi998", stroke: muted, strokeWidth: 1 }),
              Plot.line(f.limits, { x: "size", y: "lo95", stroke: axis, strokeWidth: 1 }),
              Plot.line(f.limits, { x: "size", y: "hi95", stroke: axis, strokeWidth: 1 }),
              Plot.ruleY([f.target], { stroke: css("--text-secondary"), strokeWidth: 1 }),
              Plot.dot(pts, { x: "size", y: "y", r: 5, fill: (p) => (p.status.includes("99.8") ? s1 : muted), stroke: css("--surface-1"), strokeWidth: 2 }),
              Plot.text(pts.filter((p) => p.status.includes("99.8") || p.status.includes("95")), { x: "size", y: "y", text: "d", dy: -10, fill: css("--text-primary"), fontSize: 11 }),
              Plot.tip(pts, Plot.pointer({ x: "size", y: "y", title: (p) => `${p.d}\n${fmtPct(p.y, 1)} of ${fmtInt(p.size)} waiting over 4 months\n${p.status}` })),
            ],
          });
        },
        legendItems: [["dot", css("--series-1"), "Outside the 99.8% limits"], ["dot", css("--text-muted"), "Within the 99.8% limits"], ["", css("--text-muted"), "99.8% limits"], ["", css("--axis"), "95% limits"], ["", css("--text-secondary"), "National share"]],
        table: dataTable([
          { label: "District", value: (r) => r.d },
          { label: "On the list", value: (r) => fmtInt(r.size) },
          { label: "Waiting over 4 months", value: (r) => fmtRange(r.nlo, r.nhi) },
          { label: "Share", value: (r) => fmtPct(r.y, 1) },
          { label: "Compared with limits", value: (r) => r.status },
        ], pts.slice().sort((a, b) => b.y - a.y)),
      }),
      el("h2", {}, "Rates per 100,000 people"),
      f.population ? el("p", {}, f.population.takeaway) : el("p", { class: "caveat" },
        "Population-based rates will be added once the district population source has been confirmed. Until then, districts are compared by the share of their own waiting list, which needs no outside data."));
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
      if (v) v.textContent = `Data to ${monthLabel(parseMonth(meta.latest_month))}; version ${meta.data_version}, built ${meta.built}.`;
    }).catch(() => {});
    const pages = { "page-national": pageNational, "page-district": pageDistrict, "page-specialty": pageSpecialty, "page-fair": pageFair, "page-target": pageTarget };
    for (const [id, fn] of Object.entries(pages)) {
      const root = document.getElementById(id);
      if (root) fn(root).catch((e) => errorBox(root, e));
    }
    if (document.getElementById("checks-table")) pageMethods().catch(console.error);
  }

  // Redraw charts when the colour scheme changes, so colours follow the theme.
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => location.reload());
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
