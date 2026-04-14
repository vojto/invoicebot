import { Link, router } from "@inertiajs/react"
import { Text, Table, Flex, Button, Badge } from "@radix-ui/themes"
import { z } from "zod"
import DateDifferenceBadge from "./DateDifferenceBadge"
import AccountingDateEditor from "./AccountingDateEditor"
import InvoicePdfPopover from "./InvoicePdfPopover"

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
  amount_cents: z.number().nullable(),
  currency: z.string().nullable(),
  accounting_date: z.string().nullish(),
  deleted_at: z.string().nullish(),
  note: z.string().nullable(),
  pdf_url: z.string().nullish(),
  email: EmailSchema.nullable(),
  bank_transaction: z.object({
    id: z.number(),
    vendor_name: z.string().nullable(),
  }).nullable(),
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
  const isLinked = !!invoice.bank_transaction
  const deletedStyle = isDeleted ? { textDecoration: "line-through", opacity: 0.4 } : undefined
  const rowClass = isLinked && !isDeleted ? "bg-blue-50" : ""

  return (
    <Table.Row className={rowClass}>
      <Table.Cell>
        <Flex align="center" gap="1">
          <Link
            href={`/invoices/${invoice.id}`}
            className="text-inherit underline decoration-dotted hover:decoration-solid underline-offset-2"
            style={deletedStyle}
          >
            <Text as="span" weight="medium">
              {invoice.vendor_name || "Unknown"}
            </Text>
          </Link>
          {invoice.pdf_url && !isDeleted && (
            <InvoicePdfPopover invoiceId={invoice.id} />
          )}
        </Flex>
      </Table.Cell>
      <Table.Cell>
        <Text style={deletedStyle}>
          {invoice.amount_cents != null ? formatCurrency(invoice.amount_cents, invoice.currency) : "—"}
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
        {invoice.bank_transaction && (
          <Badge size="1" variant="soft" color="blue">
            {invoice.bank_transaction.vendor_name || "Transaction"}
          </Badge>
        )}
      </Table.Cell>
      <Table.Cell>
        <Flex gap="2" justify="end">
          {isDeleted ? (
            <Button
              size="1"
              variant="soft"
              onClick={() => router.post(`/invoices/${invoice.id}/restore`, {}, { preserveScroll: true })}
            >
              Restore
            </Button>
          ) : (
            <Button
              size="1"
              variant="soft"
              color="red"
              onClick={() => router.post(`/invoices/${invoice.id}/remove`, {}, { preserveScroll: true })}
            >
              Remove
            </Button>
          )}
        </Flex>
      </Table.Cell>
    </Table.Row>
  )
}
