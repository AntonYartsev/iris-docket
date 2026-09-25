import { ref, watch } from "vue";

const PREFIX = "portal.ui.";

function read(key) {
  try {
    const raw = localStorage.getItem(PREFIX + key);
    return raw === null ? undefined : JSON.parse(raw);
  } catch {
    return undefined;
  }
}

function write(key, value) {
  try {
    localStorage.setItem(PREFIX + key, JSON.stringify(value));
  } catch {
    // storage full, whatever..
  }
}

export function stored(key, initial, allowed) {
  const saved = read(key);
  const usable = saved !== undefined && (!allowed || allowed.includes(saved));
  const state = ref(usable ? saved : initial);
  watch(state, (v) => write(key, v), { deep: true });
  return state;
}
