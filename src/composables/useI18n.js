import en from "../locales/en.json";

export function t(key, vars) {
  const s = en[key] ?? key;
  return vars ? s.replace(/\{(\w+)\}/g, (m, name) => vars[name] ?? m) : s;
}
