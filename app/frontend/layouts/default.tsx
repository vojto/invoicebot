import { ReactNode } from "react"
import { Link, router, usePage } from "@inertiajs/react"
import { Button, Box, Callout, Flex, Text } from "@radix-ui/themes"
import { z } from "zod"
import Nav from "../components/Nav"

const UserSchema = z.object({
  id: z.number(),
  email: z.string(),
  name: z.string(),
  picture_url: z.string(),
})

const FlashSchema = z.object({
  notice: z.string().optional(),
  alert: z.string().optional(),
})

const PagePropsSchema = z.object({
  user: UserSchema.nullable().optional(),
  signed_in: z.boolean().optional(),
  flash: FlashSchema.optional(),
})

type PageProps = z.infer<typeof PagePropsSchema>

function FlashMessage({ flash }: { flash?: PageProps["flash"] }) {
  if (flash?.alert) {
    return (
      <Callout.Root color="red" mb="4">
        <Callout.Text>{flash.alert}</Callout.Text>
      </Callout.Root>
    )
  }

  if (flash?.notice) {
    return (
      <Callout.Root color="green" mb="4">
        <Callout.Text>{flash.notice}</Callout.Text>
      </Callout.Root>
    )
  }

  return null
}

export default function DefaultLayout({ children }: { children: ReactNode }) {
  const { props } = usePage()
  const { user, signed_in, flash } = PagePropsSchema.parse(props)

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
            {/* Logo and Navigation */}
            <Flex align="center" gap="6">
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
              {signed_in && <Nav />}
            </Flex>

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
            <FlashMessage flash={flash} />
            {children}
          </Box>
        </main>
      </Box>
    </Box>
  )
}
