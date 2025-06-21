// document.addEventListener("DOMContentLoaded", () => {
//   console.log("DMContentLoaded");

//   // Prevent the browser's back button from navigating away
//   // by pushing a fake state into the history stack
//   history.pushState(null, null, location.href); // Add a fake history state

//   window.onpopstate = () => {
//     // Prevent actual browser navigation

//     console.log("onpopstate event triggered");
//     history.pushState(null, null, location.href);

//     // Send signal to Shiny that back was pressed
//     Shiny.setInputValue("back_button_pressed", new Date().getTime());
//   };
// });

(() => {
  // 1) set an initial hash
  location.replace(location.pathname + "#state1");
  // 2) push a different hash
  location.hash = "state2";

  window.addEventListener("hashchange", () => {
    if (location.hash === "#state1") {
      console.log("Back (hash) pressed!");
      Shiny.setInputValue("back_button_pressed", new Date().getTime());
      // go forward again
      location.hash = "state2";
    }
  });
})();
