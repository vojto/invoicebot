import { Head, Link, router } from "@inertiajs/react"
import { Heading, Box, Text, Button, Flex, Table } from "@radix-ui/themes"
import { CheckIcon, FileTextIcon, PlusIcon } from "@radix-ui/react-icons"
import { z } from "zod"
import InvoiceSelector from "../../components/InvoiceSelector"

const TransactionSchema = z.object({
  id: z.number(),
  invoice_id: z.number().nullable(),
  invoice: z
    .object({
      id: z.number(),
      label: z.string(),
    })
    .nullable(),
  direction: z.enum(["inflow", "outflow"]),
  booking_date_label: z.string(),
  amount_cents: z.number(),
  amount_label: z.string(),
  original_amount_label: z.string(),
  vendor_name: z.string().nullable(),
  bank_name: z.string().nullable(),
  hidden_at: z.string().nullable(),
})

type Transaction = z.infer<typeof TransactionSchema>

const TransactionGroupSchema = z.object({
  month_key: z.string(),
  month_label: z.string(),
  transactions: z.array(TransactionSchema),
})

type TransactionGroup = z.infer<typeof TransactionGroupSchema>

const PropsSchema = z.object({
  transaction_groups: z.array(TransactionGroupSchema),
})

type Props = z.infer<typeof PropsSchema>

export default function TransactionsIndex(props: Props) {
  const { transaction_groups } = PropsSchema.parse(props)
  const hasTransactions = transaction_groups.length > 0

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

        {!hasTransactions ? (
          <Text color="gray">
            No transactions found. Connect a bank account to see your transactions.
          </Text>
        ) : (
          <Flex direction="column" gap="6">
            {transaction_groups.map((group: TransactionGroup) => (
              <Box key={group.month_key}>
                <Heading size="5" as="h2" mb="4">
                  {group.month_label}
                </Heading>
                <Table.Root variant="surface" size="2">
                  <Table.Header>
                    <Table.Row>
                      <Table.ColumnHeaderCell width="36px"></Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="110px">Bank</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="110px">Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Original</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Invoice</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="100px">Actions</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {group.transactions.map((tx) => {
                      const isHidden = !!tx.hidden_at
                      const isLinked = !!tx.invoice_id
                      const hiddenClass = isHidden ? "line-through opacity-40" : ""
                      const bankLabel = tx.bank_name?.split(" ")[0] || ""
                      const directionColor = tx.direction === "inflow" ? "green" : "red"
                      const rowClass = isHidden
                        ? "bg-gray-50"
                        : isLinked
                          ? "bg-blue-50"
                          : ""

                      return (
                        <Table.Row key={tx.id} className={rowClass}>
                          <Table.Cell>
                            {isLinked && <CheckIcon className="text-blue-600" />}
                          </Table.Cell>
                          <Table.Cell><span className={hiddenClass}>{bankLabel}</span></Table.Cell>
                          <Table.Cell><span className={hiddenClass}>{tx.booking_date_label}</span></Table.Cell>
                          <Table.Cell>
                            <Text className={hiddenClass} color={isHidden ? "gray" : directionColor}>
                              {tx.amount_label}
                            </Text>
                          </Table.Cell>
                          <Table.Cell>
                            <span className={hiddenClass}>
                              {tx.original_amount_label}
                            </span>
                          </Table.Cell>
                          <Table.Cell><span className={hiddenClass}>{tx.vendor_name}</span></Table.Cell>
                          <Table.Cell>
                            {tx.invoice ? (
                              <Button size="1" variant="soft" color="blue" className="gap-1">
                                <FileTextIcon />
                                {tx.invoice.label}
                              </Button>
                            ) : (
                              !isHidden && <InvoiceSelector transactionId={tx.id} />
                            )}
                          </Table.Cell>
                          <Table.Cell>
                            {isHidden ? (
                              <Button
                                size="1"
                                variant="soft"
                                color="gray"
                                onClick={() => router.post(`/transactions/${tx.id}/restore`, {}, { preserveScroll: true })}
                              >
                                Restore
                              </Button>
                            ) : (
                              <Button
                                size="1"
                                variant="soft"
                                color="red"
                                onClick={() => router.post(`/transactions/${tx.id}/hide`, {}, { preserveScroll: true })}
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
