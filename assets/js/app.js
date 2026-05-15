import { Socket } from "../../deps/phoenix/priv/static/phoenix.mjs";
import { LiveSocket } from "../../deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

const Hooks = {}

Hooks.ThemeToggle = {
  mounted() {
    const theme = localStorage.getItem("theme")
    if (theme === "dark" || (!theme && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
      document.documentElement.classList.add("dark")
    }
    this.el.addEventListener("click", () => {
      document.documentElement.classList.toggle("dark")
      const isDark = document.documentElement.classList.contains("dark")
      localStorage.setItem("theme", isDark ? "dark" : "light")
    })
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket
