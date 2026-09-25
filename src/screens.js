const screen = (to, icon, badge, tone) => ({
  to,
  icon,
  badge,
  tone,
  label: `screen.${to.slice(1)}`,
  hint: `screen.${to.slice(1)}.hint`,
  window: badge ? `badge.${badge}` : "",
});

export const GROUPS = [
  {
    label: "nav.home",
    items: [screen("/dashboard", "dashboard")],
  },
  {
    label: "nav.instance",
    items: [
      screen("/system", "system"),
      screen("/security", "security"),
      screen("/secrets", "secrets"),
      screen("/webapps", "webapps"),
      screen("/tasks", "tasks", "tasks", "confirm"),
      screen("/logs", "logs", "logs", "confirm"),
      screen("/interop", "interop", "interop", "deny"),
      screen("/packages", "packages"),
    ],
  },
  {
    label: "nav.governance",
    items: [screen("/tools", "tools"), screen("/policy", "policy"), screen("/audit", "audit")],
  },
  {
    label: "nav.agent",
    items: [screen("/agent", "agent")],
  },
  {
    label: "nav.insight",
    items: [screen("/findings", "findings", "findings", "deny"), screen("/reach", "reach")],
  },
  {
    label: "nav.portal",
    items: [screen("/version", "version")],
  },
];

export const SCREENS = GROUPS.flatMap((g) => g.items);
