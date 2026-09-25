import { ref, shallowRef } from "vue";

const BASE = "/portal/api";

// cookie only, nothing stored
let authorization = null;

export async function api(path, body) {
  const res = await fetch(BASE + path, {
    method: body === undefined ? "GET" : "POST",
    credentials: "same-origin",
    headers: {
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      ...(authorization ? { Authorization: authorization } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok || json?.error) {
    // iris 401 has no body
    throw Object.assign(new Error(json?.error?.message ?? `${res.status} ${res.statusText}`), {
      code: json?.error?.code ?? (res.status === 401 ? "unauthorized" : "internal"),
      detail: json?.error?.detail,
    });
  }
  return json;
}

export async function signIn(user, password) {
  authorization = "Basic " + btoa(String.fromCharCode(...new TextEncoder().encode(`${user}:${password}`)));
  try {
    return await api("/info");
  } finally {
    authorization = null;
  }
}

export function useResource(load) {
  const data = shallowRef(null);
  const error = ref(null);
  const pending = ref(true);

  const reload = async () => {
    pending.value = true;
    error.value = null;
    try {
      data.value = (await load()).data;
    } catch (e) {
      error.value = e;
    } finally {
      pending.value = false;
    }
  };

  reload();
  return { data, error, pending, reload };
}
