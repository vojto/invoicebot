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

const TableColumnSchema = z.object({
  key: z.string(),
  label: z.string(),
  kind: z.enum(["text", "flag", "country_vat", "date", "amount"]),
  width: z.number(),
  split_view: z.boolean(),
  align: z.enum(["start", "center", "end"]),
})

const TableRowSchema = z.object({
  invoice_id: z.number(),
  pdf_url: z.string().nullable(),
  currencies: z.record(z.string(), z.string().nullable()),
  values: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])),
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
  spreadsheet_url: z.string(),
  table: z.object({
    columns: z.array(TableColumnSchema),
    rows: z.array(TableRowSchema),
  }),
  invoices: z.array(InvoiceSchema),
})

type Props = z.infer<typeof PropsSchema>
type Invoice = z.infer<typeof InvoiceSchema>
type TableColumn = z.infer<typeof TableColumnSchema>
type TableRow = z.infer<typeof TableRowSchema>
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

function formatTableDate(value: string | null) {
  if (!value) return "—"

  return new Intl.DateTimeFormat("en-US", {
    month: "2-digit",
    day: "2-digit",
    timeZone: "UTC",
  }).format(new Date(value))
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
      className="inline-block h-3 w-[18px] rounded-[2px] shadow-[0_0_0_1px_var(--gray-a5)]"
    />
  )
}

function MonthNavigation({ previousUrl, nextUrl }: { previousUrl: string; nextUrl: string }) {
  return (
    <nav aria-label="Invoice month">
      <Flex gap="2">
        <Button size="2" variant="soft" color="gray" asChild>
          <Link href={previousUrl}>
            <ChevronLeftIcon /> Previous
          </Link>
        </Button>
        <Button size="2" variant="soft" color="gray" asChild>
          <Link href={nextUrl}>
            Next <ChevronRightIcon />
          </Link>
        </Button>
      </Flex>
    </nav>
  )
}

function ViewToggle({ value, onChange }: { value: ViewMode; onChange: (value: ViewMode) => void }) {
  return (
    <Flex gap="2" role="group" aria-label="Invoice display">
      <Button
        size="2"
        variant="soft"
        color={value === "split" ? undefined : "gray"}
        type="button"
        aria-pressed={value === "split"}
        onClick={() => onChange("split")}
      >
        <ColumnsIcon /> Split
      </Button>
      <Button
        size="2"
        variant="soft"
        color={value === "table" ? undefined : "gray"}
        type="button"
        aria-pressed={value === "table"}
        onClick={() => onChange("table")}
      >
        <TableIcon /> Table
      </Button>
    </Flex>
  )
}

