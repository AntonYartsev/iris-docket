<script setup>
import { computed, ref, shallowRef } from "vue";
import { stored } from "../composables/useStored";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import DetailPanel from "../components/DetailPanel.vue";
import FieldGrid from "../components/FieldGrid.vue";
import FilterField from "../components/FilterField.vue";
import RefreshButton from "../components/RefreshButton.vue";
import TabBar from "../components/TabBar.vue";

const { invoke } = useToolInvoke();

const rows = shallowRef({ x509: [], wallet: [], tls: [], servers: [], clients: [] });
const state = shallowRef({});
const error = shallowRef({});
const busy = ref(false);
const filter = ref("");
const selected = ref("");

async function load() {
  busy.value = true;
  const keys = ["x509", "wallet", "tls", "servers"];
  state.value = { x509: "loading", wallet: "loading", tls: "loading", servers: "loading", clients: "loading" };
  const answers = await Promise.allSettled([
    invoke("secrets.x509.list", { maxRows: 1000 }, true),
    invoke("secrets.wallet.collections", { maxRows: 1000 }, true),
    invoke("secrets.tls.list", { maxRows: 1000 }, true),
    invoke("secrets.oauth2.servers", { maxRows: 1000 }, true),
  ]);
  const next = { x509: [], wallet: [], tls: [], servers: [], clients: [] },
    states = {},
    failures = {};
  answers.forEach((a, i) => {
    const key = keys[i];
    next[key] = a.status === "fulfilled" ? a.value.data : [];
    states[key] = a.status === "fulfilled" ? "ready" : a.reason.code === "policy_denied" ? "denied" : "error";
    if (a.status === "rejected") failures[key] = a.reason.message;
  });

  if (states.x509 === "ready") {
    const certs = await Promise.allSettled(
      next.x509.map((c) => invoke("secrets.x509.certificate", { alias: c.Alias }, true)),
    );
    next.x509 = next.x509.map((c, i) =>
      certs[i].status === "fulfilled"
        ? { ...c, ...certs[i].value.data, days: daysLeft(certs[i].value.data.ValidityNotAfter) }
        : { ...c, failed: certs[i].reason.message },
    );
  }

  if (states.servers === "ready") {
    const perServer = await Promise.allSettled(
      next.servers.map((srv) => invoke("secrets.oauth2.list", { serverId: srv.ID, maxRows: 1000 }, true)),
    );
    next.clients = perServer.flatMap((r, i) =>
      r.status === "fulfilled" ? r.value.data.map((c) => ({ ...c, Server: next.servers[i].ID })) : [],
    );
    states.clients = "ready";
  } else {
    states.clients = states.servers;
    failures.clients = `client configurations are listed per server, and the server list did not come back: ${failures.servers}`;
  }

  rows.value = next;
  state.value = states;
  error.value = failures;
  busy.value = false;
}
load();

function daysLeft(until) {
  if (!until) return null;
  const day = (s) => Date.parse(s.slice(0, 10) + "T00:00:00Z");
  return Math.round((day(until) - day(new Date().toISOString())) / 86_400_000);
}

const anyone = (c) => !c.OwnerList?.length;
const selfSigned = (c) => !!c.IssuerDN && c.IssuerDN === c.SubjectDN;
const cn = (dn) => /CN=([^,]+)/.exec(dn ?? "")?.[1] ?? dn;

const tone = (c) => (c.days < 0 ? "text-deny" : c.days <= 30 ? "text-confirm" : "text-text-muted");
const left = (c) => (c.days < 0 ? `${-c.days} d ago` : c.days === 0 ? "today" : `${c.days} d`);

