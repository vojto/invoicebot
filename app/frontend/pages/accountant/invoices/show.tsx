import { Head, Link } from "@inertiajs/react"
import {
  CheckIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  ColumnsIcon,
  DownloadIcon,
  ExternalLinkIcon,
  FileTextIcon,
  ResetIcon,
  TableIcon,
} from "@radix-ui/react-icons"
import { Box, Button, Flex, Heading, Table, Text } from "@radix-ui/themes"
import { ReactNode, useState } from "react"
import { z } from "zod"
import PdfPreview from "../../../components/PdfPreview"
import PublicLayout from "../../../layouts/public"
import formatCurrency from "../../../lib/formatCurrency"

const InvoiceSchema = z.object({
  id: z.number(),
  vendor_name: z.string().nullable(),
  amount_cents: z.number().nullable(),
  currency: z.string().nullable(),
  accounting_date: z.string().nullable(),
  issue_date: z.string().nullable(),
  delivery_date: z.string().nullable(),
  category_name: z.string().nullable(),
  vendor_country: z.string().nullable(),
  vendor_eu_vat_id: z.string().nullable(),
  transaction: z.object({
    date: z.string().nullable(),
    account_name: z.string().nullable(),
    amount_cents: z.number().nullable(),
    currency: z.string().nullable(),
    original_amount_cents: z.number().nullable(),
    original_currency: z.string().nullable(),
    direction: z.enum(["credit", "debit"]),
  }).nullable(),
  pdf_url: z.string().nullable(),
  pages_url: z.string().nullable(),
})

const PropsSchema = z.object({
  invoice_month: z.object({
    key: z.string(),
    label: z.string(),
  }),
  progress_storage_key: z.string(),
  previous_month_url: z.string(),
  next_month_url: z.string(),
  download_url: z.string(),
  invoices: z.array(InvoiceSchema),
})

type Props = z.infer<typeof PropsSchema>
type Invoice = z.infer<typeof InvoiceSchema>
type ViewMode = "split" | "table"

const flagUrls = import.meta.glob(
  "../../../../../node_modules/country-flag-icons/3x2/*.svg",
  { eager: true, import: "default", query: "?url&no-inline" },
) as Record<string, string>

function formatDate(value: string | null) {
  if (!value) return "—"

  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(value))
}

function amountLabel(invoice: Invoice) {
  return invoice.amount_cents == null
    ? "—"
    : formatCurrency(invoice.amount_cents, invoice.currency)
}

function transactionAmountLabel(invoice: Invoice) {
  if (invoice.transaction?.amount_cents == null) return "—"

  const amount = formatCurrency(invoice.transaction.amount_cents, invoice.transaction.currency)
  return invoice.transaction.currency ? `${amount} ${invoice.transaction.currency}` : amount
}

function originalTransactionAmountLabel(invoice: Invoice) {
  if (invoice.transaction?.original_amount_cents == null) return "—"

  const amount = formatCurrency(invoice.transaction.original_amount_cents, invoice.transaction.original_currency)
  return invoice.transaction.original_currency ? `${amount} ${invoice.transaction.original_currency}` : amount
}

function CountryFlag({ country }: { country: string | null }) {
  const countryCode = country?.trim().toUpperCase()
  const flagUrl = countryCode
    ? flagUrls[`../../../../../node_modules/country-flag-icons/3x2/${countryCode}.svg`]
    : null
  if (!countryCode || !flagUrl) return "—"

  return (
    <img
      src={flagUrl}
      alt={countryCode}
      title={countryCode}
      className="inline-block h-4 w-6 rounded-[2px] shadow-[0_0_0_1px_var(--gray-a5)]"
    />
  )
}

