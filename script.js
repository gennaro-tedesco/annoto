(() => {
  // ── Theme toggle ──────────────────────────────────────
  const root = document.documentElement;
  const toggle = document.getElementById("theme-toggle");

  const saved =
    localStorage.getItem("theme") ??
    (window.matchMedia("(prefers-color-scheme: light)").matches
      ? "light"
      : "dark");

  const apply = (theme) => {
    root.setAttribute("data-theme", theme);
    toggle.textContent = theme === "dark" ? "☀️" : "🌙";
    localStorage.setItem("theme", theme);
  };

  apply(saved);

  toggle.addEventListener("click", () => {
    apply(root.getAttribute("data-theme") === "dark" ? "light" : "dark");
  });

  // ── Scroll reveal ─────────────────────────────────────
  const observer = new IntersectionObserver(
    (entries) =>
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("visible");
          observer.unobserve(e.target);
        }
      }),
    { threshold: 0.12 },
  );

  document.querySelectorAll(".reveal").forEach((el) => observer.observe(el));
})();
