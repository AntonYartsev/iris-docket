import { ref } from "vue";
import { api } from "./useApi";

const pending = ref(null);
const toast = ref(null);
let settle = null;

const call = (tool, args, confirmToken) =>
  api(`/tools/${encodeURIComponent(tool)}/invoke`, confirmToken ? { args, confirmToken } : { args });

async function invoke(tool, args = {}, quiet = false) {
  try {
    return done(tool, await call(tool, args), quiet);
  } catch (e) {
    if (e.code !== "confirm_required") {
      if (!quiet)
        toast.value = {
          tone: "deny",
          text: `${tool}: ${e.message}`,
          auditId: e.detail?.auditId,
        };
      throw e;
    }
    pending.value = { tool, ...e.detail };
    return new Promise((resolve) => {
      settle = resolve;
    });
  }
}

async function confirm() {
  const { tool, args, confirmToken } = pending.value;
  pending.value = null;
  try {
    settle(done(tool, await call(tool, args, confirmToken)));
  } catch (e) {
    toast.value = {
      tone: "deny",
      text: `${tool}: ${e.message}`,
      auditId: e.detail?.auditId,
    };
    settle(null);
  }
}

function cancel() {
  pending.value = null;
  settle(null);
}

function done(tool, res, quiet) {
  if (!quiet)
    toast.value = {
      tone: "allow",
      text: `${tool} done in ${res.meta.durationMs} ms`,
      auditId: res.meta.auditId,
    };
  if (quiet !== "background")
    for (const w of res.meta.warnings ?? []) toast.value = { tone: "confirm", text: w, auditId: res.meta.auditId };
  return res;
}

export function useToolInvoke() {
  return {
    invoke,
    confirm,
    cancel,
    pending,
    toast,
    dismiss: () => (toast.value = null),
  };
}
