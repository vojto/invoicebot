import { Box, Card, Flex, Heading, Table, Text } from "@radix-ui/themes"
import { z } from "zod"

export const SpendingBreakdownSchema = z.object({
  currency: z.string(),
  total_amount_cents: z.number(),
  total_amount_label: z.string(),
  unconverted_currencies: z.array(z.string()),
  categories: z.array(z.object({
    id: z.number().nullable(),
    name: z.string(),
    uncategorized: z.boolean(),
    amount_cents: z.number(),
    amount_label: z.string(),
  })),
})

const PropsSchema = z.object({
  breakdown: SpendingBreakdownSchema,
})

type Props = z.infer<typeof PropsSchema>
type SpendingBreakdown = z.infer<typeof SpendingBreakdownSchema>

const CHART_COLORS = [
  "var(--blue-9)",
  "var(--violet-9)",
  "var(--green-9)",
  "var(--orange-9)",
  "var(--pink-9)",
  "var(--cyan-9)",
  "var(--amber-9)",
  "var(--indigo-9)",
]
const UNCATEGORIZED_COLOR = "var(--gray-8)"

function categoryColor(category: SpendingBreakdown["categories"][number], index: number) {
  return category.uncategorized ? UNCATEGORIZED_COLOR : CHART_COLORS[index % CHART_COLORS.length]
}

function percentage(amountCents: number, totalAmountCents: number) {
  return totalAmountCents === 0 ? 0 : (amountCents / totalAmountCents) * 100
}

function chartGradient(breakdown: SpendingBreakdown) {
  let start = 0
  const segments = breakdown.categories.map((category, index) => {
    const end = start + percentage(category.amount_cents, breakdown.total_amount_cents)
    const segment = `${categoryColor(category, index)} ${start}% ${end}%`
    start = end
    return segment
  })

  return `conic-gradient(${segments.join(", ")})`
}

function BreakdownCard({ breakdown }: { breakdown: SpendingBreakdown }) {
  return (
    <Card size="3">
      <Flex justify="between" align="baseline" mb="4" wrap="wrap" gap="2">
        <Heading size="4">{breakdown.currency} spending</Heading>
        <Text size="4" weight="bold">{breakdown.total_amount_label}</Text>
      </Flex>

      <Flex gap="6" align="center" wrap="wrap">
        <Box style={{ flex: "1 1 420px", minWidth: 0 }}>
          <Table.Root variant="ghost" size="2">
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeaderCell>Category</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell justify="end">Amount</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell justify="end" width="80px">Share</Table.ColumnHeaderCell>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {breakdown.categories.map((category, index) => (
                <Table.Row key={category.id ?? "uncategorized"}>
                  <Table.Cell>
                    <Flex align="center" gap="2">
                      <Box
                        aria-hidden="true"
                        style={{
                          width: "10px",
                          height: "10px",
                          borderRadius: "999px",
                          background: categoryColor(category, index),
                          flexShrink: 0,
                        }}
                      />
                      <Text weight="medium">{category.name}</Text>
                    </Flex>
                  </Table.Cell>
                  <Table.Cell justify="end">{category.amount_label}</Table.Cell>
                  <Table.Cell justify="end">
                    <Text color="gray">
                      {percentage(category.amount_cents, breakdown.total_amount_cents).toFixed(1)}%
                    </Text>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table.Body>
          </Table.Root>
        </Box>

        <Flex style={{ flex: "0 1 300px" }} justify="center" align="center">
          <Box
            role="img"
            aria-label={`Pie chart of ${breakdown.currency} spending by category`}
            style={{
              position: "relative",
              width: "220px",
              height: "220px",
              borderRadius: "50%",
              background: chartGradient(breakdown),
              boxShadow: "inset 0 0 0 1px var(--gray-a4)",
            }}
          >
            <Flex
              direction="column"
              justify="center"
              align="center"
              style={{
                position: "absolute",
                inset: "42px",
                borderRadius: "50%",
                background: "var(--color-background)",
                boxShadow: "0 0 0 1px var(--gray-a3)",
                textAlign: "center",
              }}
            >
              <Text size="1" color="gray">Total</Text>
              <Text size="4" weight="bold">{breakdown.total_amount_label}</Text>
            </Flex>
          </Box>
        </Flex>
      </Flex>
    </Card>
  )
}

export default function CategorySpendingBreakdown(props: Props) {
  const { breakdown } = PropsSchema.parse(props)

  return (
    <Box mb="7">
      {breakdown.unconverted_currencies.length > 0 && (
        <Text as="p" size="2" color="orange" mb="4">
          Some invoices were excluded because no EUR rate was available for {breakdown.unconverted_currencies.join(", ")}.
        </Text>
      )}

      {breakdown.categories.length === 0 ? (
        <Card>
          <Text color="gray">No invoice spending for this month yet.</Text>
        </Card>
      ) : (
        <BreakdownCard breakdown={breakdown} />
      )}
    </Box>
  )
}
