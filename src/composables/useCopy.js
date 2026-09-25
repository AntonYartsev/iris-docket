import { ref } from "vue";

// clipboard need https
export function useCopy() {
  const copied = ref("");
  async function copy(text, el) {
    try {
      await navigator.clipboard.writeText(text);
      copied.value = text;
      setTimeout(() => copied.value === text && (copied.value = ""), 1500);
    } catch {
      if (el) getSelection().selectAllChildren(el);
    }
  }
  return { copied, copy };
}
