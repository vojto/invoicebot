import { createInertiaApp } from "@inertiajs/react"
import { type ReactNode, createElement } from "react"
import { createRoot } from "react-dom/client"
import { Theme } from "@radix-ui/themes"
import DefaultLayout from "../layouts/default"

import "@radix-ui/themes/styles.css"

interface ResolvedComponent {
  default: ReactNode & { layout?: (page: ReactNode) => ReactNode }
}

const appName = (import.meta.env.VITE_APP_NAME ?? "Invoicebot") as string

void createInertiaApp({
  title: (title) => `${title} - ${appName}`,

  resolve: (name) => {
    const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.tsx", {
      eager: true,
    })
    const page = pages[`../pages/${name}.tsx`]
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.tsx'`)
    }

    page.default.layout ??= (page) => createElement(DefaultLayout, null, page)

    return page
  },

  setup({ el, App, props }) {
    createRoot(el).render(
      createElement(
        Theme,
        {
          accentColor: "blue",
          grayColor: "slate",
          appearance: "light",
          panelBackground: "solid",
          radius: "medium",
        },
        createElement(App, props)
      )
    )
  },
}).catch((error) => {
  if (document.getElementById("app")) {
    throw error
  } else {
    console.error(
      "Missing root element.\n\n" +
        "If you see this error, it probably means you loaded Inertia.js on non-Inertia pages.\n" +
        'Consider moving <%= vite_typescript_tag "inertia" %> to the Inertia-specific layout instead.',
    )
  }
})
