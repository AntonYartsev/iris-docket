<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { events, poll } from "../composables/useShell";
import { t } from "../composables/useI18n";
import CapacityTile from "./CapacityTile.vue";

const history = shallowRef(null);
const failed = ref("");

watch(
  events,
  async () => {
    try {
      history.value = (await poll("monitor.history")).data;
      failed.value = "";
    } catch (e) {
      failed.value = e.message;
    }
  },
  { immediate: true },
);

const compact = (v) =>
  v === null || v === undefined
    ? "-"
    : v >= 1e6
      ? `${(v / 1e6).toFixed(1)}M`
      : v >= 1e4
        ? `${Math.round(v / 1e3)}k`
        : `${+v.toFixed(v < 10 ? 2 : 0)}`;
const pct = (v) => (v === null || v === undefined ? "-" : `${Math.round(v)}`);
const tone = (v) => (v >= 90 ? "text-deny" : v >= 75 ? "text-confirm" : "text-text-bright");

const span = computed(() => Math.max(1, -(history.value?.t[0] ?? 0)));
const clock = (minutesAgo) => {
  const tm = (history.value?.now ?? "").split(" ")[1];
  if (!tm) return "";
  const [h, m] = tm.split(":").map(Number);
  const at = (((h * 60 + m - minutesAgo) % 1440) + 1440) % 1440;
  return `${String(Math.floor(at / 60)).padStart(2, "0")}:${String(at % 60).padStart(2, "0")}`;
};
const axis = computed(() => [1, 0.75, 0.5, 0.25].map((f) => clock(Math.round(span.value * f))).concat("now"));

function draw(values, top) {
  const h = history.value;
  if (!h || !values.length) return { line: "", area: "" };
  const x = (t) => ((t + span.value) / span.value) * 240;
  const y = (v) => 58 - (Math.min(v, top) / top) * 54;
  let line = "";
  let area = "";
  let run = [];
  const flush = () => {
    if (!run.length) return;
    if (run.length === 1) run.push([run[0][0] + 2, run[0][1]]);
    const d = run.map(([px, py], i) => `${i ? "L" : "M"}${px.toFixed(1)} ${py.toFixed(1)}`).join(" ");
    line += d;
    area += `${d} L${run.at(-1)[0].toFixed(1)} 60 L${run[0][0].toFixed(1)} 60 Z`;
    run = [];
  };
  values.forEach((v, i) => {
    if (v === null || (i && h.t[i] - h.t[i - 1] > 2)) flush();
    if (v !== null) run.push([x(h.t[i]), y(v)]);
  });
  flush();
  return { line, area };
}

const stats = (values) => {
  const vs = values.filter((v) => v !== null);
  return vs.length ? { avg: vs.reduce((a, b) => a + b, 0) / vs.length, peak: Math.max(...vs) } : null;
};

const tiles = computed(() => {
  const h = history.value ?? { cpu: [], memory: [], globalRefs: [], sql: [] };
  const tile = (key, label, fmt, unit, fixed) => {
    const s = stats(h[key]);
    const now = h[key].at(-1) ?? null;
    const top = fixed ? Math.max(10, Math.ceil(((s?.peak ?? 0) * 1.25) / 10) * 10) : (s?.peak ?? 1) * 1.15 || 1;
    return {
      label,
      now: fmt(now),
      unit,
      tone: fixed ? tone(now) : "text-text-bright",
      avg: s ? fmt(s.avg) : "-",
      peak: s ? fmt(s.peak) : "-",
      top: fixed ? `${top}%` : compact(top),
      ...draw(h[key], top),
    };
  };
  return [
    tile("cpu", t("health.cpu"), pct, "%", true),
    tile("memory", t("health.memory"), pct, "%", true),
    tile("globalRefs", t("health.refs"), compact, "", false),
    tile("sql", t("health.sql"), compact, "", false),
  ];
});
</script>

<template>
  <section class="flex min-w-0 flex-col overflow-hidden rounded-card border border-line bg-surface">
    <div class="grid grid-cols-[repeat(4,minmax(0,1fr))_1.15fr]">
      <div
        v-for="m in tiles"
        :key="m.label"
        class="flex min-w-0 flex-col border-l border-line px-3 pt-2 pb-1.5 first:border-l-0"
      >
        <div class="truncate text-micro text-text-muted">{{ m.label }}</div>
        <div class="flex items-end gap-1">
          <span :key="m.now" class="animate-number text-display leading-tight tabular-nums" :class="m.tone">{{
            m.now
          }}</span>
          <span class="mb-1 text-small text-text-muted">{{ m.unit }}</span>
          <span class="mb-0.5 ml-auto text-right font-mono text-[11px] leading-tight text-text-muted">
            <span class="block"
              >{{ t("health.avg") }} <span class="text-text">{{ m.avg }}</span></span
            >
            <span class="block"
              >{{ t("health.peak") }} <span class="text-text">{{ m.peak }}</span></span
            >
          </span>
        </div>
        <div class="relative min-h-[60px] flex-1 [@media(max-height:820px)]:min-h-[34px]">
          <span class="absolute top-0 right-0 z-10 font-mono text-[10.5px] text-text-dim">{{ m.top }}</span>
          <svg viewBox="0 0 240 60" preserveAspectRatio="none" class="absolute inset-0 size-full">
            <line
              v-for="g in [15, 30, 45]"
              :key="g"
              x1="0"
              x2="240"
              :y1="g"
              :y2="g"
              stroke="var(--color-line)"
              vector-effect="non-scaling-stroke"
            />
            <path :d="m.area" fill="var(--color-accent)" opacity="0.16" />
            <path
              :d="m.line"
              fill="none"
              stroke="var(--color-accent)"
              stroke-width="1.5"
              vector-effect="non-scaling-stroke"
            />
          </svg>
        </div>
        <div class="flex justify-between font-mono text-[10.5px] text-text-dim">
          <span v-for="(a, i) in axis" :key="i">{{ a }}</span>
        </div>
      </div>

      <CapacityTile />
    </div>
    <p v-if="failed" class="border-t border-line px-3 py-1.5 text-micro text-text-muted">{{ failed }}</p>
  </section>
</template>
