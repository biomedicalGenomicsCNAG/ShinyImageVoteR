// Initialize Panzoom on a given container and image element IDs.
// Usage: initPanzoom('namespace-voting_image_container', 'namespace-voting_image')
function initPanzoom(containerId, imageId) {
  try {
    const container = document.getElementById(containerId);
    if (!container) {
      return;
    }

    if (typeof Panzoom !== "function") {
      console.error("Panzoom library is not loaded.");
      return;
    }

    const image = document.getElementById(imageId);
    if (!image) {
      return;
    }

    const panzoom = Panzoom(image, {
      contain: "outside",
      maxScale: 10,
      minScale: 1,
    });

    container.__panzoomInstance = panzoom;

    const wheelHandler = (event) => {
      event.preventDefault();
      panzoom.zoomWithWheel(event);
    };
    container.__wheelHandler = wheelHandler;
    container.addEventListener("wheel", wheelHandler, { passive: false });

    // const pointerDown = function () {
    //   container.style.cursor = "grabbing";
    // };
    // const pointerUp = function () {
    //   container.style.cursor = "grab";
    // };
    // container.__pointerDown = pointerDown;
    // container.__pointerUp = pointerUp;
    // container.addEventListener("pointerdown", pointerDown);
    // window.addEventListener("pointerup", pointerUp);
  } catch (err) {
    console.error("initPanzoom error:", err);
  }
}

(() => {
  const initialized = new WeakSet();

  function tryInit(container) {
    console.log("panzoom tryInit with container:", container);
    if (!container || initialized.has(container)) return;
    const img = container.querySelector("[data-panzoom-image]");
    if (!img || !container.id || !img.id) return;
    initPanzoom(container.id, img.id);
    initialized.add(container);
    console.log("panzoom initialized for container:", container);
    console.log("initialized set:", initialized);
  }

  function scan(root) {
    // console.log("panzoom scan in root:", root);
    (root || document)
      .querySelectorAll("[data-panzoom-container]")
      .forEach(tryInit);
  }

  // watch for Shiny re-renders
  const obs = new MutationObserver((muts) => {
    console.log("panzoom mutation observed:", muts);
    muts.forEach((m) => {
      m.addedNodes.forEach((node) => {
        if (node.nodeType !== 1) return;
        if (node.matches?.("[data-panzoom-container]")) tryInit(node);
        scan(node); // catch descendants
      });
    });
  });
  obs.observe(document.body, { childList: true, subtree: true });
})();
