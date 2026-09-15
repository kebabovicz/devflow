import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  // No StrictMode: its double-invoked effects would attach to a session twice.
  <App />,
);
