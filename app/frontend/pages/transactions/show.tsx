import { Head, Link } from "@inertiajs/react"
import { Box, Flex, Heading, Text, Table, Button, Badge } from "@radix-ui/themes"
import { ArrowLeftIcon, FileTextIcon } from "@radix-ui/react-icons"
import { z } from "zod"
import PdfPreview from "../../components/PdfPreview"

const InvoiceSchema = z.object({
  id: z.number(),
  vendor_name: z.string(),
  amount_label: z.string(),
  issue_date: z.string().nullable(),
  pdf_url: z.string().nullable(),
})

const TransactionSchema = z.object({
  id: z.number(),
  direction: z.enum(["credit", "debit"]),
  booking_date: z.string().nullable(),
  value_date: z.string().nullable(),
  amount_label: z.string(),
  original_amount_label: z.string().nullable(),
  vendor_name: z.string().nullable(),
  description: z.string().nullable(),
  creditor_name: z.string().nullable(),
  creditor_iban: z.string().nullable(),
  debtor_name: z.string().nullable(),
  debtor_iban: z.string().nullable(),
  bank_name: z.string().nullable(),
  hidden_at: z.string().nullable(),
  invoice: InvoiceSchema.nullable(),
})

const PropsSchema = z.object({
  transaction: TransactionSchema,
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
  const d = new Date(iso + "T00:00:00")
  return d.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" })
}

export default function TransactionsShow(props: Props) {
  const { transaction: tx } = PropsSchema.parse(props)

  return (
    <>
      <Head title={`Transaction – ${tx.vendor_name || "Unknown"}`} />
      <Flex mb="4" align="center" gap="2">
        <Button variant="ghost" size="1" asChild>
          <Link href="/transactions">
            <ArrowLeftIcon /> Back to transactions
          </Link>
        </Button>
      </Flex>

      <Heading size="6" mb="4">Transaction Details</Heading>

      <Flex gap="6" wrap="wrap">
        <Box style={{ flex: "1 1 400px", minWidth: 0 }}>
          <Table.Root variant="surface" size="2">
            <Table.Body>
              <DetailRow label="Vendor" value={tx.vendor_name} />
              <DetailRow label="Bank" value={tx.bank_name} />
              <DetailRow
                label="Amount"
                value={
                  <Text color={tx.direction === "credit" ? "green" : "red"}>
                    {tx.amount_label}
                  </Text>
                }
              />
              {tx.original_amount_label && (
                <DetailRow label="Original Amount" value={tx.original_amount_label} />
              )}
              <DetailRow label="Direction" value={
                <Badge color={tx.direction === "credit" ? "green" : "red"}>
                  {tx.direction}
                </Badge>
              } />
              <DetailRow label="Booking Date" value={formatDate(tx.booking_date)} />
              <DetailRow label="Value Date" value={formatDate(tx.value_date)} />
              <DetailRow label="Description" value={tx.description} />
              <DetailRow label="Creditor" value={tx.creditor_name} />
              <DetailRow label="Creditor IBAN" value={tx.creditor_iban} />
              <DetailRow label="Debtor" value={tx.debtor_name} />
              <DetailRow label="Debtor IBAN" value={tx.debtor_iban} />
              {tx.hidden_at && (
                <DetailRow label="Status" value={
                  <Badge color="gray">Hidden</Badge>
                } />
              )}
            </Table.Body>
          </Table.Root>

          {tx.invoice && (
            <Box mt="6">
              <Heading size="4" mb="3">Linked Invoice</Heading>
              <Table.Root variant="surface" size="2">
                <Table.Body>
                  <DetailRow label="Vendor" value={tx.invoice.vendor_name} />
                  <DetailRow label="Amount" value={tx.invoice.amount_label} />
                  <DetailRow label="Issue Date" value={formatDate(tx.invoice.issue_date)} />
                  {tx.invoice.pdf_url && (
                    <DetailRow label="PDF" value={
                      <Button size="1" variant="soft" asChild>
                        <a href={tx.invoice.pdf_url} target="_blank" rel="noopener noreferrer">
                          <FileTextIcon /> Open PDF
                        </a>
                      </Button>
                    } />
                  )}
                </Table.Body>
              </Table.Root>
            </Box>
          )}
        </Box>

        {tx.invoice?.pdf_url && (
          <Box style={{ flex: "0 0 auto" }}>
            <PdfPreview url={tx.invoice.pdf_url} />
          </Box>
        )}
      </Flex>
    </>
  )
}
