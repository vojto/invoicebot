import { Head } from "@inertiajs/react"
import { Heading, Box, Text } from "@radix-ui/themes"

export default function DashboardShow() {
  return (
    <>
      <Head title="Dashboard" />
      <Box>
        <Heading size="5" as="h1" mb="6">
          Dashboard
        </Heading>
        <Text color="gray">
          Welcome to Invoicebot. Your invoice matching features will appear here.
        </Text>
      </Box>
    </>
  )
}
