document.addEventListener("keydown", (e) => {
	// only fire if the questions div is on-screen
	const questionsDiv = document.getElementById("voting-voting_questions_div");
	if (!questionsDiv || questionsDiv.offsetParent === null) {
		return;
	}

	console.log("Key pressed:", e.key);
	// ——— special buttons ———
	if (e.key === "Enter") {
		// make sure that the button is enabled
		const nextBtn = document.getElementById("voting-nextBtn");
		if (nextBtn?.disabled) {
			console.log("Next button is disabled, not proceeding");
			return;
		}
		nextBtn.click();
		return;
	}

	// ——— back button ———
	if (e.key === "Backspace") {
		console.log("Backspace pressed");
		// if the comment box is focused, let Backspace delete text instead
		if (
			document.activeElement.id === "voting-comment" ||
			document.activeElement.id === "login-passwd"
		) {
			return;
		}

		// make sure that the button is enabled
		const backBtn = document.getElementById("voting-backBtn");
		if (backBtn?.disabled) {
			console.log("Back button is disabled, not proceeding");
			return;
		}
		backBtn.click();
		return;
	}

	// ——— don’t fire when typing ———
	const id = document.activeElement.id;
	if (id === "voting-comment") return;

	const groups = {
		// ——— radio buttons ———
		agreement: {
			keys: { 1: "yes", 2: "diff_var", 3: "germline", 4: "no_or_few_reads", 5: "none_of_above" },
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
		const sel = `input[name=voting-${groupId}][value="${value}"]`;
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
