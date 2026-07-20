import { Head, Link } from "@inertiajs/react"
import { Box, Button, Flex, Heading, Table, Text } from "@radix-ui/themes"
import { ReactNode } from "react"
import { z } from "zod"
import PublicLayout from "../../../layouts/public"
import formatCurrency from "../../../lib/formatCurrency"

const PropsSchema = z.object({
  invoice_month: z.object({
    key: z.string(),
    label: z.string(),
  }),
  previous_month_url: z.string(),
  next_month_url: z.string(),
  invoices: z.array(z.object({
    id: z.number(),
    vendor_name: z.string().nullable(),
    amount_cents: z.number().nullable(),
    currency: z.string().nullable(),
    accounting_date: z.string().nullable(),
    pdf_url: z.string().nullable(),
  })),
})

type Props = z.infer<typeof PropsSchema>

function formatDate(value: string | null) {
  if (!value) return "—"

  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(value))
}

function AccountantInvoicesShow(props: Props) {
  const { invoice_month, previous_month_url, next_month_url, invoices } = PropsSchema.parse(props)

  return (
    <>
      <Head title={`Shared invoices — ${invoice_month.label}`}>
        <meta name="robots" content="noindex, nofollow, noarchive" />
        <meta name="referrer" content="no-referrer" />
      </Head>

      <Flex justify="between" align="center" mb="6" wrap="wrap" gap="3">
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
        <Text color="gray">No invoices found for {invoice_month.label}.</Text>
      ) : (
        <Box className="overflow-x-auto">
          <Table.Root variant="surface" size="2">
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeaderCell>Vendor</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell width="160px">Date</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell width="150px">Amount</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell width="100px">PDF</Table.ColumnHeaderCell>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {invoices.map((invoice) => (
                <Table.Row key={invoice.id}>
                  <Table.Cell>
                    <Text weight="medium">{invoice.vendor_name || "Unknown"}</Text>
                  </Table.Cell>
                  <Table.Cell>{formatDate(invoice.accounting_date)}</Table.Cell>
                  <Table.Cell>
                    {invoice.amount_cents == null
                      ? "—"
                      : formatCurrency(invoice.amount_cents, invoice.currency)}
                  </Table.Cell>
                  <Table.Cell>
                    {invoice.pdf_url ? (
                      <a href={invoice.pdf_url} target="_blank" rel="noreferrer">Open</a>
                    ) : (
                      <Text color="gray">—</Text>
                    )}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table.Body>
          </Table.Root>
        </Box>
      )}
    </>
  )
}

AccountantInvoicesShow.layout = (page: ReactNode) => <PublicLayout>{page}</PublicLayout>

export default AccountantInvoicesShow
