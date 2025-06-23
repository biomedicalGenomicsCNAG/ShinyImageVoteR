// document.addEventListener("keydown", (e) => {
//   console.log("Key pressed:", e.key);
//   // ——— special buttons ———
//   if (e.key === "Enter") {
//     document.getElementById("nextBtn")?.click();
//     return;
//   }

//   // ——— back button ———
//   if (e.key === "Backspace") {
//     console.log("Backspace pressed");
//     // if the comment box is focused, let Backspace delete text instead
//     if (
//       document.activeElement.id === "comment" ||
//       document.activeElement.id === "passwd"
//     ) {
//       return;
//     }
//     console.log("Backspace pressed, going back");
//     console.log("History length:", history.length);
//     history.back();
//     // otherwise, fire your back button
//     // document.getElementById("backBtn")?.click();
//     return;
//   }

//   // ——— don’t fire when typing ———
//   const tag = document.activeElement.tagName;
//   if (tag === "INPUT" || tag === "TEXTAREA") return;

//   const groups = {
//     // ——— radio buttons ———
//     agreement: {
//       keys: { 1: "yes", 2: "no", 3: "diff_var", 4: "not_confident" },
//       toggle: false,
//     },
//     // ——— checkboxes ———
//     observation: {
//       keys: {
//         a: "coverage",
//         s: "low_vaf",
//         d: "alignment",
//         f: "complex",
//         g: "img_qual_issue",
//         h: "platform_issue",
//       },
//       toggle: true,
//     },
//   };

//   // ——— look up which group & value this key belongs to ———
//   for (const [groupId, { keys: map, toggle }] of Object.entries(groups)) {
//     const value = map[e.key];
//     if (!value) continue;

//     // document.querySelector('input[name="observation"][value="issues_with_coverage"]')

//     // build a single selector for both radios & checkboxes:
//     const sel = `input[name="${groupId}"][value="${value}"]`;
//     console.log(
//       "Hotkey pressed:",
//       e.key,
//       "for group:",
//       groupId,
//       "value:",
//       value
//     );
//     console.log("Selector:", sel);
//     const input = document.querySelector(sel);
//     if (!input) return;

//     input.checked = toggle ? !input.checked : true;
//     input.dispatchEvent(new Event("change", { bubbles: true }));
//     return;
//   }
// });

// wrap in an IIFE so it only runs once per page load
(function () {
  // your handler as a named function:
  function hotkeysHandler(e) {
    console.log("Key pressed:", e.key);

    // ——— special buttons ———
    if (e.key === "Enter") {
      document.getElementById("nextBtn")?.click();
      return;
    }

    // ——— back button ———
    if (e.key === "Backspace") {
      // only on the very first keydown, not repeats:
      if (e.repeat) return;

      console.log("Backspace pressed");
      // if inside a text field, do the normal delete:
      if (["comment", "passwd"].includes(document.activeElement.id)) {
        return;
      }
      e.preventDefault(); // stop native back-navigation
      console.log("Backspace → history.back()");
      history.back();
      return;
    }

    // ——— don’t fire when typing elsewhere ———
    const tag = document.activeElement.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA") return;

    // ——— your radio/checkbox hotkeys ———
    const groups = {
      agreement: {
        keys: { 1: "yes", 2: "no", 3: "diff_var", 4: "not_confident" },
        toggle: false,
      },
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

    for (const [groupId, { keys: map, toggle }] of Object.entries(groups)) {
      const value = map[e.key];
      if (!value) continue;
      const sel = `input[name="${groupId}"][value="${value}"]`;
      console.log("Hotkey:", e.key, "→", sel);
      const input = document.querySelector(sel);
      if (!input) return;

      input.checked = toggle ? !input.checked : true;
      input.dispatchEvent(new Event("change", { bubbles: true }));
      return;
    }
  }

  // remove any old copy, then bind exactly one
  document.removeEventListener("keydown", hotkeysHandler);
  document.addEventListener("keydown", hotkeysHandler);
  console.log("Global hotkeysHandler bound once");
})();