const cert = computed(() => rows.value.x509.find((c) => c.Alias === selected.value));
const facts = computed(() => {
  const c = cert.value;
  return [
    ["Subject", c.SubjectDN],
    ["Issuer", selfSigned(c) ? `${c.IssuerDN} (self-signed)` : c.IssuerDN],
    ["Serial", c.SerialNumber],
    ["Valid from", c.ValidityNotBefore && `${c.ValidityNotBefore} UTC`],
    ["Expires", c.ValidityNotAfter && `${c.ValidityNotAfter} UTC · ${left(c)}`],
    ["Private key", c.HasPrivateKey ? "held" : "not held"],
    ["Owners", anyone(c) ? "anyone - every user of the instance" : c.OwnerList.join(", ")],
    ["Peer names", c.PeerNames?.join(", ")],
    ["CA file", c.CAFile || "default - iris.cer in the manager directory"],
  ];
});

const expired = computed(() => rows.value.x509.filter((c) => c.days < 0).length);
const expiring = computed(() => rows.value.x509.filter((c) => c.days >= 0 && c.days <= 30).length);

const TABS = [
  {
    key: "x509",
    label: "Certificates",
    title: "CERTIFICATES",
    tool: "secrets.x509.list",
    note: "X.509 credentials and when each certificate lapses. A private key is never returned - only whether one is held.",
    rowKey: "Alias",
    columns: [
      { key: "Alias", label: "Credential", mono: true, class: "text-text-bright" },
      { key: "ValidityNotAfter", label: "Expires", mono: true },
      { key: "OwnerList", label: "Key used by" },
      { key: "IssuerDN", label: "Issuer", class: "max-w-[140px] truncate text-text-muted" },
    ],
    empty: "No X.509 credentials",
  },
  {
    key: "tls",
    label: "TLS",
    title: "TLS CONFIGURATIONS",
    tool: "secrets.tls.list",
    note: "Certificates and keys are named here, not shown.",
    rowKey: "Name",
    columns: [
      {
        key: "Name",
        label: "Configuration",
        mono: true,
        class: "text-text-bright",
      },
      { key: "Type", label: "Type", class: "text-text-muted" },
      { key: "Enabled", label: "State" },
      {
        key: "Description",
        label: "Description",
        class: "max-w-[200px] truncate text-text-muted",
      },
    ],
    empty: "No TLS configurations",
  },
  {
    key: "wallet",
    label: "Wallet",
    title: "WALLET COLLECTIONS",
    tool: "secrets.wallet.collections",
    note: "Access to a collection is controlled by resources, which is what is shown. The secrets themselves are not readable through any API.",
    rowKey: "Name",
    columns: [
      {
        key: "Name",
        label: "Collection",
        mono: true,
        class: "text-text-bright",
      },
      {
        key: "EditResource",
        label: "Edit requires",
        mono: true,
        class: "text-text-muted",
      },
      {
        key: "UseResource",
        label: "Use requires",
        mono: true,
        class: "text-text-muted",
      },
    ],
    empty: "No wallet collections",
  },
  {
    key: "servers",
    label: "OAuth2 servers",
    title: "OAUTH2 SERVERS",
    tool: "secrets.oauth2.servers",
    note: "Servers this instance talks to as a client.",
    rowKey: "ID",
    columns: [
      { key: "ID", label: "Server", mono: true, class: "text-text-bright" },
      {
        key: "IssuerEndpoint",
        label: "Issuer",
        mono: true,
        class: "max-w-[220px] truncate text-text-muted",
      },
      { key: "ClientCount", label: "Clients", right: true, mono: true },
      { key: "ResourceCount", label: "Resources", right: true, mono: true },
    ],
    empty: "No OAuth2 servers",
  },
  {
    key: "clients",
    label: "OAuth2 clients",
    title: "OAUTH2 CLIENTS",
    tool: "secrets.oauth2.list",
    note: "Client secrets are not part of these responses.",
    rowKey: "ApplicationName",
    columns: [
      {
        key: "ApplicationName",
        label: "Application",
        mono: true,
        class: "text-text-bright",
      },
      { key: "ClientType", label: "Client type", class: "text-text-muted" },
      {
        key: "DefaultScope",
        label: "Default scope",
        mono: true,
        class: "max-w-[180px] truncate text-text-muted",
      },
      { key: "Server", label: "Server", mono: true, class: "text-text-muted" },
    ],
    empty: "No client configurations",
  },
];

