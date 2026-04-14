import { Head, Link, router } from "@inertiajs/react"
import { Heading, Box, Text, Button, Flex, Table } from "@radix-ui/themes"
import { CheckIcon, ChevronDownIcon, FileTextIcon, PlusIcon } from "@radix-ui/react-icons"
import * as DropdownMenu from "@radix-ui/react-dropdown-menu"
import { z } from "zod"
import BankSyncStatusList, { BankSyncStatusSchema } from "../../components/BankSyncStatusList"
import InvoiceSelector from "../../components/InvoiceSelector"
import TransactionNoteEditor from "../../components/TransactionNoteEditor"
import TransactionInvoiceUploadButton from "../../components/TransactionInvoiceUploadButton"

const TransactionSchema = z.object({
  id: z.number(),
  invoice_id: z.number().nullable(),
  invoice: z
    .object({
      id: z.number(),
      label: z.string(),
    })
    .nullable(),
  direction: z.enum(["credit", "debit"]),
  booking_date_label: z.string(),
  amount_cents: z.number(),
  amount_label: z.string(),
  original_amount_label: z.string(),
  vendor_name: z.string().nullable(),
  custom_note: z.string().nullable(),
  bank_name: z.string().nullable(),
  hidden_at: z.string().nullable(),
  is_flagged: z.boolean(),
})

const TransactionGroupSchema = z.object({
  month_key: z.string(),
  month_label: z.string(),
  transactions: z.array(TransactionSchema),
})

type TransactionGroup = z.infer<typeof TransactionGroupSchema>

const PropsSchema = z.object({
  transaction_groups: z.array(TransactionGroupSchema),
  bank_sync_statuses: z.array(BankSyncStatusSchema),
})

type Props = z.infer<typeof PropsSchema>

type ActionButtonProps = {
  transactionId: number
  isFlagged: boolean
}

function postTransactionAction(url: string) {
  router.post(url, {}, { preserveScroll: true })
}

function TransactionActions({ transactionId, isFlagged }: ActionButtonProps) {
  return (
    <DropdownMenu.Root>
      <DropdownMenu.Trigger asChild>
        <Button size="1" variant="soft" color="gray">
          Actions
          <ChevronDownIcon />
        </Button>
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content
          align="end"
          sideOffset={6}
          className="z-50 min-w-28 rounded-md border border-gray-200 bg-white p-1 shadow-lg"
        >
          <DropdownMenu.Item
            className="cursor-pointer select-none rounded px-2 py-1.5 text-sm text-gray-800 outline-none hover:bg-gray-100 focus:bg-gray-100"
            onSelect={() => postTransactionAction(`/transactions/${transactionId}/hide`)}
          >
            Hide
          </DropdownMenu.Item>
          <DropdownMenu.Item
            className="cursor-pointer select-none rounded px-2 py-1.5 text-sm text-gray-800 outline-none hover:bg-gray-100 focus:bg-gray-100"
            onSelect={() => postTransactionAction(
              isFlagged
                ? `/transactions/${transactionId}/unflag`
                : `/transactions/${transactionId}/flag`
            )}
          >
            {isFlagged ? "Remove flag" : "Flag"}
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  )
}

export default function TransactionsIndex(props: Props) {
  const { transaction_groups, bank_sync_statuses } = PropsSchema.parse(props)
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
        <BankSyncStatusList bankSyncStatuses={bank_sync_statuses} />

        {!hasTransactions ? (
          <Text color="gray">
            No transactions found. Connect a bank account to see your transactions.
          </Text>
        ) : (
          <Flex direction="column" gap="6">
            {transaction_groups.map((group: TransactionGroup) => (
              <Box key={group.month_key}>
                <Flex justify="between" align="center" mb="4">
                  <Heading size="5" as="h2">
                    {group.month_label}
                  </Heading>
                  {group.month_key !== "unknown" && (
                    <Button size="1" variant="soft" asChild>
                      <Link href={`/statements/${group.month_key}`}>
                        Print
                      </Link>
                    </Button>
                  )}
                </Flex>
                <Table.Root variant="surface" size="2">
                  <Table.Header>
                    <Table.Row>
                      <Table.ColumnHeaderCell width="36px"></Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="110px">Bank</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="110px">Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Original</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Note</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Invoice</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="100px">Actions</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {group.transactions.map((tx) => {
                      const isHidden = !!tx.hidden_at
                      const isFlagged = tx.is_flagged
                      const isLinked = !!tx.invoice_id
                      const hiddenClass = isHidden ? "line-through opacity-40" : ""
                      const bankLabel = tx.bank_name?.split(" ")[0] || ""
                      const directionColor = tx.direction === "credit" ? "green" : "red"
                      const rowClass = isHidden
                        ? "bg-gray-50"
                        : isFlagged
                          ? "bg-red-50"
                        : isLinked
                          ? "bg-blue-50"
                          : "bg-yellow-50/50"

                      return (
                        <Table.Row key={tx.id} className={rowClass}>
                          <Table.Cell>
                            {isLinked && <CheckIcon className="text-blue-600" />}
                          </Table.Cell>
                          <Table.Cell><span className={hiddenClass}>{bankLabel}</span></Table.Cell>
                          <Table.Cell>
                            <Link
                              href={`/transactions/${tx.id}`}
                              className={hiddenClass}
                              style={{ color: 'inherit', textDecoration: 'underline dotted', textUnderlineOffset: 3 }}
                              onMouseEnter={e => { e.currentTarget.style.textDecoration = 'none' }}
                              onMouseLeave={e => { e.currentTarget.style.textDecoration = 'underline dotted' }}
                            >
                              {tx.booking_date_label}
                            </Link>
                          </Table.Cell>
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
                          <Table.Cell>
                            <TransactionNoteEditor
                              transactionId={tx.id}
                              customNote={tx.custom_note}
                              vendorName={tx.vendor_name}
                              textClassName={hiddenClass}
                            />
                          </Table.Cell>
                          <Table.Cell>
                            {!isFlagged && (
                              tx.invoice ? (
                                <Button size="1" variant="soft" color="blue" className="gap-1">
                                  <FileTextIcon />
                                  {tx.invoice.label}
                                </Button>
                              ) : (
                                !isHidden && (
                                <Flex gap="2" wrap="wrap">
                                  <InvoiceSelector transactionId={tx.id} />
                                  <TransactionInvoiceUploadButton transactionId={tx.id} />
                                </Flex>
                                )
                              )
                            )}
                          </Table.Cell>
                          <Table.Cell>
                            {isHidden || isFlagged ? (
                              <Button
                                size="1"
                                variant="soft"
                                color="gray"
                                onClick={() => postTransactionAction(
                                  isHidden
                                    ? `/transactions/${tx.id}/restore`
                                    : `/transactions/${tx.id}/unflag`
                                )}
                              >
                                {isHidden ? "Restore" : "Unflag"}
                              </Button>
                            ) : (
                              <TransactionActions transactionId={tx.id} isFlagged={isFlagged} />
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
