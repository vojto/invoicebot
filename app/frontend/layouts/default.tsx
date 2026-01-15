import { ReactNode } from "react"
import { Link, router, usePage } from "@inertiajs/react"
import { Button, Box, Flex, Text } from "@radix-ui/themes"

interface User {
  id: number
  email: string
  name: string
  picture_url: string
}

interface PageProps {
  user?: User | null
  signed_in?: boolean
  [key: string]: unknown
}

export default function DefaultLayout({ children }: { children: ReactNode }) {
  const { props } = usePage<PageProps>()
  const { user, signed_in } = props

  const handleLogout = () => {
    router.visit("/logout")
  }

  return (
    <Box style={{ minHeight: "100vh", backgroundColor: "var(--color-background)" }}>
      {/* Header */}
      <Box asChild>
        <header style={{ backgroundColor: "var(--gray-a2)", borderBottom: "1px solid var(--gray-a5)" }}>
          <Flex
            className="mx-auto"
            style={{ maxWidth: "1000px" }}
            px="4"
            py="4"
            justify="between"
            align="center"
          >
            {/* Logo */}
            <Link
              href="/"
              style={{
                fontSize: "var(--font-size-5)",
                fontWeight: "var(--font-weight-semibold)",
                color: "var(--accent-11)",
                textDecoration: "none"
              }}
            >
              Invoicebot
            </Link>

            {/* User info and logout button */}
            {signed_in && user && (
              <Flex align="center" gap="4">
                <Box style={{ textAlign: "right" }}>
                  <Text as="p" size="2" weight="medium" style={{ color: "var(--gray-12)" }}>
                    {user.name}
                  </Text>
                  <Text as="p" size="1" style={{ color: "var(--gray-11)" }}>
                    {user.email}
                  </Text>
                </Box>
                <Button variant="soft" onClick={handleLogout}>
                  Logout
                </Button>
              </Flex>
            )}
          </Flex>
        </header>
      </Box>

      {/* Main content */}
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
