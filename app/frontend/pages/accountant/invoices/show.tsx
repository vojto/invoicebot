import { Head, Link } from "@inertiajs/react"
import { CheckIcon, ExternalLinkIcon, FileTextIcon, ResetIcon } from "@radix-ui/react-icons"
import { Badge, Box, Button, Flex, Heading, Table, Text } from "@radix-ui/themes"
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
  document_type: z.enum(["invoice", "credit_note"]),
  vendor_country: z.string().nullable(),
  vendor_eu_vat_id: z.string().nullable(),
  note: z.string().nullable(),
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

function documentTypeLabel(invoice: Invoice) {
  return invoice.document_type === "credit_note" ? "Credit note" : "Invoice"
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

function InvoiceDetails({ invoice, onDone }: { invoice: Invoice; onDone: () => void }) {
  return (
    <Box p="4" style={{ borderBottom: "1px solid var(--gray-a5)", backgroundColor: "var(--color-background)" }}>
      <Flex justify="between" align="start" gap="4" wrap="wrap">
        <Box>
          <Flex align="center" gap="2" mb="2">
            <Badge color={invoice.document_type === "credit_note" ? "orange" : "blue"}>
              {documentTypeLabel(invoice)}
            </Badge>
            {invoice.vendor_country && <Badge color="gray">{invoice.vendor_country}</Badge>}
          </Flex>
          <Heading size="5">{invoice.vendor_name || "Unknown vendor"}</Heading>
          <Text as="div" size="4" weight="bold" mt="1">{amountLabel(invoice)}</Text>
        </Box>

        <Flex gap="2">
          {invoice.pdf_url && (
            <Button variant="soft" asChild>
              <a href={invoice.pdf_url} target="_blank" rel="noreferrer">
                <ExternalLinkIcon /> Open PDF
              </a>
            </Button>
          )}
          <Button onClick={onDone} data-testid="accountant-done">
            <CheckIcon /> Done
          </Button>
        </Flex>
      </Flex>

      <div className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Detail label="Accounting date" value={formatDate(invoice.accounting_date)} />
        <Detail label="Issue date" value={formatDate(invoice.issue_date)} />
        <Detail label="Delivery date" value={formatDate(invoice.delivery_date)} />
        <Detail label="Supplier VAT ID" value={invoice.vendor_eu_vat_id} />
      </div>

      {invoice.note && (
        <Box mt="4" pt="3" style={{ borderTop: "1px solid var(--gray-a4)" }}>
          <Text as="div" size="1" color="gray" mb="1">Note</Text>
          <Text as="div" size="2">{invoice.note}</Text>
        </Box>
      )}
    </Box>
  )
}

function PdfPane({ invoice, onDone }: { invoice: Invoice; onDone: () => void }) {
  return (
    <section className="flex min-h-[680px] min-w-0 flex-col bg-[var(--gray-a2)] lg:min-h-0" aria-label="Invoice preview">
      <InvoiceDetails invoice={invoice} onDone={onDone} />

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
  const visibleInvoices = invoices.filter((invoice) => !processedInvoiceIdSet.has(invoice.id))
  const [selection, setSelection] = useState({
    month: invoice_month.key,
    invoiceId: visibleInvoices[0]?.id ?? null,
  })
  const selectedInvoiceId = selection.month === invoice_month.key
    ? selection.invoiceId
    : visibleInvoices[0]?.id ?? null
  const selectedInvoice = visibleInvoices.find((invoice) => invoice.id === selectedInvoiceId) || visibleInvoices[0]

  const handleDone = () => {
    if (!selectedInvoice) return

    const selectedIndex = visibleInvoices.findIndex((invoice) => invoice.id === selectedInvoice.id)
    const nextInvoice = visibleInvoices[selectedIndex + 1] || visibleInvoices[selectedIndex - 1]
    const nextProcessedInvoiceIds = [...processedInvoiceIds, selectedInvoice.id]

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

      <Flex justify="between" align="center" mb="5" wrap="wrap" gap="3">
        <Box>
          <Heading size="6">Invoices — {invoice_month.label}</Heading>
          <Text size="2" color="gray">{invoices.length} invoices</Text>
        </Box>
        <Flex gap="2">
          <Button variant="soft" color="gray" asChild>
            <Link href={previous_month_url}>Previous month</Link>
          </Button>
          <Button variant="soft" color="gray" asChild>
            <Link href={next_month_url}>Next month</Link>
          </Button>
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
                    <Table.ColumnHeaderCell width="130px">Date</Table.ColumnHeaderCell>
                    <Table.ColumnHeaderCell width="130px" justify="end">Amount</Table.ColumnHeaderCell>
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {visibleInvoices.map((invoice) => {
                    const isSelected = invoice.id === selectedInvoice?.id

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
                        }}
                      >
                        <Table.Cell>
                          <Flex align="center" gap="2">
                            <FileTextIcon color={invoice.pdf_url ? "var(--accent-9)" : "var(--gray-7)"} />
                            <Box style={{ minWidth: 0 }}>
                              <Text as="div" weight="medium" truncate>{invoice.vendor_name || "Unknown"}</Text>
                              <Text as="div" size="1" color="gray">{documentTypeLabel(invoice)}</Text>
                            </Box>
                          </Flex>
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

              {visibleInvoices.length === 0 && (
                <Flex align="center" justify="center" py="9">
                  <Text size="2" color="gray">No invoices left to review.</Text>
                </Flex>
              )}
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
            ? <PdfPane invoice={selectedInvoice} onDone={handleDone} />
            : <CompletedPane />}
        </div>
      )}
    </>
  )
}

AccountantInvoicesShow.layout = (page: ReactNode) => <PublicLayout>{page}</PublicLayout>

export default AccountantInvoicesShow
