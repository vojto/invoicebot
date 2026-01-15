import { Head, Link } from "@inertiajs/react"
import { Heading, Box, Text, Button, Flex } from "@radix-ui/themes"
import { PlusIcon } from "@radix-ui/react-icons"

export default function TransactionsIndex() {
  return (
    <>
      <Head title="Transactions" />
      <Box>
        <Flex justify="between" align="center" mb="4">
          <Heading size="6">Transactions</Heading>
          <Button asChild>
            <Link href="/banks">
              <PlusIcon />
              Connect Bank Account
            </Link>
          </Button>
        </Flex>
        <Text color="gray">
          Bank transactions will appear here once you connect a bank account.
        </Text>
      </Box>
    </>
  )
}
