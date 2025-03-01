import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
// import App from "./App";
import Voting from "./pages/Voting";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {/* <App /> */}
    <Voting />
  </StrictMode>
);