function MonthNavigation({ previousUrl, nextUrl }: { previousUrl: string; nextUrl: string }) {
  return (
    <nav
      aria-label="Invoice month"
      className="inline-flex overflow-hidden rounded-md border border-[var(--gray-a6)] bg-[var(--color-background)] shadow-sm"
    >
      <Link
        href={previousUrl}
        className="inline-flex h-8 items-center gap-1 border-r border-[var(--gray-a6)] px-2.5 text-sm font-medium text-[var(--gray-11)] hover:bg-[var(--gray-a3)] focus-visible:z-10 focus-visible:outline-2 focus-visible:outline-[var(--accent-8)]"
      >
        <ChevronLeftIcon /> Previous
      </Link>
      <Link
        href={nextUrl}
        className="inline-flex h-8 items-center gap-1 px-2.5 text-sm font-medium text-[var(--gray-11)] hover:bg-[var(--gray-a3)] focus-visible:z-10 focus-visible:outline-2 focus-visible:outline-[var(--accent-8)]"
      >
        Next <ChevronRightIcon />
      </Link>
    </nav>
  )
}

function ViewToggle({ value, onChange }: { value: ViewMode; onChange: (value: ViewMode) => void }) {
  return (
    <div
      role="group"
      aria-label="Invoice display"
      className="inline-flex overflow-hidden rounded-md border border-[var(--gray-a6)] bg-[var(--color-background)] shadow-sm"
    >
      <button
        type="button"
        aria-pressed={value === "split"}
        onClick={() => onChange("split")}
        className={`inline-flex h-8 items-center gap-1.5 border-r border-[var(--gray-a6)] px-2.5 text-sm font-medium ${value === "split" ? "bg-[var(--accent-a4)] text-[var(--accent-11)]" : "text-[var(--gray-11)] hover:bg-[var(--gray-a3)]"}`}
      >
        <ColumnsIcon /> Split
      </button>
      <button
        type="button"
        aria-pressed={value === "table"}
        onClick={() => onChange("table")}
        className={`inline-flex h-8 items-center gap-1.5 px-2.5 text-sm font-medium ${value === "table" ? "bg-[var(--accent-a4)] text-[var(--accent-11)]" : "text-[var(--gray-11)] hover:bg-[var(--gray-a3)]"}`}
      >
        <TableIcon /> Table
      </button>
    </div>
  )
}

function loadProcessedInvoiceIds(storageKey: string, invoices: Invoice[]) {
  if (typeof window === "undefined") return []

  try {
    const value = JSON.parse(window.localStorage.getItem(storageKey) || "[]")
    if (!Array.isArray(value)) return []

    const invoiceIds = new Set(invoices.map((invoice) => invoice.id))
    return value.filter((id): id is number => Number.isInteger(id) && invoiceIds.has(id))
  } catch {
    return []
  }
}

function saveProcessedInvoiceIds(storageKey: string, invoiceIds: number[]) {
  try {
    window.localStorage.setItem(storageKey, JSON.stringify(invoiceIds))
  } catch {
    // Keep the in-memory workflow usable when local storage is unavailable.
  }
}

function clearProcessedInvoiceIds(storageKey: string) {
  try {
    window.localStorage.removeItem(storageKey)
  } catch {
    // The in-memory reset still works when local storage is unavailable.
  }
}

function Detail({ label, value }: { label: string; value: ReactNode }) {
  return (
    <Box>
      <Text as="div" size="1" color="gray" mb="1">{label}</Text>
      <Text as="div" size="2" weight="medium">{value || "—"}</Text>
    </Box>
  )
}

function TransactionDetail({ invoice }: { invoice: Invoice }) {
  if (!invoice.transaction) return "—"

  return (
    <>
      {formatDate(invoice.transaction.date)}
      <Text as="div" size="1" color="gray" weight="regular">
        {invoice.transaction.account_name || "—"}
      </Text>
    </>
  )
}

