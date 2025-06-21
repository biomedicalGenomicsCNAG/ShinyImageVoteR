document.addEventListener("keydown", (e) => {
  // Trigger login button on Enter
  const loginBtn = document.getElementById("loginBtn");
  if (e.key === "Enter" && loginBtn) {
    loginBtn.click();
    return;
  }

  // Trigger next button on Enter
  const nextBtn = document.getElementById("nextBtn");
  if (e.key === "Enter" && nextBtn) {
    nextBtn.click();
    return;
  }

  // Tricker back button on backspace
  const backBtn = document.getElementById("backBtn");
  if (e.key === "Backspace" && backBtn) {
    backBtn.click();
    return;
  }

  const container = document.getElementById("agreement");
  if (!container) return;

  // Ignore key presses when typing in form fields
  const tag = document.activeElement.tagName;
  if (tag === "INPUT" || tag === "TEXTAREA") return;

  function setVal(value) {
    const input = document.querySelector(
      `input[name="agreement"][value="${value}` + '"]'
    );
    if (!input) {
      return;
    }
    input.checked = true;
    // Trigger change for Shiny
    const evt = new Event("change", { bubbles: true });
    input.dispatchEvent(evt);
  }

  switch (e.key) {
    case "1":
      setVal("yes");
      break;
    case "2":
      setVal("no");
      break;
    case "3":
      setVal("diff_var");
      break;
    case "4":
      setVal("not_confident");
      break;
  }
});
