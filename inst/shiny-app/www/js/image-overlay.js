(function () {
  const activeClass = "is-active";
  const bodyOpenClass = "overlay-open";

  const openOverlay = (overlay, image) => {
    if (!overlay || !image) return;
    const overlayImg = overlay.querySelector("[data-overlay-image]");
    if (!overlayImg) return;
    overlayImg.src = image.src;
    overlayImg.alt = image.alt || "Fullscreen image";
    overlay.classList.add(activeClass);
    overlay.setAttribute("aria-hidden", "false");
    document.body.classList.add(bodyOpenClass);
  };

  const closeOverlay = (overlay) => {
    if (!overlay) return;
    overlay.classList.remove(activeClass);
    overlay.setAttribute("aria-hidden", "true");
    document.body.classList.remove(bodyOpenClass);
  };

  const handleToggleClick = (event) => {
    const toggle = event.target.closest(".image-overlay-toggle");
    if (!toggle) return;
    event.preventDefault();
    const overlayId = toggle.dataset.overlayTarget;
    const imageId = toggle.dataset.overlayImage;
    const overlay = overlayId ? document.getElementById(overlayId) : null;
    const image = imageId ? document.getElementById(imageId) : null;
    openOverlay(overlay, image);
  };

  const handleOverlayClick = (event) => {
    const overlay = event.target.closest("[data-image-overlay]");
    if (!overlay) return;
    if (event.target.matches(".image-overlay-close")) {
      closeOverlay(overlay);
      return;
    }
    if (event.target === overlay) {
      closeOverlay(overlay);
    }
  };

  const handleImageDoubleClick = (event) => {
    const image = event.target.closest("[data-image-overlay-image]");
    if (!image) return;
    const overlayId = image.dataset.overlayTarget;
    const overlay = overlayId ? document.getElementById(overlayId) : null;
    openOverlay(overlay, image);
  };

  const handleEscape = (event) => {
    if (event.key !== "Escape") return;
    document
      .querySelectorAll("[data-image-overlay]." + activeClass)
      .forEach((overlay) => closeOverlay(overlay));
  };

  document.addEventListener("click", handleToggleClick);
  document.addEventListener("click", handleOverlayClick);
  document.addEventListener("dblclick", handleImageDoubleClick);
  document.addEventListener("keydown", handleEscape);
})();
