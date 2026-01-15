import { ReactNode } from "react"
import { Box } from "@radix-ui/themes"

export default function DefaultLayout({ children }: { children: ReactNode }) {
  return (
    <Box style={{ minHeight: "100vh", backgroundColor: "var(--color-background)" }}>
      <Box asChild>
        <main style={{ width: "100%", backgroundColor: "var(--color-background)" }}>
          <Box className="mx-auto" style={{ maxWidth: "1000px" }} px="4" py="8">
            {children}
          </Box>
        </main>
      </Box>
    </Box>
  )
}
