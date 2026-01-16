// Fullscreen image overlay functionality
(function () {
  let overlayInstance = null;

  function createOverlay() {
    if (overlayInstance) return overlayInstance;

    const overlay = document.createElement("div");
    overlay.id = "fullscreen-overlay";
    overlay.className = "fullscreen-overlay";
    overlay.style.display = "none";

    const closeBtn = document.createElement("button");
    closeBtn.className = "fullscreen-close-btn";
    closeBtn.innerHTML = "&times;";
    closeBtn.setAttribute("aria-label", "Close fullscreen");

    const imgContainer = document.createElement("div");
    imgContainer.className = "fullscreen-image-container";

    const img = document.createElement("img");
    img.className = "fullscreen-image";

    imgContainer.appendChild(img);
    overlay.appendChild(closeBtn);
    overlay.appendChild(imgContainer);
    document.body.appendChild(overlay);

    overlayInstance = {
      element: overlay,
      image: img,
      closeBtn: closeBtn,
    };

    // Close on button click
    closeBtn.addEventListener("click", closeOverlay);

    // Close on overlay background click
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) {
        closeOverlay();
      }
    });

    return overlayInstance;
  }

  function openOverlay(imageSrc) {
    const overlay = createOverlay();
    overlay.image.src = imageSrc;
    overlay.element.style.display = "flex";
    document.body.style.overflow = "hidden";
  }

  function closeOverlay() {
    if (!overlayInstance) return;
    overlayInstance.element.style.display = "none";
    document.body.style.overflow = "";
  }

  // Handle Escape key to close overlay
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && overlayInstance) {
      if (overlayInstance.element.style.display === "flex") {
        closeOverlay();
      }
    }
  });

  // Initialize fullscreen button and double-click handlers
  function initFullscreenForImage(container) {
    if (!container || container.dataset.fullscreenInitialized) return;

    const img = container.querySelector("[data-panzoom-image]");
    if (!img) return;

    // Create fullscreen button
    const fullscreenBtn = document.createElement("button");
    fullscreenBtn.className = "fullscreen-btn";
    fullscreenBtn.innerHTML = "⛶";
    fullscreenBtn.setAttribute("aria-label", "View fullscreen");
    fullscreenBtn.title = "View fullscreen";

    // Add button to container
    container.style.position = "relative";
    container.appendChild(fullscreenBtn);

    // Button click handler
    fullscreenBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      openOverlay(img.src);
    });

    // Double-click handler
    img.addEventListener("dblclick", () => {
      openOverlay(img.src);
    });

    container.dataset.fullscreenInitialized = "true";
  }

  // Scan for images with data-panzoom-container attribute
  function scanForFullscreenImages() {
    const containers = document.querySelectorAll("[data-panzoom-container]");
    containers.forEach((container) => {
      initFullscreenForImage(container);
    });
  }

  // Initial scan
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", scanForFullscreenImages);
  } else {
    scanForFullscreenImages();
  }

  // Observer to handle dynamically added images
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1) {
          // Element node
          if (node.matches && node.matches("[data-panzoom-container]")) {
            initFullscreenForImage(node);
          }
          // Check children
          const containers = node.querySelectorAll
            ? node.querySelectorAll("[data-panzoom-container]")
            : [];
          containers.forEach((container) => {
            initFullscreenForImage(container);
          });
        }
      });
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
  });
})();