function InvoiceDetails({ invoice, isProcessed, onToggleProcessed }: { invoice: Invoice; isProcessed: boolean; onToggleProcessed: () => void }) {
  return (
    <Box p="3" style={{ borderBottom: "1px solid var(--gray-a5)", backgroundColor: "var(--color-background)" }}>
      <Flex justify="between" align="center" gap="4" wrap="wrap">
        <div className="grid flex-1 grid-cols-2 gap-4 sm:grid-cols-4">
          <Detail label="Issue date" value={formatDate(invoice.issue_date)} />
          <Detail label="Delivery date" value={formatDate(invoice.delivery_date)} />
          <Detail label="Supplier VAT ID" value={invoice.vendor_eu_vat_id} />
          <Detail label="Transaction" value={<TransactionDetail invoice={invoice} />} />
        </div>

        <Flex gap="2" ml="auto">
          {invoice.pdf_url && (
            <Button variant="soft" asChild>
              <a href={invoice.pdf_url} target="_blank" rel="noreferrer">
                <ExternalLinkIcon /> Open PDF
              </a>
            </Button>
          )}
          <Button
            onClick={onToggleProcessed}
            variant={isProcessed ? "soft" : "solid"}
            color={isProcessed ? "gray" : undefined}
            data-testid={isProcessed ? "accountant-undo" : "accountant-done"}
          >
            {isProcessed ? <ResetIcon /> : <CheckIcon />}
            {isProcessed ? "Undo" : "Done"}
          </Button>
        </Flex>
      </Flex>
    </Box>
  )
}

function PdfPane({ invoice, isProcessed, onToggleProcessed }: { invoice: Invoice; isProcessed: boolean; onToggleProcessed: () => void }) {
  return (
    <section className="flex min-h-[680px] min-w-0 flex-col bg-[var(--gray-a2)] lg:min-h-0" aria-label="Invoice preview">
      <InvoiceDetails invoice={invoice} isProcessed={isProcessed} onToggleProcessed={onToggleProcessed} />

      <div className="min-h-[520px] flex-1 p-3">
        {invoice.pages_url ? (
          <PdfPreview
            invoiceId={invoice.id}
            pagesUrl={invoice.pages_url}
            className="h-full min-h-[620px] w-full lg:min-h-0"
          />
        ) : (
          <Flex height="100%" minHeight="520px" align="center" justify="center" direction="column" gap="3">
            <FileTextIcon width="32" height="32" color="var(--gray-8)" />
            <Text color="gray">No PDF is attached to this invoice.</Text>
          </Flex>
        )}
      </div>
    </section>
  )
}

function CompletedPane() {
  return (
    <Flex
      minHeight="520px"
      height="100%"
      align="center"
      justify="center"
      direction="column"
      gap="3"
      className="bg-[var(--gray-a2)]"
    >
      <Flex align="center" justify="center" className="size-12 rounded-full bg-[var(--green-a4)] text-[var(--green-9)]">
        <CheckIcon width="24" height="24" />
      </Flex>
      <Heading size="4">All done</Heading>
      <Text size="2" color="gray">You have reviewed every invoice for this month.</Text>
    </Flex>
  )
}

function ProgressFooter({ processedCount, invoiceCount, onReset }: { processedCount: number; invoiceCount: number; onReset: () => void }) {
  return (
    <Flex
      asChild
      align="center"
      justify="between"
      gap="3"
      px="3"
      py="2"
      style={{ borderTop: "1px solid var(--gray-a5)", backgroundColor: "var(--gray-a2)" }}
    >
      <footer data-testid="accountant-progress">
        <Text size="2" color="gray">
          <Text weight="bold" color="gray">{processedCount}</Text> of {invoiceCount} processed
        </Text>
        <Button
          size="1"
          variant="ghost"
          color="gray"
          disabled={processedCount === 0}
          onClick={onReset}
          data-testid="accountant-reset"
        >
          <ResetIcon /> Reset
        </Button>
      </footer>
    </Flex>
  )
}

