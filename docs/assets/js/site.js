/* Nebula site — shared chrome.
   The sidebar, breadcrumb, prev/next links and search index are all built from
   NAV below, so adding a page means adding one entry here and one HTML file. */

const NAV = [
  {
    group: "Introduction",
    open: true,
    items: [
      { href: "index.html",   title: "Overview",   blurb: "What Nebula is and what it ships with." },
      { href: "showcase.html", title: "Showcase",  blurb: "Screenshots of the shell in use." },
    ],
  },
  {
    group: "Getting started",
    open: true,
    items: [
      { href: "install.html",      title: "Install",         blurb: "The one-line installer, what it does, and installing by hand." },
      { href: "hyprland.html",     title: "Hyprland setup",  blurb: "Autostart and environment variables, in conf and Lua syntax." },
      { href: "keybindings.html",  title: "Keybindings",     blurb: "Every global shortcut the shell registers." },
      { href: "dependencies.html", title: "Dependencies",    blurb: "Pacman and AUR packages, the Python venv, optional extras." },
    ],
  },
  {
    group: "Using Nebula",
    open: true,
    items: [
      { href: "launcher.html", title: "Launcher",      blurb: "Five modes behind one window, selected by prefix." },
      { href: "widgets.html",  title: "Widget canvas", blurb: "The widget screen and the widgets you can place on it." },
      { href: "settings.html", title: "Settings",      blurb: "The settings panel and where its state is stored." },
    ],
  },
  {
    group: "Going further",
    open: true,
    items: [
      { href: "theming.html", title: "Theming other apps", blurb: "Rendering the palette into btop, kitty, GTK, waybar and more." },
      { href: "filedrop.html", title: "Phone", blurb: "Files, links and clipboard to and from your phone with KDE Connect." },
      { href: "troubleshooting.html", title: "Troubleshooting", blurb: "Known failure modes and how to get out of them." },
    ],
  },
];

const REPO = "https://github.com/iamSt3el/Nebula";

const ICON = {
  chev: '<svg class="chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M7.4 8.6 12 13.2l4.6-4.6L18 10l-6 6-6-6z"/></svg>',
  github: '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.4 7.4 0 0 1 2-.27c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>',
  menu: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18v2H3V6zm0 5h18v2H3v-2zm0 5h18v2H3v-2z"/></svg>',
  search: '<svg viewBox="0 0 24 24" aria-hidden="true" style="width:15px;height:15px;fill:currentColor"><path d="M15.5 14h-.79l-.28-.27a6.5 6.5 0 1 0-.7.7l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0A4.5 4.5 0 1 1 14 9.5 4.5 4.5 0 0 1 9.5 14z"/></svg>',
  info: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>',
  warn: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>',
  left: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15.4 7.4 14 6l-6 6 6 6 1.4-1.4-4.6-4.6z"/></svg>',
  right: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8.6 16.6 10 18l6-6-6-6-1.4 1.4 4.6 4.6z"/></svg>',
};

const flat = NAV.flatMap(g => g.items);
const here = location.pathname.split("/").pop() || "index.html";

/* ── top bar ──────────────────────────────────────────────────────── */

function topbar() {
  const el = document.createElement("header");
  el.className = "topbar";
  el.innerHTML = `
    <button class="iconbtn navtoggle" type="button" aria-label="Open navigation"
            aria-expanded="false">${ICON.menu}</button>
    <a class="brand" href="index.html">
      <img src="assets/img/logo.png" alt="" width="26" height="26">Nebula
    </a>
    <span class="spacer"></span>
    <button class="searchbtn" type="button" id="searchOpen" aria-label="Search the documentation">
      ${ICON.search}<span class="lbl">Search</span><span class="k">Ctrl K</span>
    </button>
    <a class="iconbtn" href="${REPO}" aria-label="Nebula on GitHub"
       rel="noopener">${ICON.github}</a>`;
  const skip = document.querySelector('.skip');
  if (skip) skip.after(el); else document.body.prepend(el);
}

