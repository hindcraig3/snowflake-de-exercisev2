document.addEventListener("DOMContentLoaded", function () {
  var overlay = document.createElement("div");
  overlay.className = "mermaid-overlay";
  overlay.addEventListener("click", function () {
    overlay.classList.remove("mermaid-overlay--active");
  });
  document.body.appendChild(overlay);

  function attachClickHandler(svg) {
    if (svg.dataset.lightbox) return;
    svg.dataset.lightbox = "true";
    svg.style.cursor = "pointer";

    svg.addEventListener("click", function (e) {
      e.stopPropagation();
      var expanded = document.createElement("div");
      expanded.className = "mermaid-expanded";
      expanded.innerHTML = svg.outerHTML;
      var inner = expanded.querySelector("svg");
      if (inner) {
        inner.style.width = "100%";
        inner.style.height = "100%";
        inner.style.maxWidth = "none";
        inner.style.maxHeight = "none";
        inner.removeAttribute("data-lightbox");
        inner.style.cursor = "default";
      }
      overlay.innerHTML = "";
      overlay.appendChild(expanded);
      overlay.classList.add("mermaid-overlay--active");
    });
  }

  // Watch for mermaid SVGs appearing in the DOM
  var observer = new MutationObserver(function () {
    document.querySelectorAll(".mermaid svg:not([data-lightbox])").forEach(attachClickHandler);
  });
  observer.observe(document.body, { childList: true, subtree: true });

  // Also handle SVGs that mermaid renders as replacements (not inside .mermaid)
  // mermaid.js sometimes replaces the div entirely with an SVG
  setInterval(function () {
    document.querySelectorAll("svg[id^='mermaid-']:not([data-lightbox])").forEach(attachClickHandler);
  }, 2000);
});
