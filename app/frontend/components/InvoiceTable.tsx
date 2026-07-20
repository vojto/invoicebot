import { Box, Table } from "@radix-ui/themes"
import { z } from "zod"
import InvoiceRow, { InvoiceSchema } from "./InvoiceRow"
import { CategorySchema } from "./TransactionCategorySelect"

const PropsSchema = z.object({
  invoices: z.array(InvoiceSchema),
  categories: z.array(CategorySchema).optional(),
  showCategory: z.boolean().optional(),
})

type Props = z.infer<typeof PropsSchema>

export default function InvoiceTable(props: Props) {
  const { invoices, categories = [], showCategory = false } = PropsSchema.parse(props)

  return (
    <Box className="overflow-x-auto">
      <Table.Root variant="surface" size="2">
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeaderCell width="400px">Vendor</Table.ColumnHeaderCell>
            <Table.ColumnHeaderCell width="120px">Amount</Table.ColumnHeaderCell>
            <Table.ColumnHeaderCell width="140px">Accounting Date</Table.ColumnHeaderCell>
            <Table.ColumnHeaderCell width="200px">Email Date</Table.ColumnHeaderCell>
            <Table.ColumnHeaderCell>Email Subject</Table.ColumnHeaderCell>
            <Table.ColumnHeaderCell>Transaction</Table.ColumnHeaderCell>
            {showCategory && <Table.ColumnHeaderCell width="190px">Category</Table.ColumnHeaderCell>}
            <Table.ColumnHeaderCell width="140px">Actions</Table.ColumnHeaderCell>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {invoices.map((invoice) => (
            <InvoiceRow
              key={invoice.id}
              invoice={invoice}
              categories={categories}
              showCategory={showCategory}
            />
          ))}
        </Table.Body>
      </Table.Root>
    </Box>
  )
}
