import { router } from "@inertiajs/react"
import { Text, Table, Flex, Button } from "@radix-ui/themes"
import { z } from "zod"
import DateDifferenceBadge from "./DateDifferenceBadge"
import AccountingDateEditor from "./AccountingDateEditor"

const EmailSchema = z.object({
  id: z.number(),
  subject: z.string().nullable(),
  from_name: z.string().nullable(),
  from_address: z.string().nullable(),
  date: z.string().nullable(),
})

export const InvoiceSchema = z.object({
  id: z.number(),
  vendor_name: z.string().nullable(),
  amount_cents: z.number(),
  currency: z.string().nullable(),
  accounting_date: z.string().nullish(),
  deleted_at: z.string().nullish(),
  note: z.string().nullable(),
  pdf_url: z.string().nullish(),
  email: EmailSchema.nullable(),
})

export type Invoice = z.infer<typeof InvoiceSchema>

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

type Props = {
  invoice: Invoice
}

export default function InvoiceRow({ invoice }: Props) {
  const isDeleted = !!invoice.deleted_at
  const deletedStyle = isDeleted ? { textDecoration: "line-through", opacity: 0.4 } : undefined

  return (
    <Table.Row>
      <Table.Cell>
        <Text weight="medium" style={deletedStyle}>
          {invoice.vendor_name || "Unknown"}
        </Text>
      </Table.Cell>
      <Table.Cell>
        <Text family="mono" style={deletedStyle}>
          {formatCurrency(invoice.amount_cents, invoice.currency)}
        </Text>
      </Table.Cell>
      <Table.Cell>
        <Flex align="center" gap="1">
          <Text color={invoice.accounting_date ? undefined : "gray"} style={deletedStyle}>
            {formatDate(invoice.accounting_date)}
          </Text>
          {!isDeleted && (
            <AccountingDateEditor
              invoiceId={invoice.id}
              accountingDate={invoice.accounting_date}
            />
          )}
        </Flex>
      </Table.Cell>
      <Table.Cell>
        <Text color={invoice.email?.date ? undefined : "gray"} style={deletedStyle}>
          {formatDate(invoice.email?.date)}
          <DateDifferenceBadge
            emailDate={invoice.email?.date}
            accountingDate={invoice.accounting_date}
          />
        </Text>
      </Table.Cell>
      <Table.Cell>
        <Text size="2" color="gray" style={deletedStyle}>
          {invoice.email?.subject || "—"}
        </Text>
      </Table.Cell>
      <Table.Cell>
        <Flex gap="2" justify="end">
          {invoice.pdf_url && !isDeleted && (
            <Button size="1" variant="soft" asChild>
              <a href={invoice.pdf_url} target="_blank" rel="noopener noreferrer">
                Open
              </a>
            </Button>
          )}
          {isDeleted ? (
            <Button
              size="1"
              variant="soft"
              onClick={() => router.post(`/invoices/${invoice.id}/restore`)}
            >
              Restore
            </Button>
          ) : (
            <Button
              size="1"
              variant="soft"
              color="red"
              onClick={() => router.post(`/invoices/${invoice.id}/remove`)}
            >
              Remove
            </Button>
          )}
        </Flex>
      </Table.Cell>
    </Table.Row>
  )
}