/* ── sidebar ──────────────────────────────────────────────────────── */

function sidebar() {
  const host = document.querySelector(".sidebar");
  if (!host) return;

  host.innerHTML = NAV.map(g => {
    const holdsCurrent = g.items.some(i => i.href === here);
    const open = g.open !== false || holdsCurrent;
    const items = g.items.map(i => `
      <li><a href="${i.href}"${i.href === here ? ' aria-current="page"' : ""}>${i.title}
        ${i.tag ? `<span class="tag ${i.tag}">${i.tagText || i.tag}</span>` : ""}</a></li>`).join("");
    return `<div class="navgroup" data-open="${open}">
        <button type="button" aria-expanded="${open}">${g.group}${ICON.chev}</button>
        <ul>${items}</ul>
      </div>`;
  }).join("");

  host.addEventListener("click", e => {
    const b = e.target.closest(".navgroup > button");
    if (!b) return;
    const g = b.parentElement;
    const open = g.dataset.open !== "true";
    g.dataset.open = String(open);
    b.setAttribute("aria-expanded", String(open));
  });

  const toggle = document.querySelector(".navtoggle");
  if (!toggle) return;
  let scrim = null;
  const close = () => {
    host.dataset.open = "false";
    toggle.setAttribute("aria-expanded", "false");
    scrim?.remove();
    scrim = null;
  };
  toggle.addEventListener("click", () => {
    const open = host.dataset.open !== "true";
    if (!open) return close();
    host.dataset.open = "true";
    toggle.setAttribute("aria-expanded", "true");
    scrim = document.createElement("button");
    scrim.className = "scrim";
    scrim.setAttribute("aria-label", "Close navigation");
    scrim.addEventListener("click", close);
    document.body.append(scrim);
  });
  host.addEventListener("click", e => { if (e.target.closest("a")) close(); });
  addEventListener("keydown", e => { if (e.key === "Escape" && scrim) close(); });
}

/* ── on this page ─────────────────────────────────────────────────── */

function toc() {
  const host = document.querySelector(".toc");
  const article = document.querySelector(".content");
  if (!host || !article) return;

  const heads = [...article.querySelectorAll("h2, h3")].filter(h => h.textContent.trim());
  if (heads.length < 2) { host.remove(); return; }

  heads.forEach((h, i) => { if (!h.id) h.id = slug(h.textContent) || `h-${i}`; });
  host.innerHTML = `<b>On this page</b><ul>${heads.map(h =>
    `<li><a href="#${h.id}" class="${h.tagName === "H3" ? "sub" : ""}">${h.textContent}</a></li>`
  ).join("")}</ul>`;

  const links = new Map([...host.querySelectorAll("a")].map(a => [a.hash.slice(1), a]));
  let active = null;
  const io = new IntersectionObserver(entries => {
    for (const e of entries) if (e.isIntersecting) {
      active?.classList.remove("on");
      active = links.get(e.target.id);
      active?.classList.add("on");
      break;
    }
  }, { rootMargin: "-72px 0px -72% 0px", threshold: 0 });
  heads.forEach(h => io.observe(h));
}

const slug = s => s.toLowerCase().trim()
  .replace(/[^\w\s-]/g, "").replace(/\s+/g, "-").replace(/-+/g, "-");

/* ── breadcrumb + prev / next ─────────────────────────────────────── */

function pagenav() {
  const article = document.querySelector(".content");
  if (!article || here === "index.html") return;

  const idx = flat.findIndex(i => i.href === here);
  const group = NAV.find(g => g.items.some(i => i.href === here));
  const crumb = article.querySelector(".crumb");
  if (crumb && group) {
    crumb.innerHTML = `<a href="index.html">Nebula</a> / ${group.group} / ${flat[idx]?.title ?? ""}`;
  }
  if (idx < 0) return;

  const prev = flat[idx - 1], next = flat[idx + 1];
  if (!prev && !next) return;
  const el = document.createElement("nav");
  el.className = "pagenav";
  el.setAttribute("aria-label", "Previous and next page");
  el.innerHTML =
    (prev ? `<a href="${prev.href}"><span class="dir">Previous</span><b>${prev.title}</b></a>` : "") +
    (next ? `<a class="next" href="${next.href}"><span class="dir">Next</span><b>${next.title}</b></a>` : "");
  article.append(el);
}

