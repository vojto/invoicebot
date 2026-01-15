import { Head } from "@inertiajs/react"
import { Heading, Box, Text, Table } from "@radix-ui/themes"
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

function formatDate(dateString: string | null): string {
  if (!dateString) return "—"

  const date = new Date(dateString)
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(date)
}

export default function DashboardShow(props: Props) {
  const { invoices } = PropsSchema.parse(props)

  return (
    <>
      <Head title="Dashboard" />
      <Box>
        <Heading size="5" as="h1" mb="6">
          Recent Invoices
        </Heading>

        {invoices.length === 0 ? (
          <Text color="gray">
            No invoices found. Invoices will appear here once emails are
            processed.
          </Text>
        ) : (
          <Table.Root variant="surface" size="2">
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell>Amount</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell>Date</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell>Email Subject</Table.ColumnHeaderCell>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {invoices.map((invoice) => (
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
        )}
      </Box>
    </>
  )
}
