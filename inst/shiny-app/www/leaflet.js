// onRender callback for leaflet outputs that display an image overlay
// with zoom and pan controls, fit-to-view button, and responsive resizing
// Expects data to contain 'imageUrl' (string)
// Requires buttons with ids 'zoomIn', 'zoomOut', 'fitBtn' in the widget container

// Note: leaflet is usually used for maps with lat-long coordinates,
// but here we use it to display a simple image with pixel coordinates.
// We set the image bounds to [[0,0], [height,width]] so that the top-left
// corner is (0,0) and the bottom-right corner is (width,height).

window.renderLeafletImageOverlay = (function () {
  const voteImageState = {
    maps: {},
    pending: {},
  };

  function ensureStateEntry(id) {
    if (!voteImageState.maps[id]) {
      voteImageState.maps[id] = null;
    }
  }

  function applyOverlay(map, el, imageUrl) {
    if (!map || !el || !imageUrl) {
      return;
    }

    if (map.imageOverlayLayer) {
      map.removeLayer(map.imageOverlayLayer);
      map.imageOverlayLayer = null;
    }

    const img = new Image();
    img.onload = function () {
      const width = this.naturalWidth;
      const height = this.naturalHeight;

      const bounds = L.latLngBounds([
        [0, 0],
        [height, width],
      ]);

      map.imageOverlayLayer = L.imageOverlay(imageUrl, bounds, {
        interactive: true,
      }).addTo(map);

      map.fitBounds(bounds, { animate: false });
      const padX = width * 0.1;
      const padY = height * 0.1;
      map.setMaxBounds(
        L.latLngBounds([
          [-padY, -padX],
          [height + padY, width + padX],
        ])
      );

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
        map.fitBounds(bounds);
      });

      if (!map._voteImageResizeObserver) {
        map._voteImageResizeObserver = new ResizeObserver(() => {
          const center = map.getCenter();
          const zoom = map.getZoom();
          map.invalidateSize();
          map.setView(center, zoom, { animate: false });
        });
        map._voteImageResizeObserver.observe(el);
      }
    };
    img.src = imageUrl;
  }

  function registerMap(id, map, el) {
    voteImageState.maps[id] = { map, el };
    if (voteImageState.pending[id]) {
      const imageUrl = voteImageState.pending[id];
      delete voteImageState.pending[id];
      applyOverlay(map, el, imageUrl);
    }
  }

  function setOverlay(id, imageUrl) {
    ensureStateEntry(id);
    const entry = voteImageState.maps[id];
    if (entry) {
      applyOverlay(entry.map, entry.el, imageUrl);
    } else {
      voteImageState.pending[id] = imageUrl;
    }
  }

  if (typeof Shiny !== "undefined" && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler("voteImage:setOverlay", (message) => {
      if (!message || !message.outputId) {
        return;
      }
      setOverlay(message.outputId, message.imageUrl);
    });
  }

  return function (el, x, data) {
    const map = this;
    const id = el.id;
    registerMap(id, map, el);
    if (data && data.imageUrl) {
      setOverlay(id, data.imageUrl);
    }
  };
})();
