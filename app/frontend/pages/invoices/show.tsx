import { Head, Link } from "@inertiajs/react"
import { ArrowLeftIcon, ExternalLinkIcon, FileTextIcon } from "@radix-ui/react-icons"
import { Badge, Box, Button, Flex, Heading, Table, Text } from "@radix-ui/themes"
import { z } from "zod"
import AccountingDateEditor from "../../components/AccountingDateEditor"
import PdfPreview from "../../components/PdfPreview"

const EmailSchema = z.object({
  id: z.number(),
  subject: z.string().nullable(),
  from_name: z.string().nullable(),
  from_address: z.string().nullable(),
  date: z.string().nullable(),
})

const TransactionSchema = z.object({
  id: z.number(),
  vendor_name: z.string().nullable(),
  amount_label: z.string(),
  booking_date: z.string().nullable(),
})

const InvoiceSchema = z.object({
  id: z.number(),
  vendor_name: z.string().nullable(),
  amount_label: z.string(),
  currency: z.string().nullable(),
  accounting_date: z.string().nullable(),
  issue_date: z.string().nullable(),
  delivery_date: z.string().nullable(),
  note: z.string().nullable(),
  deleted_at: z.string().nullable(),
  pdf_url: z.string().nullable(),
  email: EmailSchema.nullable(),
  bank_transaction: TransactionSchema.nullable(),
})

const PropsSchema = z.object({
  invoice: InvoiceSchema,
})

type Props = z.infer<typeof PropsSchema>

function DetailRow({ label, value }: { label: string; value: React.ReactNode }) {
  if (!value) return null

  return (
    <Table.Row>
      <Table.Cell style={{ width: 180 }}>
        <Text weight="medium" color="gray">{label}</Text>
      </Table.Cell>
      <Table.Cell>{value}</Table.Cell>
    </Table.Row>
  )
}

function formatDate(iso: string | null) {
  if (!iso) return null
  const value = iso.includes("T") ? iso : `${iso}T00:00:00`
  return new Date(value).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  })
}


export default function InvoicesShow(props: Props) {
  const { invoice } = PropsSchema.parse(props)

  return (
    <>
      <Head title={`Invoice – ${invoice.vendor_name || "Unknown"}`} />
      <Flex mb="4" align="center" gap="2">
        <Button variant="ghost" size="1" asChild>
          <Link href="/dashboard">
            <ArrowLeftIcon /> Back to invoices
          </Link>
        </Button>
      </Flex>

      <Heading size="6" mb="4">Invoice Details</Heading>

      <Flex gap="6" wrap="wrap">
        <Box style={{ flex: "1 1 0", minWidth: 0 }}>
          <Table.Root variant="surface" size="2">
            <Table.Body>
              <DetailRow label="Vendor" value={invoice.vendor_name} />
              <DetailRow label="Amount" value={invoice.amount_label} />
              <DetailRow label="Currency" value={invoice.currency} />
              <DetailRow
                label="Accounting Date"
                value={
                  <Flex align="center" gap="2">
                    <Text color={invoice.accounting_date ? undefined : "gray"}>
                      {formatDate(invoice.accounting_date) || "—"}
                    </Text>
                    {!invoice.deleted_at && (
                      <AccountingDateEditor
                        invoiceId={invoice.id}
                        accountingDate={invoice.accounting_date}
                      />
                    )}
                  </Flex>
                }
              />
              <DetailRow label="Issue Date" value={formatDate(invoice.issue_date)} />
              <DetailRow label="Delivery Date" value={formatDate(invoice.delivery_date)} />
              <DetailRow label="Note" value={invoice.note} />
              {invoice.deleted_at && (
                <DetailRow label="Status" value={<Badge color="gray">Removed</Badge>} />
              )}
              {invoice.pdf_url && (
                <DetailRow
                  label="PDF"
                  value={
                    <Button size="1" variant="soft" asChild>
                      <a href={invoice.pdf_url} target="_blank" rel="noopener noreferrer">
                        <FileTextIcon /> Open PDF
                      </a>
                    </Button>
                  }
                />
              )}
            </Table.Body>
          </Table.Root>

          {invoice.bank_transaction && (
            <Box mt="6">
              <Heading size="4" mb="3">Linked Transaction</Heading>
              <Table.Root variant="surface" size="2">
                <Table.Body>
                  <DetailRow label="Vendor" value={invoice.bank_transaction.vendor_name} />
                  <DetailRow label="Amount" value={invoice.bank_transaction.amount_label} />
                  <DetailRow label="Booking Date" value={formatDate(invoice.bank_transaction.booking_date)} />
                  <DetailRow
                    label="Details"
                    value={
                      <Button size="1" variant="soft" asChild>
                        <Link href={`/transactions/${invoice.bank_transaction.id}`}>
                          <ExternalLinkIcon /> View transaction
                        </Link>
                      </Button>
                    }
                  />
                </Table.Body>
              </Table.Root>
            </Box>
          )}

          {invoice.email && (
            <Box mt="6">
              <Heading size="4" mb="3">Source Email</Heading>
              <Table.Root variant="surface" size="2">
                <Table.Body>
                  <DetailRow label="Subject" value={invoice.email.subject} />
                  <DetailRow label="From" value={invoice.email.from_name || invoice.email.from_address} />
                  <DetailRow label="Address" value={invoice.email.from_address} />
                  <DetailRow label="Date" value={formatDate(invoice.email.date)} />
                </Table.Body>
              </Table.Root>
            </Box>
          )}
        </Box>

        <Box style={{ flex: "1 1 0", minWidth: 0 }}>
          {invoice.pdf_url ? (
            <PdfPreview invoiceId={invoice.id} />
          ) : (
            <Text color="gray" size="2">No preview available.</Text>
          )}
        </Box>
      </Flex>
    </>
  )
}
