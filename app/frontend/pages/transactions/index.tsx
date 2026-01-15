import { Head, Link } from "@inertiajs/react"
import { Heading, Box, Text, Button, Flex, Table } from "@radix-ui/themes"
import { PlusIcon } from "@radix-ui/react-icons"
import { z } from "zod"

const TransactionSchema = z.object({
  id: z.number(),
  booking_date: z.string().nullable(),
  amount_cents: z.number(),
  currency: z.string().nullable(),
  creditor_name: z.string().nullable(),
  debtor_name: z.string().nullable(),
  description: z.string().nullable(),
  bank_name: z.string().nullable(),
})

type Transaction = z.infer<typeof TransactionSchema>

const PropsSchema = z.object({
  transactions: z.array(TransactionSchema),
})

type Props = z.infer<typeof PropsSchema>

function getMonthKey(dateString: string | null | undefined): string {
  if (!dateString) return "unknown"
  const date = new Date(dateString)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
}

function formatMonthHeading(monthKey: string): string {
  if (monthKey === "unknown") return "Unknown Date"
  const [year, month] = monthKey.split("-")
  const date = new Date(parseInt(year), parseInt(month) - 1, 1)
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
  }).format(date)
}

function groupTransactionsByMonth(transactions: Transaction[]): Map<string, Transaction[]> {
  const groups = new Map<string, Transaction[]>()

  for (const tx of transactions) {
    const key = getMonthKey(tx.booking_date)
    const existing = groups.get(key) || []
    existing.push(tx)
    groups.set(key, existing)
  }

  // Sort transactions within each group (newest first)
  for (const [key, groupTx] of groups) {
    groupTx.sort((a, b) => {
      if (!a.booking_date) return 1
      if (!b.booking_date) return -1
      return new Date(b.booking_date).getTime() - new Date(a.booking_date).getTime()
    })
    groups.set(key, groupTx)
  }

  // Sort groups by month key (newest first)
  const sortedEntries = [...groups.entries()].sort((a, b) => {
    if (a[0] === "unknown") return 1
    if (b[0] === "unknown") return -1
    return b[0].localeCompare(a[0])
  })

  return new Map(sortedEntries)
}

function formatAmount(amountCents: number, currency: string | null): string {
  const amount = amountCents / 100
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency || "EUR",
  }).format(amount)
}

function formatDate(dateString: string | null): string {
  if (!dateString) return "-"
  const date = new Date(dateString)
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  }).format(date)
}

export default function TransactionsIndex(props: Props) {
  const { transactions } = PropsSchema.parse(props)
  const groupedTransactions = groupTransactionsByMonth(transactions)

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

        {transactions.length === 0 ? (
          <Text color="gray">
            No transactions found. Connect a bank account to see your transactions.
          </Text>
        ) : (
          <Flex direction="column" gap="6">
            {[...groupedTransactions.entries()].map(([monthKey, monthTransactions]) => (
              <Box key={monthKey}>
                <Heading size="5" as="h2" mb="4">
                  {formatMonthHeading(monthKey)}
                </Heading>
                <Table.Root variant="surface" size="2">
                  <Table.Header>
                    <Table.Row>
                      <Table.ColumnHeaderCell width="110px">Bank</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="110px">Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="110px">Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="200px">From / To</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Description</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {monthTransactions.map((tx) => (
                      <Table.Row key={tx.id}>
                        <Table.Cell>{tx.bank_name}</Table.Cell>
                        <Table.Cell>{formatDate(tx.booking_date)}</Table.Cell>
                        <Table.Cell>
                          <Text color={tx.amount_cents >= 0 ? "green" : undefined}>
                            {formatAmount(tx.amount_cents, tx.currency)}
                          </Text>
                        </Table.Cell>
                        <Table.Cell>
                          {tx.amount_cents >= 0 ? tx.debtor_name : tx.creditor_name}
                        </Table.Cell>
                        <Table.Cell>
                          <Text size="1" color="gray" className="line-clamp-3">
                            {tx.description}
                          </Text>
                        </Table.Cell>
                      </Table.Row>
                    ))}
                  </Table.Body>
                </Table.Root>
              </Box>
            ))}
          </Flex>
        )}
      </Box>
    </>
  )
}
