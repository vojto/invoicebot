import { Head, Link } from "@inertiajs/react"
import { CheckIcon, DownloadIcon, ExternalLinkIcon, FileTextIcon, ResetIcon } from "@radix-ui/react-icons"
import { Box, Button, Flex, Heading, Table, Text } from "@radix-ui/themes"
import { ReactNode, useState } from "react"
import { z } from "zod"
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
  pdf_url: z.string().nullable(),
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

function countryFlag(country: string | null) {
  const countryCode = country?.trim().toUpperCase()
  if (!countryCode?.match(/^[A-Z]{2}$/)) return null

  return String.fromCodePoint(...[...countryCode].map((letter) => letter.charCodeAt(0) + 127397))
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

function InvoiceDetails({ invoice, isProcessed, onDone }: { invoice: Invoice; isProcessed: boolean; onDone: () => void }) {
  return (
    <Box p="3" style={{ borderBottom: "1px solid var(--gray-a5)", backgroundColor: "var(--color-background)" }}>
      <Flex justify="between" align="center" gap="4" wrap="wrap">
        <div className="grid flex-1 grid-cols-2 gap-4 sm:grid-cols-3">
          <Detail label="Issue date" value={formatDate(invoice.issue_date)} />
          <Detail label="Delivery date" value={formatDate(invoice.delivery_date)} />
          <Detail label="Supplier VAT ID" value={invoice.vendor_eu_vat_id} />
        </div>

        <Flex gap="2" ml="auto">
          {invoice.pdf_url && (
            <Button size="1" variant="soft" asChild>
              <a href={invoice.pdf_url} target="_blank" rel="noreferrer">
                <ExternalLinkIcon /> Open PDF
              </a>
            </Button>
          )}
          <Button size="1" onClick={onDone} disabled={isProcessed} data-testid="accountant-done">
            <CheckIcon /> {isProcessed ? "Processed" : "Done"}
          </Button>
        </Flex>
      </Flex>
    </Box>
  )
}

function PdfPane({ invoice, isProcessed, onDone }: { invoice: Invoice; isProcessed: boolean; onDone: () => void }) {
  return (
    <section className="flex min-h-[680px] min-w-0 flex-col bg-[var(--gray-a2)] lg:min-h-0" aria-label="Invoice preview">
      <InvoiceDetails invoice={invoice} isProcessed={isProcessed} onDone={onDone} />

      <div className="min-h-[520px] flex-1 p-3">
        {invoice.pdf_url ? (
          <iframe
            key={invoice.pdf_url}
            src={invoice.pdf_url}
            title={`${invoice.vendor_name || "Invoice"} PDF`}
            className="h-full min-h-[620px] w-full rounded-lg border border-[var(--gray-a6)] bg-white lg:min-h-0"
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

  const handleDone = () => {
    if (!selectedInvoice || processedInvoiceIdSet.has(selectedInvoice.id)) return

    const nextProcessedInvoiceIds = [...processedInvoiceIds, selectedInvoice.id]
    const nextProcessedInvoiceIdSet = new Set(nextProcessedInvoiceIds)
    const selectedIndex = invoices.findIndex((invoice) => invoice.id === selectedInvoice.id)
    const remainingInvoices = [...invoices.slice(selectedIndex + 1), ...invoices.slice(0, selectedIndex)]
    const nextInvoice = remainingInvoices.find((invoice) => !nextProcessedInvoiceIdSet.has(invoice.id))

    saveProcessedInvoiceIds(storageKey, nextProcessedInvoiceIds)
    setProgress({ storageKey, invoiceIds: nextProcessedInvoiceIds })
    setSelection({ month: invoice_month.key, invoiceId: nextInvoice?.id ?? null })
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
        <Flex gap="2">
          <Button size="1" variant="soft" color="gray" asChild>
            <Link href={previous_month_url}>Previous month</Link>
          </Button>
          <Button size="1" variant="soft" color="gray" asChild>
            <Link href={next_month_url}>Next month</Link>
          </Button>
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
                    const flag = countryFlag(invoice.vendor_country)

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
                          {flag ? (
                            <Text
                              as="span"
                              size="4"
                              role="img"
                              aria-label={invoice.vendor_country || undefined}
                              title={invoice.vendor_country || undefined}
                            >
                              {flag}
                            </Text>
                          ) : "—"}
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
                  <Text weight="bold" color="gray">{processedInvoiceIds.length}</Text> of {invoices.length} processed
                </Text>
                <Button
                  size="1"
                  variant="ghost"
                  color="gray"
                  disabled={processedInvoiceIds.length === 0}
                  onClick={handleReset}
                  data-testid="accountant-reset"
                >
                  <ResetIcon /> Reset
                </Button>
              </footer>
            </Flex>
          </section>

          {selectedInvoice
            ? (
              <PdfPane
                invoice={selectedInvoice}
                isProcessed={processedInvoiceIdSet.has(selectedInvoice.id)}
                onDone={handleDone}
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
