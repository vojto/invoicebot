import { ReactNode } from "react"
import { Link, router, usePage } from "@inertiajs/react"
import { Button, Box, Flex, Text } from "@radix-ui/themes"
import { z } from "zod"

const UserSchema = z.object({
  id: z.number(),
  email: z.string(),
  name: z.string(),
  picture_url: z.string(),
})

const PagePropsSchema = z.object({
  user: UserSchema.nullable().optional(),
  signed_in: z.boolean().optional(),
})

type PageProps = z.infer<typeof PagePropsSchema>

export default function DefaultLayout({ children }: { children: ReactNode }) {
  const { props } = usePage()
  const { user, signed_in } = PagePropsSchema.parse(props)

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
            style={{ maxWidth: "1400px" }}
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
          <Box className="mx-auto" style={{ maxWidth: "1400px" }} px="4" py="8">
            {children}
          </Box>
        </main>
      </Box>
    </Box>
  )
}