/* ── search ───────────────────────────────────────────────────────── */

function search() {
  const open = document.getElementById("searchOpen");
  if (!open) return;

  const dlg = document.createElement("dialog");
  dlg.className = "search";
  dlg.innerHTML = `
    <input type="search" placeholder="Search pages and sections" aria-label="Search">
    <div class="results" role="listbox"></div>`;
  document.body.append(dlg);

  const input = dlg.querySelector("input");
  const list = dlg.querySelector(".results");

  // Pages, plus this page's own headings — enough to jump around without an
  // index build step. Cross-page heading search would need one.
  const entries = flat.map(i => ({ href: i.href, title: i.title, sub: i.blurb }));
  document.querySelectorAll(".content h2, .content h3").forEach(h => {
    if (h.id) entries.push({ href: `#${h.id}`, title: h.textContent, sub: "On this page" });
  });

  let hits = [], sel = 0;

  const render = () => {
    if (!hits.length) {
      list.innerHTML = `<p class="empty">No page matches that. Try “install”, “keybind” or “theme”.</p>`;
      return;
    }
    list.innerHTML = hits.map((h, i) =>
      `<a href="${h.href}" class="${i === sel ? "on" : ""}" role="option"
          aria-selected="${i === sel}"><b>${h.title}</b><span>${h.sub}</span></a>`).join("");
  };

  const run = () => {
    const q = input.value.trim().toLowerCase();
    hits = !q ? entries.slice(0, 8)
      : entries.filter(e => (e.title + " " + e.sub).toLowerCase().includes(q)).slice(0, 10);
    sel = 0;
    render();
  };

  const show = () => { dlg.showModal(); input.value = ""; run(); input.focus(); };
  open.addEventListener("click", show);
  addEventListener("keydown", e => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") { e.preventDefault(); show(); }
  });

  input.addEventListener("input", run);
  input.addEventListener("keydown", e => {
    if (e.key === "ArrowDown") { e.preventDefault(); sel = Math.min(sel + 1, hits.length - 1); render(); }
    else if (e.key === "ArrowUp") { e.preventDefault(); sel = Math.max(sel - 1, 0); render(); }
    else if (e.key === "Enter" && hits[sel]) { e.preventDefault(); location.href = hits[sel].href; dlg.close(); }
  });
  dlg.addEventListener("click", e => { if (e.target === dlg) dlg.close(); });
}

/* ── code copy buttons ────────────────────────────────────────────── */

function copyButtons() {
  document.querySelectorAll(".code").forEach(box => {
    const pre = box.querySelector("pre");
    if (!pre || box.querySelector(".copy")) return;
    const b = document.createElement("button");
    b.type = "button";
    b.className = "copy";
    b.textContent = "Copy";
    b.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(pre.innerText.replace(/^\$ /gm, ""));
        b.textContent = "Copied";
      } catch { b.textContent = "Copy failed"; }
      setTimeout(() => (b.textContent = "Copy"), 1800);
    });
    box.append(b);
  });

  const one = document.querySelector(".cmd button");
  if (one) one.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(one.previousElementSibling.innerText.replace(/^\$ /, ""));
      one.textContent = "Copied";
    } catch { one.textContent = "Copy failed"; }
    setTimeout(() => (one.textContent = "Copy"), 1800);
  });
}

/* ── go ───────────────────────────────────────────────────────────── */

topbar();
sidebar();
toc();
pagenav();
search();
copyButtons();