const tab = stored(
  "secrets.tab",
  "x509",
  TABS.map((t) => t.key),
);
const current = computed(() => TABS.find((t) => t.key === tab.value));
const tabs = computed(() => TABS.map((t) => ({ key: t.key, label: t.label, count: rows.value[t.key].length })));

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const list = rows.value[tab.value];
  return q ? list.filter((r) => JSON.stringify(r).toLowerCase().includes(q)) : list;
});
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" />
    <TabBar v-model="tab" :tabs="tabs" />
    <RefreshButton :busy="busy" title="Read the certificates, configurations and clients again" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      :title="current.title"
      :meta="`${shown.length} of ${rows[tab].length} · read only`"
      :meta-title="current.note"
      class="flex-1"
    >
      <template v-if="tab === 'x509'" #actions>
        <span v-if="expired" class="inline-flex items-center gap-1.5 text-micro text-deny">
          <span class="size-[5px] rounded-badge bg-current" />{{ expired }} expired
        </span>
        <span v-if="expiring" class="inline-flex items-center gap-1.5 text-micro text-confirm">
          <span class="size-[5px] rounded-badge bg-current" />{{ expiring }} within 30 days
        </span>
      </template>

      <DataTable
        :columns="current.columns"
        :rows="shown"
        :row-key="current.rowKey"
        :selectable="tab === 'x509'"
        :selected="tab === 'x509' ? selected : null"
        :state="state[tab]"
        :error="error[tab]"
        :tool="current.tool"
        :empty="filter ? 'Nothing matches the filter' : current.empty"
        :empty-hint="current.note"
        @select="selected = $event.Alias"
        @retry="load"
      >
        <template #Enabled="{ row }">
          <span :class="row.Enabled ? 'text-text-muted' : 'text-deny'">{{ row.Enabled ? "enabled" : "disabled" }}</span>
        </template>
        <template #OwnerList="{ row }">
          <span
            :class="row.HasPrivateKey && anyone(row) ? 'text-confirm' : 'text-text-muted'"
            :title="
              !row.HasPrivateKey
                ? 'No private key held'
                : anyone(row)
                  ? 'Private key held, and no owner list: every user of the instance can use it'
                  : 'Private key held'
            "
          >
            {{ !row.HasPrivateKey ? "-" : anyone(row) ? "anyone" : row.OwnerList.join(", ") }}
          </span>
        </template>
        <template #IssuerDN="{ row }">
          <span :title="row.IssuerDN">{{ selfSigned(row) ? "self-signed" : cn(row.IssuerDN) || "-" }}</span>
        </template>
        <template #ValidityNotAfter="{ row }">
          <span v-if="row.failed" class="text-deny" :title="row.failed">unreadable</span>
          <span v-else :class="tone(row)" :title="`${row.ValidityNotBefore} – ${row.ValidityNotAfter} UTC`">
            {{ row.ValidityNotAfter?.slice(0, 10) }} · {{ left(row) }}
          </span>
        </template>
        <template #Description="{ row }">
          <span :title="row.Description">{{ row.Description || "-" }}</span>
        </template>
      </DataTable>
    </Block>

    <DetailPanel
      v-if="tab === 'x509' && cert"
      title="CERTIFICATE"
      :subject="cert.Alias"
      class="!w-[420px]"
      @close="selected = ''"
    >
      <div class="px-2.5 py-[9px]">
        <FieldGrid :rows="facts" label-width="84px">
          <template #Expires="{ value }">
            <span :class="tone(cert)">{{ value }}</span>
          </template>
          <template #Owners="{ value }">
            <span :class="cert.HasPrivateKey && anyone(cert) && 'text-confirm'">{{ value }}</span>
          </template>
        </FieldGrid>
      </div>
    </DetailPanel>
  </div>
</template>
