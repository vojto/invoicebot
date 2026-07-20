import { Head, Link } from "@inertiajs/react"
import { Box, Button, Flex, Heading, Text } from "@radix-ui/themes"
import { DownloadIcon } from "@radix-ui/react-icons"
import { z } from "zod"
import CategorySpendingBreakdown, { SpendingBreakdownSchema } from "../../components/CategorySpendingBreakdown"
import InvoiceTable from "../../components/InvoiceTable"
import { InvoiceSchema } from "../../components/InvoiceRow"
import PdfDropZone from "../../components/PdfDropZone"
import { CategorySchema } from "../../components/TransactionCategorySelect"

const PropsSchema = z.object({
  invoice_month: z.object({
    key: z.string(),
    label: z.string(),
  }),
  invoices: z.array(InvoiceSchema),
  categories: z.array(CategorySchema),
  spending_breakdowns: z.array(SpendingBreakdownSchema),
})

type Props = z.infer<typeof PropsSchema>

export default function InvoicesIndex(props: Props) {
  const { invoice_month, invoices, categories, spending_breakdowns } = PropsSchema.parse(props)
  const activeInvoices = invoices.filter((invoice) => !invoice.deleted_at)

  return (
    <PdfDropZone enabled={true}>
      <Head title={`Invoices — ${invoice_month.label}`} />
      <Box>
        <Flex justify="between" align="center" mb="6" wrap="wrap" gap="3">
          <Box>
            <Heading size="6">Invoices — {invoice_month.label}</Heading>
            <Text size="2" color="gray">{activeInvoices.length} active invoices</Text>
          </Box>
          <Flex gap="2">
            <Button variant="soft" color="gray" asChild>
              <Link href="/dashboard">Back to Invoices</Link>
            </Button>
            {activeInvoices.length > 0 && (
              <Button variant="soft" asChild>
                <a href={`/invoices/download?month=${invoice_month.key}`} download>
                  <DownloadIcon />
                  Download ZIP
                </a>
              </Button>
            )}
          </Flex>
        </Flex>

        <CategorySpendingBreakdown breakdowns={spending_breakdowns} />

        <Heading size="5" mb="4">Invoices</Heading>
        {invoices.length === 0 ? (
          <Text color="gray">No invoices found for {invoice_month.label}.</Text>
        ) : (
          <InvoiceTable invoices={invoices} categories={categories} showCategory />
        )}
      </Box>
    </PdfDropZone>
  )
}
