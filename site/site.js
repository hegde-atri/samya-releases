// The theme showcase starts on the visitor's own theme, Copy buttons copy the
// command beside them, and a command fades out at the right only while more of
// it is hidden there.
if (matchMedia("(prefers-color-scheme: light)").matches) {
  const light = document.getElementById("t-light");
  if (light) light.checked = true;
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
