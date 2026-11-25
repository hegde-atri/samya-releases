// The landing page's theme picker themes the page and its screenshots, and is
// remembered for the docs. Copy buttons copy the command beside them, and a
// command fades out at the right only while more of it is hidden there. A
// doc's "On this page" marks the section being read.
document.documentElement.classList.add("js");
const root = document.documentElement;
const system = () => (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
const pickers = document.querySelectorAll(".seg [data-pick]");
const show = (theme) => {
  for (const button of pickers) button.setAttribute("aria-checked", button.dataset.pick === theme);
  for (const img of document.querySelectorAll("img[data-shot]")) {
    img.previousElementSibling?.remove();
    img.src = `/shots/${img.dataset.shot}-${theme}.webp`;
  }
};
if (pickers.length) {
  if (root.dataset.theme) show(root.dataset.theme);
  else for (const button of pickers) button.setAttribute("aria-checked", button.dataset.pick === system());
  for (const button of pickers)
    button.onclick = () => {
      const theme = button.dataset.pick;
      root.dataset.theme = theme;
      try { localStorage.setItem("theme", theme); } catch {}
      show(theme);
    };
}
for (const button of document.querySelectorAll(".copy")) {
  button.onclick = () =>
    navigator.clipboard.writeText(button.nextElementSibling.textContent.trim()).then(() => {
      button.textContent = "Copied";
      setTimeout(() => (button.textContent = "Copy"), 1500);
    });
}
const fades = [...document.querySelectorAll(".cmd pre")];
const fade = () => {
  for (const pre of fades) {
    pre.classList.toggle("overflow-right", pre.scrollWidth - pre.clientWidth - pre.scrollLeft > 2);
  }
};
for (const pre of fades) pre.addEventListener("scroll", fade, { passive: true });
addEventListener("resize", fade);
fade();
const marks = [...document.querySelectorAll(".toc a")];
const heads = marks.map((a) => document.getElementById(decodeURIComponent(a.hash.slice(1))));
const spy = () => {
  const end = innerHeight + scrollY >= document.documentElement.scrollHeight - 2;
  let at = 0;
  heads.forEach((h, i) => { if (h && h.getBoundingClientRect().top < 120) at = i; });
  if (end) at = heads.length - 1;
  marks.forEach((a, i) => (i === at ? a.setAttribute("aria-current", "location") : a.removeAttribute("aria-current")));
};
if (marks.length) {
  addEventListener("scroll", spy, { passive: true });
  spy();
}