function DownloadGroup({ zipUrl, spreadsheetUrl, monthLabel }: {
  zipUrl: string
  spreadsheetUrl: string
  monthLabel: string
}) {
  return (
    <Flex gap="2" role="group" aria-label={`Download ${monthLabel} invoices`}>
      <Button size="2" variant="soft" color="gray" asChild>
        <a href={zipUrl} download>
          <DownloadIcon /> ZIP
        </a>
      </Button>
      <Button size="2" variant="soft" color="gray" asChild>
        <a href={spreadsheetUrl} download>
          <TableIcon /> Excel
        </a>
      </Button>
    </Flex>
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

function TableCellContent({
  column,
  row,
  isProcessed = false,
  compact = false,
}: {
  column: TableColumn
  row: TableRow
  isProcessed?: boolean
  compact?: boolean
}) {
  const value = row.values[column.key]

  if (column.key === "vendor_name") {
    const vendor = typeof value === "string" && value ? value : "Unknown"
    const content = compact ? (
      <Flex align="center" gap="2">
        {isProcessed
          ? <CheckIcon style={{ color: "var(--accent-9)" }} />
          : <FileTextIcon color={row.pdf_url ? "var(--accent-9)" : "var(--gray-7)"} />}
        <Box style={{ minWidth: 0 }}>
          <Text as="div" weight="medium" truncate>{vendor}</Text>
          <Text as="div" size="1" color="gray">
            {typeof row.values.category_name === "string" && row.values.category_name
              ? row.values.category_name
              : "Uncategorized"}
          </Text>
        </Box>
      </Flex>
    ) : <Text weight="medium">{vendor}</Text>

    return !compact && row.pdf_url ? (
      <a
        href={row.pdf_url}
        target="_blank"
        rel="noreferrer"
        className="text-inherit underline decoration-dotted underline-offset-2 hover:decoration-solid"
      >
        {content}
      </a>
    ) : (
      content
    )
  }

  switch (column.kind) {
  case "country_vat": {
    const vatId = typeof value === "string" && value ? value : null
    const country = typeof row.values.vendor_country === "string"
      ? row.values.vendor_country
      : null
    if (!country && !vatId) return "—"

    return (
      <Flex align="center" gap="2">
        {country && <CountryFlag country={country} />}
        {vatId && <Text>{vatId}</Text>}
      </Flex>
    )
  }
  case "flag":
    return <CountryFlag country={typeof value === "string" ? value : null} />
  case "date":
    return formatTableDate(typeof value === "string" ? value : null)
  case "amount": {
    if (typeof value !== "number") return "—"

    const currency = row.currencies[column.key]
    return (
      <Text weight="medium">
        {currency ? formatCurrency(Math.round(value * 100), currency) : value.toFixed(2)}
      </Text>
    )
  }
  default:
    return value == null || value === "" ? "—" : String(value)
  }
}

function FullInvoiceTable({
  table,
}: {
  table: Props["table"]
}) {
  const tableWidth = table.columns.reduce((width, column) => width + column.width * 8, 0)

  return (
    <section className="flex w-full min-w-0 flex-col overflow-hidden rounded-xl border border-[var(--gray-a6)] bg-[var(--color-background)] shadow-sm" aria-label="Invoice table">
      <div className="w-full overflow-auto">
        <Table.Root size="1" style={{ minWidth: tableWidth, width: "100%" }}>
          <Table.Header style={{ position: "sticky", top: 0, zIndex: 1, backgroundColor: "var(--color-background)" }}>
            <Table.Row>
              {table.columns.map((column) => (
                <Table.ColumnHeaderCell
                  key={column.key}
                  justify={column.align}
                  style={{ minWidth: column.width * 8 }}
                >
                  {column.label}
                </Table.ColumnHeaderCell>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {table.rows.map((row) => (
              <Table.Row key={row.invoice_id}>
                {table.columns.map((column) => (
                  <Table.Cell key={column.key} justify={column.align} className="whitespace-nowrap">
                    <TableCellContent column={column} row={row} />
                  </Table.Cell>
                ))}
              </Table.Row>
            ))}
          </Table.Body>
        </Table.Root>
      </div>
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
    spreadsheet_url,
    table,
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
  const splitViewColumns = table.columns.filter((column) => column.split_view)
  const tableRowsByInvoiceId = new Map(table.rows.map((row) => [row.invoice_id, row]))

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
            <DownloadGroup
              zipUrl={download_url}
              spreadsheetUrl={spreadsheet_url}
              monthLabel={invoice_month.label}
            />
          )}
        </Flex>
      </Flex>

      {invoices.length === 0 ? (
        <Flex minHeight="420px" align="center" justify="center" direction="column" gap="2">
          <FileTextIcon width="32" height="32" color="var(--gray-8)" />
          <Text color="gray">No invoices found for {invoice_month.label}.</Text>
        </Flex>
      ) : viewMode === "table" ? (
        <FullInvoiceTable table={table} />
      ) : (
        <div className="grid min-h-[680px] overflow-hidden rounded-xl border border-[var(--gray-a6)] bg-[var(--color-background)] shadow-sm lg:h-[calc(100vh-178px)] lg:grid-cols-2">
          <section className="flex min-h-0 min-w-0 flex-col border-b border-[var(--gray-a6)] lg:border-b-0 lg:border-r" aria-label="Invoices">
            <div className="min-h-0 flex-1 overflow-auto">
              <Table.Root size="2" style={{ width: "100%" }}>
                <Table.Header style={{ position: "sticky", top: 0, zIndex: 1, backgroundColor: "var(--color-background)" }}>
                  <Table.Row>
                    {splitViewColumns.map((column) => (
                      <Table.ColumnHeaderCell
                        key={column.key}
                        justify={column.align}
                        style={{ minWidth: column.width * 8 }}
                      >
                        {column.label}
                      </Table.ColumnHeaderCell>
                    ))}
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
                        {splitViewColumns.map((column) => (
                          <Table.Cell key={column.key} justify={column.align} className="whitespace-nowrap">
                            <TableCellContent
                              column={column}
                              row={tableRowsByInvoiceId.get(invoice.id)!}
                              isProcessed={isProcessed}
                              compact
                            />
                          </Table.Cell>
                        ))}
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
