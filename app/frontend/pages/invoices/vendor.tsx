import { Head, Link } from "@inertiajs/react"
import { ArrowLeftIcon } from "@radix-ui/react-icons"
import { Box, Button, Flex, Heading, Text } from "@radix-ui/themes"
import { z } from "zod"
import InvoiceTable from "../../components/InvoiceTable"
import { InvoiceSchema } from "../../components/InvoiceRow"
import { CategorySchema } from "../../components/InvoiceCategorySelect"

/*
 * Lists every invoice from one vendor, newest first. Reached by clicking the
 * vendor name on an invoice's detail page; matches the vendor name exactly.
 */

const PropsSchema = z.object({
  vendor_name: z.string(),
  invoices: z.array(InvoiceSchema),
  categories: z.array(CategorySchema),
})

type Props = z.infer<typeof PropsSchema>

export default function InvoicesVendor(props: Props) {
  const { vendor_name, invoices, categories } = PropsSchema.parse(props)

  return (
    <>
      <Head title={`Invoices — ${vendor_name}`} />
      <Flex mb="4" align="center" gap="2">
        <Button variant="ghost" size="1" asChild>
          <Link href="/dashboard">
            <ArrowLeftIcon /> Back to invoices
          </Link>
        </Button>
      </Flex>

      <Box mb="6">
        <Heading size="6">{vendor_name}</Heading>
        <Text size="2" color="gray">{invoices.length} invoices</Text>
      </Box>

      {invoices.length === 0 ? (
        <Text color="gray">No invoices found for {vendor_name}.</Text>
      ) : (
        <InvoiceTable invoices={invoices} categories={categories} showCategory />
      )}
    </>
  )
}
