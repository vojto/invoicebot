import { ReactNode } from "react"
import { Box, Flex, Text } from "@radix-ui/themes"

export default function PublicLayout({ children }: { children: ReactNode }) {
  return (
    <Box style={{ minHeight: "100vh", backgroundColor: "var(--color-background)" }}>
      <Box asChild>
        <header style={{ backgroundColor: "var(--gray-a2)", borderBottom: "1px solid var(--gray-a5)" }}>
          <Flex width="100%" px="4" py="4" justify="between" align="center">
            <Text size="5" weight="bold" color="blue">Invoicebot</Text>
            <Text size="2" color="gray">Shared accountant access</Text>
          </Flex>
        </header>
      </Box>
      <Box asChild>
        <main>
          <Box width="100%" px="4" py="6">
            {children}
          </Box>
        </main>
      </Box>
    </Box>
  )
}
