// onRender callback for leaflet outputs that display an image overlay
// with zoom and pan controls, fit-to-view button, and responsive resizing
// Expects data to contain 'imageUrl' (string)
// Requires buttons with ids 'zoomIn', 'zoomOut', 'fitBtn' in the widget container

// Note: leaflet is usually used for maps with lat-long coordinates,
// but here we use it to display a simple image with pixel coordinates.
// We set the image bounds to [[0,0], [height,width]] so that the top-left
// corner is (0,0) and the bottom-right corner is (width,height).

window.renderLeafletImageOverlay = function (el, x, data) {
  console.log("renderLeafletImageOverlay called with data:", data);
  if (!data || !data.imageUrl) {
    console.error("No imageUrl provided in data");
    return;
  }

  console.log("Leaflet map object:", this);
  console.log("Container element:", el);
  console.log("x:", x);

  const map = this;
  const imageUrl = data.imageUrl;

  if (map.imageOverlayLayer) {
    map.removeLayer(map.imageOverlayLayer);
    map.imageOverlayLayer = null;
  }

  const img = new Image();
  img.onload = function () {
    const width = this.naturalWidth;
    const height = this.naturalHeight;

    console.log("Image loaded:", imageUrl, width, "x", height);

    const bounds = L.latLngBounds([
      [0, 0],
      [height, width],
    ]);

    console.log("Image bounds:", bounds);

    map.imageOverlayLayer = L.imageOverlay(imageUrl, bounds, {
      interactive: true,
    }).addTo(map);

    // Fit and set padded max bounds
    map.fitBounds(bounds, { animate: false });
    const padX = width * 0.1;
    const padY = height * 0.1;
    map.setMaxBounds(
      L.latLngBounds([
        [-padY, -padX],
        [height + padY, width + padX],
      ])
    );

    // --- Zoom helpers ---
    function fitView() {
      map.fitBounds(bounds);
    }

    // Wire buttons once (idempotent)
    function once(id, handler) {
      const btn = el.querySelector(`#${id}`);
      if (!btn) return;
      if (!btn._bound) {
        btn.addEventListener("click", handler);
        btn._bound = true;
      }
    }

    once("zoomIn", () => {
      map.zoomIn(map.options.zoomDelta || 0.25);
    });
    once("zoomOut", () => {
      const next = map.getZoom() - (map.options.zoomDelta || 0.25);
      if (next >= map.options.minZoom) map.setZoom(next);
      else map.setZoom(map.options.minZoom);
    });
    once("fitBtn", () => {
      fitView();
    });

    // When the container is resized (e.g., input$image_width changes),
    // recompute 'fit' and keep center stable
    const resizeObserver = new ResizeObserver(() => {
      // maintain center; re-fit bounds to container size
      const center = map.getCenter();
      const zoom = map.getZoom();
      map.invalidateSize();
      // Option: keep current zoom; or re-fit. Here we keep zoom & center.
      map.setView(center, zoom, { animate: false });
    });
    // observe the widget container
    resizeObserver.observe(el);
  };
  img.src = imageUrl;
};
