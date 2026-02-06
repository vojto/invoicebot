import { Head, Link, router } from "@inertiajs/react"
import { Heading, Box, Text, Button, Flex, Table } from "@radix-ui/themes"
import { PlusIcon } from "@radix-ui/react-icons"
import { z } from "zod"
import BankSyncStatusList, { BankSyncStatusSchema } from "../../components/BankSyncStatusList"

const TransactionSchema = z.object({
  id: z.number(),
  booking_date: z.string().nullable(),
  amount_cents: z.number(),
  currency: z.string().nullable(),
  original_amount_cents: z.number().nullable(),
  original_currency: z.string().nullable(),
  vendor_name: z.string().nullable(),
  creditor_name: z.string().nullable(),
  debtor_name: z.string().nullable(),
  description: z.string().nullable(),
  bank_name: z.string().nullable(),
  hidden_at: z.string().nullable(),
})

type Transaction = z.infer<typeof TransactionSchema>

const PropsSchema = z.object({
  transactions: z.array(TransactionSchema),
  bank_sync_statuses: z.array(BankSyncStatusSchema),
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
  const { transactions, bank_sync_statuses } = PropsSchema.parse(props)
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
        <BankSyncStatusList bankSyncStatuses={bank_sync_statuses} />

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
                      <Table.ColumnHeaderCell width="140px">Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Original</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="100px">Actions</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {monthTransactions.map((tx) => {
                      const isHidden = !!tx.hidden_at
                      const hiddenClass = isHidden ? "line-through opacity-40" : ""

                      return (
                        <Table.Row key={tx.id}>
                          <Table.Cell className="!align-middle"><span className={hiddenClass}>{tx.bank_name}</span></Table.Cell>
                          <Table.Cell className="!align-middle"><span className={hiddenClass}>{formatDate(tx.booking_date)}</span></Table.Cell>
                          <Table.Cell className="!align-middle">
                            <Text className={hiddenClass} color={isHidden ? "gray" : (tx.amount_cents >= 0 ? "green" : undefined)}>
                              {formatAmount(tx.amount_cents, tx.currency)}
                            </Text>
                          </Table.Cell>
                          <Table.Cell className="!align-middle">
                            <span className={hiddenClass}>
                              {tx.original_currency && tx.original_amount_cents
                                ? formatAmount(tx.original_amount_cents, tx.original_currency)
                                : "—"}
                            </span>
                          </Table.Cell>
                          <Table.Cell className="!align-middle"><span className={hiddenClass}>{tx.vendor_name}</span></Table.Cell>
                          <Table.Cell className="!align-middle">
                            {isHidden ? (
                              <Button
                                size="1"
                                variant="ghost"
                                onClick={() => router.post(`/transactions/${tx.id}/restore`)}
                              >
                                Restore
                              </Button>
                            ) : (
                              <Button
                                size="1"
                                variant="ghost"
                                color="red"
                                onClick={() => router.post(`/transactions/${tx.id}/hide`)}
                              >
                                Hide
                              </Button>
                            )}
                          </Table.Cell>
                        </Table.Row>
                      )
                    })}
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
