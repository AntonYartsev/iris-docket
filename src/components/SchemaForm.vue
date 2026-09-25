<script setup>
import { computed, reactive } from "vue";

const props = defineProps({
  schema: { type: Object, required: true },
  modelValue: { type: Object, required: true },
});
const emit = defineEmits(["update:modelValue"]);

const fields = computed(() => Object.entries(props.schema.properties ?? {}));
const isRequired = (key) => (props.schema.required ?? []).includes(key);

function set(key, value) {
  const next = { ...props.modelValue };
  if (value === "" || value === undefined || value === null) delete next[key];
  else next[key] = value;
  emit("update:modelValue", next);
}

const raw = reactive({});
const parses = (key) => {
  try {
    JSON.parse(raw[key]);
    return true;
  } catch {
    return false;
  }
};
function json(key, text) {
  raw[key] = text;
  if (text.trim() === "") return set(key, "");
  if (parses(key)) set(key, JSON.parse(text));
}
function list(key, text) {
  raw[key] = text;
  set(
    key,
    text
      .split(",")
      .map((v) => v.trim())
      .filter(Boolean),
  );
}

const label = (key, field) => field.title || key;
const hint = (field) => (field.description || "").replace(/<[^>]+>/g, " ").trim();
</script>

<template>
  <div class="grid gap-2">
    <template v-for="[key, field] in fields" :key="key">
      <fieldset
        v-if="field.type === 'object' && field.properties"
        class="rounded-control border border-line px-cell-x py-cell-y"
      >
        <legend class="px-1 text-micro text-text-muted">
          {{ label(key, field) }}
        </legend>
        <SchemaForm
          :schema="field"
          :model-value="modelValue[key] ?? {}"
          @update:model-value="set(key, Object.keys($event).length ? $event : '')"
        />
      </fieldset>

      <label v-else-if="field.type === 'object' || field.items?.type === 'object'" class="block">
        <span class="mb-1 flex items-baseline gap-2 text-micro text-text-muted">
          {{ label(key, field) }}
          <span v-if="isRequired(key)" class="text-deny">required</span>
          <span v-if="raw[key] && !parses(key)" class="text-deny">not valid JSON</span>
        </span>
        <textarea
          rows="10"
          spellcheck="false"
          class="w-full rounded-control border bg-base px-2 py-1 font-mono text-micro text-text"
          :class="raw[key] && !parses(key) ? 'border-deny' : 'border-line-strong'"
          :value="raw[key] ?? (key in modelValue ? JSON.stringify(modelValue[key], null, 2) : '')"
          @input="json(key, $event.target.value)"
        />
      </label>

      <label v-else class="block">
        <span class="mb-1 flex items-baseline gap-2 text-micro text-text-muted">
          {{ label(key, field) }}
          <span v-if="isRequired(key)" class="text-deny">required</span>
          <span class="truncate text-text-muted" :title="hint(field)">{{ hint(field) }}</span>
        </span>

        <select
          v-if="field.type === 'boolean'"
          class="w-full rounded-control border border-line-strong bg-base h-[var(--size-field)] px-2 text-small text-text"
          :value="key in modelValue ? String(modelValue[key]) : ''"
          @change="set(key, $event.target.value === '' ? '' : $event.target.value === 'true')"
        >
          <option value="">leave as it is</option>
          <option value="true">true</option>
          <option value="false">false</option>
        </select>

        <select
          v-else-if="field.enum"
          class="w-full rounded-control border border-line-strong bg-base h-[var(--size-field)] px-2 text-small text-text"
          :value="modelValue[key] ?? ''"
          @change="set(key, $event.target.value)"
        >
          <option value="">-</option>
          <option v-for="option in field.enum" :key="option" :value="option">
            {{ option }}
          </option>
        </select>

        <input
          v-else-if="field.type === 'array'"
          class="w-full rounded-control border border-line-strong bg-base h-[var(--size-field)] px-2 font-mono text-small text-text"
          placeholder="comma separated"
          :value="raw[key] ?? (modelValue[key] ?? []).join(', ')"
          @input="list(key, $event.target.value)"
        />

        <input
          v-else
          :type="field.type === 'integer' || field.type === 'number' ? 'number' : 'text'"
          class="w-full rounded-control border border-line-strong bg-base h-[var(--size-field)] px-2 text-small text-text"
          :placeholder="field.example ?? ''"
          :value="modelValue[key] ?? ''"
          @input="
            set(
              key,
              field.type === 'integer' || field.type === 'number'
                ? $event.target.value === ''
                  ? ''
                  : Number($event.target.value)
                : $event.target.value,
            )
          "
        />
      </label>
    </template>
  </div>
</template>
