import { reactive, ref, shallowRef } from "vue";
import { api } from "./useApi";
import { useToolInvoke } from "./useToolInvoke";

const { invoke } = useToolInvoke();

// ponytail: 10s poll = journal noise
export const FAST_MS = 10_000;
const SLOW_MS = 60_000;

const SUBSYSTEMS = ["DatabaseSpace", "DatabaseJournal", "JournalSpace", "LockTable", "WriteDaemon"];

const METRICS = [
  "iris_disk_percent_full",
  "iris_directory_space",
  "iris_license_percent_used",
  "iris_license_consumed",
  "iris_license_available",
  "iris_license_days_remaining",
  "iris_process_count",
  "iris_csp_sessions",
  "iris_system_state",
].join(",");

export const info = shallowRef(null);
export const policy = shallowRef(null);
export const tools = shallowRef([]);
export const events = shallowRef([]);
export const latency = ref(0);
export const polls = ref(0);
export const apiState = ref("waiting");
export const alertsLog = ref("");

export const facts = reactive({
  disk: null,
  diskFreeMb: null,
  licence: null,
  licenceUsed: null,
  licenceUnits: null,
  licenceDays: null,
  processes: null,
  sessions: null,
  state: null,
  uptime: "",
  lastBackup: "",
  subsystems: null,
  alerts: null,
});

// iris clock vs browser
const skew = { local: 0, utc: 0 };
const wall = (s) => {
  const [d, t = "0:0:0"] = s.split(" ");
  const [y, mo, da] = d.split("-").map(Number);
  const [h, mi, se] = t.split(":").map(Number);
  return new Date(y, mo - 1, da, h, mi, se).getTime();
};
const p2 = (n) => String(n).padStart(2, "0");
const stamp = (ms) => {
  const t = new Date(ms);
  return `${t.getFullYear()}-${p2(t.getMonth() + 1)}-${p2(t.getDate())} ${p2(t.getHours())}:${p2(t.getMinutes())}:${p2(t.getSeconds())}`;
};

export const stampAgo = (ms, zone = "local") => stamp(Date.now() + skew[zone] - ms);
export const age = (ts, zone = "local") => Date.now() + skew[zone] - wall(ts);

// ponytail: one flag one console
export const agentBusy = ref(false);

export const badges = reactive({ findings: 0, logs: 0, tasks: 0, interop: 0 });
export const counted = ref(false);
export const findings = shallowRef([]);

export async function poll(name, args = {}) {
  await registry;
  const tool = tools.value.find((x) => x.name === name);
  if (tool?.available === false)
    throw { code: "unavailable", message: `${name}: ${tool.unavailable?.reason ?? "not served by this build"}` };
  return invoke(name, args, "background");
}
let registryRead;
const registry = new Promise((resolve) => (registryRead = resolve));

async function fast() {
  const t0 = performance.now();
  polls.value++;
  const [met, dash] = await Promise.allSettled([
    poll("monitor.metrics", { names: METRICS }),
    poll("monitor.dashboard"),
  ]);
  latency.value = Math.round(performance.now() - t0);
  if (met.status !== "fulfilled") {
    apiState.value = "down";
    return;
  }
  apiState.value =
    dash.status === "fulfilled"
      ? latency.value > 1500
        ? "slow"
        : "ok"
      : dash.reason?.code === "unavailable"
        ? "limited"
        : "down";

  const samples = (n) => met.value.data.find((m) => m.name === n)?.samples ?? [];
  const one = (n) => samples(n)[0]?.value ?? null;
  const fullest = samples("iris_disk_percent_full").reduce((a, s) => (!a || s.value > a.value ? s : a), null);
  facts.disk = fullest?.value ?? null;
  facts.diskFreeMb = samples("iris_directory_space").find((s) => s.labels.id === fullest?.labels.id)?.value ?? null;
  facts.licence = one("iris_license_percent_used");
  facts.licenceUsed = one("iris_license_consumed");
  facts.licenceUnits = facts.licenceUsed === null ? null : facts.licenceUsed + (one("iris_license_available") ?? 0);
  facts.licenceDays = one("iris_license_days_remaining");
  facts.processes = one("iris_process_count");
  facts.sessions = one("iris_csp_sessions");
  facts.state = one("iris_system_state");

  if (dash.status !== "fulfilled") return;
  const { Status, SystemUsage: use, Alerts } = dash.value.data;
  facts.uptime = (Status?.UpTime ?? "").replace(/\s+/g, " ").trim();
  facts.lastBackup = Status?.LastBackup ?? "";
  facts.subsystems = use
    ? Object.fromEntries(SUBSYSTEMS.map((k) => [k, use[k]]).filter(([, v]) => v !== undefined))
    : null;
  facts.alerts = Alerts?.SeriousAlerts ?? null;
}