function FullInvoiceTable({
  invoices,
  processedInvoiceIds,
  onToggleProcessed,
  onReset,
}: {
  invoices: Invoice[]
  processedInvoiceIds: Set<number>
  onToggleProcessed: (invoice: Invoice) => void
  onReset: () => void
}) {
  return (
    <section className="flex w-full min-w-0 flex-col overflow-hidden rounded-xl border border-[var(--gray-a6)] bg-[var(--color-background)] shadow-sm" aria-label="Invoice table">
      <div className="w-full overflow-auto">
        <Table.Root size="2" style={{ minWidth: 1900, width: "100%" }}>
          <Table.Header style={{ position: "sticky", top: 0, zIndex: 1, backgroundColor: "var(--color-background)" }}>
            <Table.Row>
              <Table.ColumnHeaderCell>Status</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell justify="center">Country</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>VAT ID</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Category</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Accounting date</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Issue date</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Delivery date</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell justify="end">Invoice amount</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Transaction date</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Bank account</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell justify="end">Bank amount</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell justify="end">Original amount</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>Direction</Table.ColumnHeaderCell>
              <Table.ColumnHeaderCell>PDF</Table.ColumnHeaderCell>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {invoices.map((invoice) => {
              const isProcessed = processedInvoiceIds.has(invoice.id)

              return (
                <Table.Row key={invoice.id} style={{ color: isProcessed ? "var(--gray-9)" : undefined }}>
                  <Table.Cell className="whitespace-nowrap">
                    <Button
                      size="1"
                      variant={isProcessed ? "soft" : "ghost"}
                      color={isProcessed ? "gray" : undefined}
                      onClick={() => onToggleProcessed(invoice)}
                      data-testid={`accountant-table-toggle-${invoice.id}`}
                    >
                      {isProcessed ? <ResetIcon /> : <CheckIcon />}
                      {isProcessed ? "Undo" : "Done"}
                    </Button>
                  </Table.Cell>
                  <Table.Cell className="min-w-48">
                    <Text weight="medium">{invoice.vendor_name || "Unknown"}</Text>
                  </Table.Cell>
                  <Table.Cell justify="center"><CountryFlag country={invoice.vendor_country} /></Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{invoice.vendor_eu_vat_id || "—"}</Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{invoice.category_name || "Uncategorized"}</Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{formatDate(invoice.accounting_date)}</Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{formatDate(invoice.issue_date)}</Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{formatDate(invoice.delivery_date)}</Table.Cell>
                  <Table.Cell justify="end" className="whitespace-nowrap"><Text weight="medium">{amountLabel(invoice)}</Text></Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{formatDate(invoice.transaction?.date || null)}</Table.Cell>
                  <Table.Cell className="whitespace-nowrap">{invoice.transaction?.account_name || "—"}</Table.Cell>
                  <Table.Cell justify="end" className="whitespace-nowrap"><Text weight="medium">{transactionAmountLabel(invoice)}</Text></Table.Cell>
                  <Table.Cell justify="end" className="whitespace-nowrap">{originalTransactionAmountLabel(invoice)}</Table.Cell>
                  <Table.Cell className="capitalize">{invoice.transaction?.direction || "—"}</Table.Cell>
                  <Table.Cell>
                    {invoice.pdf_url ? (
                      <Button size="1" variant="ghost" asChild>
                        <a href={invoice.pdf_url} target="_blank" rel="noreferrer">
                          <ExternalLinkIcon /> Open
                        </a>
                      </Button>
                    ) : "—"}
                  </Table.Cell>
                </Table.Row>
              )
            })}
          </Table.Body>
        </Table.Root>
      </div>

      <ProgressFooter processedCount={processedInvoiceIds.size} invoiceCount={invoices.length} onReset={onReset} />
    </section>
  )
}

