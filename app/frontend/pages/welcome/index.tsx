import { Head } from "@inertiajs/react"
import { Box, Heading, Text } from "@radix-ui/themes"

export default function WelcomeIndex() {
  return (
    <>
      <Head title="Welcome" />
      <Box>
        <Heading size="7" as="h1" mb="4">
          Welcome to Invoicebot
        </Heading>
        <Text size="3" color="gray">
          Your application is ready to go.
        </Text>
      </Box>
    </>
  )
}
