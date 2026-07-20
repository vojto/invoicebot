import { Head, Link, router } from "@inertiajs/react"
import { Heading, Box, Text, Button, Flex, Table } from "@radix-ui/themes"
import { CheckIcon, ChevronDownIcon, FileTextIcon, MagicWandIcon, PlusIcon } from "@radix-ui/react-icons"
import * as DropdownMenu from "@radix-ui/react-dropdown-menu"
import { z } from "zod"
import BankSyncStatusList, { BankSyncStatusSchema } from "../../components/BankSyncStatusList"
import InvoiceSelector from "../../components/InvoiceSelector"
import TransactionNoteEditor from "../../components/TransactionNoteEditor"
import TransactionInvoiceUploadButton from "../../components/TransactionInvoiceUploadButton"
import TransactionCategorySelect, { CategorySchema } from "../../components/TransactionCategorySelect"
import PdfDropZone from "../../components/PdfDropZone"

const TransactionSchema = z.object({
  id: z.number(),
  invoice_id: z.number().nullable(),
  invoice_match_source: z.enum(["manual", "automatic"]).nullable(),
  invoice: z
    .object({
      id: z.number(),
      label: z.string(),
    })
    .nullable(),
  category: CategorySchema.nullable(),
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
  categories: z.array(CategorySchema),
  bank_sync_statuses: z.array(BankSyncStatusSchema),
  selected_month: z
    .object({
      key: z.string(),
      label: z.string(),
    })
    .nullable(),
})

type Props = z.infer<typeof PropsSchema>

type ActionButtonProps = {
  transactionId: number
  isFlagged: boolean
  isLinked: boolean
}

function postTransactionAction(url: string) {
  router.post(url, {}, { preserveScroll: true })
}

function TransactionActions({ transactionId, isFlagged, isLinked }: ActionButtonProps) {
  const itemClass = "cursor-pointer select-none rounded px-2 py-1.5 text-sm text-gray-800 outline-none hover:bg-gray-100 focus:bg-gray-100"
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
          {isLinked && (
            <DropdownMenu.Item
              className={itemClass}
              onSelect={() => postTransactionAction(`/transactions/${transactionId}/unlink_invoice`)}
            >
              Unlink document
            </DropdownMenu.Item>
          )}
          <DropdownMenu.Item
            className={itemClass}
            onSelect={() => postTransactionAction(`/transactions/${transactionId}/hide`)}
          >
            Hide
          </DropdownMenu.Item>
          <DropdownMenu.Item
            className={itemClass}
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
  const { transaction_groups, categories, bank_sync_statuses, selected_month } = PropsSchema.parse(props)
  const hasTransactions = transaction_groups.length > 0

  return (
    <PdfDropZone enabled={true}>
      <Head title="Transactions" />
      <Box>
        <Flex justify="between" align="center" mb="4">
          <Heading size="6">
            {selected_month ? `Transactions — ${selected_month.label}` : "Transactions"}
          </Heading>
          <Flex gap="2">
            {selected_month && (
              <Button variant="soft" color="gray" asChild>
                <Link href="/transactions">All months</Link>
              </Button>
            )}
            <Button asChild>
              <Link href="/banks">
                <PlusIcon />
                Connect Bank Account
              </Link>
            </Button>
          </Flex>
        </Flex>
        <BankSyncStatusList bankSyncStatuses={bank_sync_statuses} />

        {!hasTransactions ? (
          <Text color="gray">
            {selected_month
              ? `No transactions found for ${selected_month.label}.`
              : "No transactions found. Connect a bank account to see your transactions."}
          </Text>
        ) : (
          <Flex direction="column" gap="6">
            {transaction_groups.map((group: TransactionGroup) => (
              <Box key={group.month_key}>
                <Flex justify="between" align="center" mb="4">
                  <Heading size="5" as="h2">
                    {group.month_key === "unknown" ? (
                      group.month_label
                    ) : (
                      <Link
                        href={`/transactions/month/${group.month_key}`}
                        className="text-inherit underline decoration-dotted underline-offset-4 hover:decoration-solid"
                      >
                        {group.month_label}
                      </Link>
                    )}{" "}
                    <Text size="4" color="gray" weight="regular">({group.transactions.length})</Text>
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
                      <Table.ColumnHeaderCell>Document</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="190px">Category</Table.ColumnHeaderCell>
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
                              className={`${hiddenClass} text-inherit underline decoration-dotted hover:decoration-solid underline-offset-2`}
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
                                <Flex align="center" gap="1">
                                  <Button size="1" variant="soft" color="blue" className="gap-1 max-w-[300px]" asChild>
                                    <Link href={`/invoices/${tx.invoice.id}`}>
                                      <FileTextIcon className="shrink-0" />
                                      <span className="truncate">{tx.invoice.label}</span>
                                    </Link>
                                  </Button>
                                  {tx.invoice_match_source === "automatic" && (
                                    <span
                                      title="Matched automatically"
                                      aria-label="Matched automatically"
                                      className="inline-flex text-violet-600"
                                    >
                                      <MagicWandIcon />
                                    </span>
                                  )}
                                </Flex>
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
                            <TransactionCategorySelect
                              transactionId={tx.id}
                              category={tx.category}
                              categories={categories}
                            />
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
                              <TransactionActions transactionId={tx.id} isFlagged={isFlagged} isLinked={isLinked} />
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
    </PdfDropZone>
  )
}
