<script setup>
import { onMounted, ref } from "vue";
import { signIn } from "../composables/useApi";
import { t } from "../composables/useI18n";

const emit = defineEmits(["signedIn"]);

const user = ref("");
const password = ref("");
// autofocus ignored, mounts late
const nameField = ref(null);
onMounted(() => nameField.value?.focus());
const busy = ref(false);
const failed = ref("");

const submit = async () => {
  busy.value = true;
  failed.value = "";
  try {
    await signIn(user.value, password.value);
    password.value = "";
    emit("signedIn");
  } catch (e) {
    failed.value = e.code === "unauthorized" ? t("login.wrong") : e.message;
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <div class="flex min-h-screen items-center justify-center p-4">
    <form
      class="w-full max-w-[320px] space-y-2.5 rounded-card border border-line bg-surface p-6 shadow-overlay"
      @submit.prevent="submit"
    >
      <div class="flex items-center justify-center gap-2 pb-3">
        <span class="grid grid-cols-2 gap-[2px]">
          <i v-for="i in 4" :key="i" class="block size-[6px] rounded-[1.5px] bg-accent" />
        </span>
        <h1 class="text-title font-semibold text-text-bright">Docket</h1>
      </div>

      <input
        ref="nameField"
        v-model="user"
        autocomplete="username"
        :placeholder="t('login.user')"
        :aria-label="t('login.user')"
        class="h-10 w-full rounded-control border border-line-strong bg-base px-3 text-small text-text placeholder:text-text-muted"
      />

      <input
        v-model="password"
        type="password"
        autocomplete="current-password"
        :placeholder="t('login.password')"
        :aria-label="t('login.password')"
        class="h-10 w-full rounded-control border border-line-strong bg-base px-3 text-small text-text placeholder:text-text-muted"
      />

      <button
        type="submit"
        :disabled="busy"
        class="h-10 w-full rounded-control bg-accent text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-50"
      >
        {{ busy ? t("login.signingIn") : t("login.signIn") }}
      </button>

      <p v-if="failed" class="text-center text-small text-deny">{{ failed }}</p>
    </form>
  </div>
</template>
