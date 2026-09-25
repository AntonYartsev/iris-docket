import { createApp } from "vue";
import { createRouter, createWebHashHistory } from "vue-router";
import "./styles/theme.css";
import App from "./App.vue";
import Dashboard from "./views/Dashboard.vue";
import Security from "./views/Security.vue";
import Tools from "./views/Tools.vue";
import Audit from "./views/Audit.vue";

// hash history, no rewrites
const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: "/", redirect: "/dashboard" },
    { path: "/dashboard", component: Dashboard },
    { path: "/security", component: Security },
    { path: "/secrets", component: () => import("./views/Secrets.vue") },
    { path: "/webapps", component: () => import("./views/WebApps.vue") },
    { path: "/tasks", component: () => import("./views/Tasks.vue") },
    { path: "/system", component: () => import("./views/System.vue") },
    { path: "/logs", component: () => import("./views/Logs.vue") },
    { path: "/interop", component: () => import("./views/Interop.vue") },
    { path: "/packages", component: () => import("./views/Packages.vue") },
    { path: "/tools", component: Tools },
    { path: "/policy", component: () => import("./views/Policy.vue") },
    { path: "/audit", component: Audit },
    { path: "/agent", component: () => import("./views/Agent.vue") },
    { path: "/findings", component: () => import("./views/Findings.vue") },
    { path: "/reach", component: () => import("./views/Reach.vue") },
    { path: "/version", component: () => import("./views/Version.vue") },
    { path: "/:rest(.*)*", redirect: "/dashboard" },
  ],
});

createApp(App).use(router).mount("#app");
