import { Head } from "@inertiajs/react"
import { Heading, Box, Text, Table, Flex } from "@radix-ui/themes"
import { z } from "zod"

const EmailSchema = z.object({
  id: z.number(),
  subject: z.string().nullable(),
  from_name: z.string().nullable(),
  from_address: z.string().nullable(),
  date: z.string().nullable(),
})

const InvoiceSchema = z.object({
  id: z.number(),
  vendor_name: z.string().nullable(),
  amount_cents: z.number(),
  currency: z.string().nullable(),
  accounting_date: z.string().nullish(),
  note: z.string().nullable(),
  email: EmailSchema,
})

const PropsSchema = z.object({
  invoices: z.array(InvoiceSchema),
})

type Props = z.infer<typeof PropsSchema>
type Invoice = z.infer<typeof InvoiceSchema>

function formatCurrency(amountCents: number, currency: string | null): string {
  const amount = amountCents / 100
  const currencyCode = currency || "USD"

  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currencyCode,
    }).format(amount)
  } catch {
    return `${amount.toFixed(2)} ${currencyCode}`
  }
}

function formatDate(dateString: string | null | undefined): string {
  if (!dateString) return "—"

  const date = new Date(dateString)
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(date)
}

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

function groupInvoicesByMonth(invoices: Invoice[]): Map<string, Invoice[]> {
  const groups = new Map<string, Invoice[]>()

  for (const invoice of invoices) {
    const key = getMonthKey(invoice.accounting_date)
    const existing = groups.get(key) || []
    existing.push(invoice)
    groups.set(key, existing)
  }

  // Sort invoices within each group (newest first)
  for (const [key, groupInvoices] of groups) {
    groupInvoices.sort((a, b) => {
      if (!a.accounting_date) return 1
      if (!b.accounting_date) return -1
      return new Date(b.accounting_date).getTime() - new Date(a.accounting_date).getTime()
    })
    groups.set(key, groupInvoices)
  }

  // Sort groups by month key (newest first)
  const sortedEntries = [...groups.entries()].sort((a, b) => {
    if (a[0] === "unknown") return 1
    if (b[0] === "unknown") return -1
    return b[0].localeCompare(a[0])
  })

  return new Map(sortedEntries)
}

export default function DashboardShow(props: Props) {
  const { invoices } = PropsSchema.parse(props)
  const groupedInvoices = groupInvoicesByMonth(invoices)

  return (
    <>
      <Head title="Dashboard" />
      <Box>
        {invoices.length === 0 ? (
          <Text color="gray">
            No invoices found. Invoices will appear here once emails are
            processed.
          </Text>
        ) : (
          <Flex direction="column" gap="6">
            {[...groupedInvoices.entries()].map(([monthKey, monthInvoices]) => (
              <Box key={monthKey}>
                <Heading size="5" as="h2" mb="4">
                  {formatMonthHeading(monthKey)}
                </Heading>
                <Table.Root variant="surface" size="2">
                  <Table.Header>
                    <Table.Row>
                      <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Accounting Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Email Subject</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {monthInvoices.map((invoice) => (
                      <Table.Row key={invoice.id}>
                        <Table.Cell>
                          <Text weight="medium">
                            {invoice.vendor_name || "Unknown"}
                          </Text>
                        </Table.Cell>
                        <Table.Cell>
                          <Text family="mono">
                            {formatCurrency(invoice.amount_cents, invoice.currency)}
                          </Text>
                        </Table.Cell>
                        <Table.Cell>
                          <Text color={invoice.accounting_date ? undefined : "gray"}>
                            {formatDate(invoice.accounting_date)}
                          </Text>
                        </Table.Cell>
                        <Table.Cell>
                          <Text size="2" color="gray">
                            {invoice.email.subject || "No subject"}
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