async function feed() {
  const [journal, alerts] = await Promise.allSettled([
    api("/audit?limit=100&changes=1"),
    poll("logs.alerts", { lines: 20 }),
  ]);

  const rows = [];
  if (journal.status === "fulfilled") {
    for (const e of journal.value.data) {
      rows.push({
        key: `aud${e.seq}`,
        src: "aud",
        ts: e.ts,
        tool: e.tool,
        tone: e.decision,
        detail: `${e.decision} · ${e.ruleId ?? "no rule"} · ${e.outcome}${e.durationMs ? ` · ${e.durationMs} ms` : ""}`,
        entry: e,
      });
    }
  }
  alertsLog.value = alerts.status === "rejected" ? alerts.reason.message : "";
  if (alerts.status === "fulfilled") {
    for (const r of alerts.value.data) {
      rows.push({
        key: `log${r.ts}${r.text.slice(0, 24)}`,
        src: "log",
        ts: r.ts,
        tool: r.category || "alerts.log",
        tone: r.level === "info" ? "" : r.level === "warn" ? "confirm" : "deny",
        detail: r.text,
      });
    }
  }

  rows.sort((a, b) => (a.ts < b.ts ? 1 : a.ts > b.ts ? -1 : 0));
  const known = new Set(events.value.map((e) => e.key));
  events.value = rows.slice(0, 40).map((r) => ({
    ...r,
    fresh: events.value.length > 0 && !known.has(r.key),
  }));
}

async function counts() {
  const hourAgo = stampAgo(3600_000);
  const [open, states, prods] = await Promise.allSettled([
    poll("insight.findings"),
    poll("task.states"),
    poll("ens.productions"),
  ]);

  if (open.status === "fulfilled") {
    findings.value = open.value.data.findings;
    badges.findings = findings.value.length;
  }
  if (states.status === "fulfilled") badges.tasks = states.value.data.filter((t) => t.suspended).length;

  badges.logs = events.value.filter((e) => e.src === "log" && e.tone === "deny" && e.ts >= hourAgo).length;

  if (prods.status === "fulfilled") {
    const running = prods.value.data.filter((p) => p.running);
    const errs = await Promise.allSettled(
      running.map((p) => poll("ens.events", { namespace: p.namespace, problemsOnly: true, maxRows: 50 })),
    );
    badges.interop = errs.filter(
      (r) => r.status === "fulfilled" && r.value.data.some((e) => e.ts >= hourAgo && e.level !== "Info"),
    ).length;
  }
  counted.value = true;
}

let started = false;

export async function startShell() {
  if (started) return;
  started = true;

  info.value = (await api("/info")).data;
  const { now, utc } = info.value.portal ?? {};
  if (now) skew.local = wall(now) - Date.now();
  if (utc) skew.utc = wall(utc) - Date.now();
  api("/policy").then((r) => (policy.value = r.data));
  tools.value = (await api("/tools")).data;
  registryRead();

  await fast();
  setInterval(fast, FAST_MS);

  const slow = () => Promise.resolve(feed()).then(counts);
  slow();
  setInterval(slow, SLOW_MS);
}

export const refreshShell = () => Promise.resolve(feed()).then(counts);

export async function reprobe() {
  info.value = (await api("/info?refresh=1")).data;
  tools.value = (await api("/tools")).data;
}
