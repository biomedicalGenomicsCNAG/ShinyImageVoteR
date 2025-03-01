import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
// import App from "./App";
import Voting from "./pages/Voting";
import "./index.css";

import { 
  QueryClient, 
  QueryClientProvider 
} from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

const queryClient = new QueryClient();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <ReactQueryDevtools />
      <Voting />
    </QueryClientProvider>
  </StrictMode>
);
