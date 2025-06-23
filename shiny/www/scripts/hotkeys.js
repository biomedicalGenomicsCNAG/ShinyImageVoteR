document.addEventListener("keydown", (e) => {
  console.log("Key pressed:", e.key);
  // ——— special buttons ———
  if (e.key === "Enter") {
    document.getElementById("nextBtn")?.click();
    return;
  }

  // ——— back button ———
  if (e.key === "Backspace") {
    console.log("Backspace pressed");
    // if the comment box is focused, let Backspace delete text instead
    if (
      document.activeElement.id === "comment" ||
      document.activeElement.id === "passwd"
    ) {
      return;
    }
    console.log("Backspace pressed, going back");
    console.log("History length:", history.length);
    history.back();
    // otherwise, fire your back button
    // document.getElementById("backBtn")?.click();
    return;
  }

  // ——— don’t fire when typing ———
  const id = document.activeElement.id;
  if (id === "comment") return;

  const groups = {
    // ——— radio buttons ———
    agreement: {
      keys: { 1: "yes", 2: "no", 3: "diff_var", 4: "not_confident" },
      toggle: false,
    },
    // ——— checkboxes ———
    observation: {
      keys: {
        a: "coverage",
        s: "low_vaf",
        d: "alignment",
        f: "complex",
        g: "img_qual_issue",
        h: "platform_issue",
      },
      toggle: true,
    },
  };

  // ——— look up which group & value this key belongs to ———
  for (const [groupId, { keys: map, toggle }] of Object.entries(groups)) {
    const value = map[e.key];
    if (!value) continue;

    // document.querySelector('input[name="observation"][value="issues_with_coverage"]')

    // build a single selector for both radios & checkboxes:
    const sel = `input[name="${groupId}"][value="${value}"]`;
    console.log(
      "Hotkey pressed:",
      e.key,
      "for group:",
      groupId,
      "value:",
      value
    );
    console.log("Selector:", sel);
    const input = document.querySelector(sel);
    if (!input) return;

    input.checked = toggle ? !input.checked : true;
    input.dispatchEvent(new Event("change", { bubbles: true }));
    return;
  }
});
