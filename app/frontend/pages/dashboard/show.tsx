import { Head } from "@inertiajs/react"
import { Heading, Box, Text, Table, Flex } from "@radix-ui/themes"
import { z } from "zod"
import InvoiceRow, { InvoiceSchema, type Invoice } from "~/components/InvoiceRow"

const PropsSchema = z.object({
  invoices: z.array(InvoiceSchema),
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
                      <Table.ColumnHeaderCell width="400px">Vendor</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="120px">Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Accounting Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="200px">Email Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Email Subject</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Actions</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {monthInvoices.map((invoice) => (
                      <InvoiceRow key={invoice.id} invoice={invoice} />
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
