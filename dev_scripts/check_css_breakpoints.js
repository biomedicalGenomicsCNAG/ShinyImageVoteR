// put the following in the browser console to test media querie

const QUERY = "(max-width:1400px)";
console.log("media query:", QUERY);
const mq = window.matchMedia(QUERY);
const label = m => (m ? "smaller max-width" : "greater max-width");

console.log("now:", label(mq.matches));
const onChange = e => console.log(label(e.matches));
mq.addEventListener("change", onChange);