function AccountantInvoicesShow(props: Props) {
  const {
    invoice_month,
    progress_storage_key,
    previous_month_url,
    next_month_url,
    download_url,
    invoices,
  } = PropsSchema.parse(props)
  const storageKey = `invoicebot:accountant-progress:${progress_storage_key}:${invoice_month.key}`
  const [progress, setProgress] = useState(() => ({
    storageKey,
    invoiceIds: loadProcessedInvoiceIds(storageKey, invoices),
  }))
  const processedInvoiceIds = progress.storageKey === storageKey
    ? progress.invoiceIds
    : loadProcessedInvoiceIds(storageKey, invoices)
  const processedInvoiceIdSet = new Set(processedInvoiceIds)
  const firstUnprocessedInvoice = invoices.find((invoice) => !processedInvoiceIdSet.has(invoice.id))
  const [selection, setSelection] = useState({
    month: invoice_month.key,
    invoiceId: firstUnprocessedInvoice?.id ?? null,
  })
  const selectedInvoiceId = selection.month === invoice_month.key
    ? selection.invoiceId
    : firstUnprocessedInvoice?.id ?? null
  const selectedInvoice = invoices.find((invoice) => invoice.id === selectedInvoiceId)
  const [viewMode, setViewMode] = useState<ViewMode>("split")

  const toggleProcessed = (invoice: Invoice, advanceSelection: boolean) => {
    if (processedInvoiceIdSet.has(invoice.id)) {
      const nextProcessedInvoiceIds = processedInvoiceIds.filter((id) => id !== invoice.id)
      saveProcessedInvoiceIds(storageKey, nextProcessedInvoiceIds)
      setProgress({ storageKey, invoiceIds: nextProcessedInvoiceIds })
      return
    }

    const nextProcessedInvoiceIds = [...processedInvoiceIds, invoice.id]
    const nextProcessedInvoiceIdSet = new Set(nextProcessedInvoiceIds)

    saveProcessedInvoiceIds(storageKey, nextProcessedInvoiceIds)
    setProgress({ storageKey, invoiceIds: nextProcessedInvoiceIds })

    if (advanceSelection) {
      const selectedIndex = invoices.findIndex((candidate) => candidate.id === invoice.id)
      const remainingInvoices = [...invoices.slice(selectedIndex + 1), ...invoices.slice(0, selectedIndex)]
      const nextInvoice = remainingInvoices.find((candidate) => !nextProcessedInvoiceIdSet.has(candidate.id))
      setSelection({ month: invoice_month.key, invoiceId: nextInvoice?.id ?? null })
    }
  }

  const handleDone = () => {
    if (selectedInvoice) toggleProcessed(selectedInvoice, true)
  }

  const handleReset = () => {
    if (!window.confirm(`Reset progress for ${invoice_month.label}? All invoices will return to the list.`)) return

    clearProcessedInvoiceIds(storageKey)
    setProgress({ storageKey, invoiceIds: [] })
    setSelection({ month: invoice_month.key, invoiceId: invoices[0]?.id ?? null })
  }

  return (
    <>
      <Head title={`Shared invoices — ${invoice_month.label}`}>
        <meta name="robots" content="noindex, nofollow, noarchive" />
        <meta name="referrer" content="no-referrer" />
      </Head>

      <Flex justify="between" align="center" mb="3" wrap="wrap" gap="3">
        <Heading size="4">
          Invoices — {invoice_month.label}{" "}
          <Text as="span" size="3" color="gray" weight="regular">({invoices.length})</Text>
        </Heading>
        <Flex gap="2" wrap="wrap" justify="end">
          <ViewToggle value={viewMode} onChange={setViewMode} />
          <MonthNavigation previousUrl={previous_month_url} nextUrl={next_month_url} />
          {invoices.length > 0 && (
            <Button size="1" variant="soft" asChild>
              <a href={download_url} download aria-label={`Download all ${invoice_month.label} invoices as a ZIP file`}>
                <DownloadIcon /> ZIP
              </a>
            </Button>
          )}
        </Flex>
      </Flex>

      {invoices.length === 0 ? (
        <Flex minHeight="420px" align="center" justify="center" direction="column" gap="2">
          <FileTextIcon width="32" height="32" color="var(--gray-8)" />
          <Text color="gray">No invoices found for {invoice_month.label}.</Text>
        </Flex>
      ) : viewMode === "table" ? (
        <FullInvoiceTable
          invoices={invoices}
          processedInvoiceIds={processedInvoiceIdSet}
          onToggleProcessed={(invoice) => toggleProcessed(invoice, false)}
          onReset={handleReset}
        />
      ) : (
        <div className="grid min-h-[680px] overflow-hidden rounded-xl border border-[var(--gray-a6)] bg-[var(--color-background)] shadow-sm lg:h-[calc(100vh-178px)] lg:grid-cols-[minmax(420px,0.8fr)_minmax(0,1.2fr)]">
          <section className="flex min-h-0 min-w-0 flex-col border-b border-[var(--gray-a6)] lg:border-b-0 lg:border-r" aria-label="Invoices">
            <div className="min-h-0 flex-1 overflow-auto">
              <Table.Root size="2" style={{ width: "100%" }}>
                <Table.Header style={{ position: "sticky", top: 0, zIndex: 1, backgroundColor: "var(--color-background)" }}>
                  <Table.Row>
                    <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
                    <Table.ColumnHeaderCell width="70px" justify="center">Country</Table.ColumnHeaderCell>
                    <Table.ColumnHeaderCell width="120px">Date</Table.ColumnHeaderCell>
                    <Table.ColumnHeaderCell width="120px" justify="end">Amount</Table.ColumnHeaderCell>
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {invoices.map((invoice) => {
                    const isSelected = invoice.id === selectedInvoice?.id
                    const isProcessed = processedInvoiceIdSet.has(invoice.id)

                    return (
                      <Table.Row
                        key={invoice.id}
                        data-testid={`accountant-invoice-${invoice.id}`}
                        aria-selected={isSelected}
                        tabIndex={0}
                        onClick={() => setSelection({ month: invoice_month.key, invoiceId: invoice.id })}
                        onKeyDown={(event) => {
                          if (event.key === "Enter" || event.key === " ") {
                            event.preventDefault()
                            setSelection({ month: invoice_month.key, invoiceId: invoice.id })
                          }
                        }}
                        style={{
                          cursor: "pointer",
                          backgroundColor: isSelected ? "var(--accent-a3)" : undefined,
                          boxShadow: isSelected ? "inset 3px 0 0 var(--accent-9)" : undefined,
                          color: isProcessed ? "var(--gray-9)" : undefined,
                        }}
                      >
                        <Table.Cell>
                          <Flex align="center" gap="2">
                            {isProcessed
                              ? <CheckIcon style={{ color: "var(--accent-9)" }} />
                              : <FileTextIcon color={invoice.pdf_url ? "var(--accent-9)" : "var(--gray-7)"} />}
                            <Box style={{ minWidth: 0 }}>
                              <Text as="div" weight="medium" truncate>{invoice.vendor_name || "Unknown"}</Text>
                              <Text as="div" size="1" color="gray">{invoice.category_name || "Uncategorized"}</Text>
                            </Box>
                          </Flex>
                        </Table.Cell>
                        <Table.Cell justify="center">
                          <CountryFlag country={invoice.vendor_country} />
                        </Table.Cell>
                        <Table.Cell>{formatDate(invoice.accounting_date)}</Table.Cell>
                        <Table.Cell justify="end">
                          <Text weight="medium">{amountLabel(invoice)}</Text>
                        </Table.Cell>
                      </Table.Row>
                    )
                  })}
                </Table.Body>
              </Table.Root>
            </div>

            <ProgressFooter
              processedCount={processedInvoiceIds.length}
              invoiceCount={invoices.length}
              onReset={handleReset}
            />
          </section>

          {selectedInvoice
            ? (
              <PdfPane
                invoice={selectedInvoice}
                isProcessed={processedInvoiceIdSet.has(selectedInvoice.id)}
                onToggleProcessed={handleDone}
              />
            )
            : <CompletedPane />}
        </div>
      )}
    </>
  )
}

AccountantInvoicesShow.layout = (page: ReactNode) => <PublicLayout>{page}</PublicLayout>

export default AccountantInvoicesShow
