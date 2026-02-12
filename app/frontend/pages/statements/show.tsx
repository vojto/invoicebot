import { Head, Link } from "@inertiajs/react"
import { Box, Button, Flex, Heading, Text } from "@radix-ui/themes"
import { z } from "zod"

const StatementRowSchema = z.object({
  key: z.string(),
  transaction_id: z.number().nullable(),
  invoice_id: z.number().nullable(),
  bank_name: z.string(),
  accounting_date_label: z.string(),
  transaction_date_label: z.string(),
  amount_label: z.string(),
  original_amount_label: z.string(),
  vendor_label: z.string(),
  invoice_label: z.string(),
  hidden: z.boolean(),
  invoice_missing: z.boolean(),
  transaction_missing: z.boolean(),
})

type StatementRow = z.infer<typeof StatementRowSchema>

const StatementSectionSchema = z.object({
  month_key: z.string(),
  month_label: z.string(),
  description: z.string(),
  rows: z.array(StatementRowSchema),
})

type StatementSection = z.infer<typeof StatementSectionSchema>

const PropsSchema = z.object({
  statement_month_key: z.string(),
  statement_month_label: z.string(),
  generated_at: z.string(),
  primary_section: StatementSectionSchema,
  supplemental_sections: z.array(StatementSectionSchema),
  invoice_only_rows: z.array(StatementRowSchema),
})

type Props = z.infer<typeof PropsSchema>

function SectionTable({ title, description, rows }: { title: string, description: string, rows: StatementRow[] }) {
  if (rows.length === 0) return null

  return (
    <Box className="statement-section mb-8">
      <Heading as="h2" size="4" mb="1">{title}</Heading>
      <Text as="p" size="2" color="gray" mb="3">{description}</Text>

      <Box className="overflow-x-auto">
        <table className="statement-table w-full border-collapse text-sm">
          <thead>
            <tr>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Banka</th>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Datum transakcie</th>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Datum zauctovania</th>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Suma</th>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Povodna suma</th>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Dodavatel</th>
              <th className="border border-gray-300 px-2 py-1 text-left font-semibold">Faktura</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.key} className={row.hidden ? "line-through opacity-60" : undefined}>
                <td className="border border-gray-300 px-2 py-1 align-top">{row.bank_name}</td>
                <td className="border border-gray-300 px-2 py-1 align-top">{row.transaction_date_label}</td>
                <td className="border border-gray-300 px-2 py-1 align-top">{row.accounting_date_label}</td>
                <td className="border border-gray-300 px-2 py-1 align-top">{row.amount_label}</td>
                <td className="border border-gray-300 px-2 py-1 align-top">{row.original_amount_label}</td>
                <td className="border border-gray-300 px-2 py-1 align-top">{row.vendor_label}</td>
                <td className="border border-gray-300 px-2 py-1 align-top">
                  {row.invoice_missing ? (
                    <span className="font-semibold uppercase tracking-wide">CHYBA FAKTURA</span>
                  ) : row.transaction_missing ? (
                    <span>
                      <span className="font-semibold uppercase tracking-wide">CHYBA TRANSAKCIA</span>
                      <span> · {row.invoice_label}</span>
                    </span>
                  ) : (
                    row.invoice_label
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Box>
    </Box>
  )
}

export default function StatementsShow(props: Props) {
  const {
    statement_month_key,
    statement_month_label,
    generated_at,
    primary_section,
    supplemental_sections,
    invoice_only_rows,
  } = PropsSchema.parse(props)

  const generatedAtLabel = new Date(generated_at).toLocaleString("sk-SK", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  })

  return (
    <>
      <Head title={`Vypis ${statement_month_label}`} />
      <style>{`
        @media print {
          .no-print { display: none !important; }
          .statement-shell { margin: 0 !important; max-width: none !important; padding: 0 !important; }
          .statement-section { page-break-inside: avoid; }
          .statement-table { font-size: 12px; }
        }
      `}</style>

      <Box className="statement-shell mx-auto max-w-[1200px] bg-white px-5 py-6 text-black">
        <Flex className="no-print mb-5" justify="between" align="center">
          <Button variant="soft" asChild>
            <Link href="/transactions">Spat na transakcie</Link>
          </Button>
          <Button onClick={() => window.print()}>Tlacit</Button>
        </Flex>

        <Heading size="6" mb="1">Mesacny vypis: {statement_month_label}</Heading>
        <Text as="p" size="2" color="gray" mb="6">
          Obdobie: {statement_month_key}. Vygenerovane: {generatedAtLabel}
        </Text>

        <SectionTable
          title={`Transakcie: ${primary_section.month_label}`}
          description={primary_section.description}
          rows={primary_section.rows}
        />

        {supplemental_sections.map((section) => (
          <SectionTable
            key={`supplemental-${section.month_key}`}
            title={`Transakcie: ${section.month_label}`}
            description={section.description}
            rows={section.rows}
          />
        ))}

        <SectionTable
          title={`Faktury v ${statement_month_label} bez priradenej transakcie`}
          description={`Tieto faktury su zauctovane v ${statement_month_label}, ale nie su prepojene so ziadnou bankovou transakciou.`}
          rows={invoice_only_rows}
        />
      </Box>
    </>
  )
}

StatementsShow.layout = (page: React.ReactNode) => page
