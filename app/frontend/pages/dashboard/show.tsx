import { Head, router } from "@inertiajs/react"
import { Heading, Box, Text, Table, Flex, Button, Callout } from "@radix-ui/themes"
import { DownloadIcon, UpdateIcon, CheckCircledIcon, CrossCircledIcon } from "@radix-ui/react-icons"
import { z } from "zod"
import InvoiceRow, { InvoiceSchema, type Invoice } from "~/components/InvoiceRow"

const PropsSchema = z.object({
  invoices: z.array(InvoiceSchema),
  sync_running: z.boolean(),
  sync_completed_at: z.string(),
  sync_error: z.string().nullable(),
})

type Props = z.infer<typeof PropsSchema>

function getMonthKey(dateString: string | null | undefined): string {
  if (!dateString) return "unknown"
  const date = new Date(dateString)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
}

function formatMonthHeading(monthKey: string): string {
  if (monthKey === "unknown") return "Unknown Date"
  const [year, month] = monthKey.split("-")
  const date = new Date(parseInt(year), parseInt(month) - 1, 1)
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
  }).format(date)
}

function groupInvoicesByMonth(invoices: Invoice[]): Map<string, Invoice[]> {
  const groups = new Map<string, Invoice[]>()

  for (const invoice of invoices) {
    const key = getMonthKey(invoice.accounting_date)
    const existing = groups.get(key) || []
    existing.push(invoice)
    groups.set(key, existing)
  }

  // Sort invoices within each group (newest first)
  for (const [key, groupInvoices] of groups) {
    groupInvoices.sort((a, b) => {
      if (!a.accounting_date) return 1
      if (!b.accounting_date) return -1
      return new Date(b.accounting_date).getTime() - new Date(a.accounting_date).getTime()
    })
    groups.set(key, groupInvoices)
  }

  // Sort groups by month key (newest first)
  const sortedEntries = [...groups.entries()].sort((a, b) => {
    if (a[0] === "unknown") return 1
    if (b[0] === "unknown") return -1
    return b[0].localeCompare(a[0])
  })

  return new Map(sortedEntries)
}

function SyncStatus({ running, completedAt, error }: { running: boolean; completedAt: string; error: string | null }) {
  const handleSync = () => router.post("/dashboard/sync")

  if (running) {
    return (
      <Callout.Root color="blue" mb="4">
        <Callout.Icon>
          <UpdateIcon style={{ animation: "spin 1s linear infinite" }} />
        </Callout.Icon>
        <Callout.Text>Syncing emails and processing invoices...</Callout.Text>
      </Callout.Root>
    )
  }

  if (error) {
    return (
      <Callout.Root color="red" mb="4" style={{ display: "flex", alignItems: "center" }}>
        <Callout.Icon>
          <CrossCircledIcon />
        </Callout.Icon>
        <Flex justify="between" align="center" style={{ flex: 1 }}>
          <Callout.Text>Sync failed: {error}</Callout.Text>
          <Button
            size="1"
            variant="solid"
            onClick={handleSync}
            style={{ backgroundColor: "white", color: "var(--red-11)" }}
          >
            Retry
          </Button>
        </Flex>
      </Callout.Root>
    )
  }

  return (
    <Callout.Root color="gray" mb="4" style={{ display: "flex", alignItems: "center" }}>
      <Callout.Icon>
        <CheckCircledIcon />
      </Callout.Icon>
      <Flex justify="between" align="center" style={{ flex: 1 }}>
        <Callout.Text>Last synced: {completedAt}</Callout.Text>
        <Button size="1" variant="soft" onClick={handleSync}>
          Sync Now
        </Button>
      </Flex>
    </Callout.Root>
  )
}

export default function DashboardShow(props: Props) {
  const { invoices, sync_running, sync_completed_at, sync_error } = PropsSchema.parse(props)
  const groupedInvoices = groupInvoicesByMonth(invoices)

  return (
    <>
      <Head title="Dashboard" />
      <SyncStatus running={sync_running} completedAt={sync_completed_at} error={sync_error} />
      <Box>
        {invoices.length === 0 ? (
          <Text color="gray">
            No invoices found. Invoices will appear here once emails are
            processed.
          </Text>
        ) : (
          <Flex direction="column" gap="6">
            {[...groupedInvoices.entries()].map(([monthKey, monthInvoices]) => {
              const hasDownloadableInvoices = monthKey !== "unknown" && monthInvoices.some((inv) => !inv.deleted_at)
              return (
              <Box key={monthKey}>
                <Flex justify="between" align="center" mb="4">
                  <Heading size="5" as="h2">
                    {formatMonthHeading(monthKey)}
                  </Heading>
                  {hasDownloadableInvoices && (
                    <Button
                      variant="soft"
                      size="2"
                      asChild
                    >
                      <a href={`/invoices/download?month=${monthKey}`} download>
                        <DownloadIcon />
                        Download ZIP
                      </a>
                    </Button>
                  )}
                </Flex>
                <Table.Root variant="surface" size="2">
                  <Table.Header>
                    <Table.Row>
                      <Table.ColumnHeaderCell width="400px">Vendor</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="120px">Amount</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Accounting Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="200px">Email Date</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell>Email Subject</Table.ColumnHeaderCell>
                      <Table.ColumnHeaderCell width="140px">Actions</Table.ColumnHeaderCell>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {monthInvoices.map((invoice) => (
                      <InvoiceRow key={invoice.id} invoice={invoice} />
                    ))}
                  </Table.Body>
                </Table.Root>
              </Box>
            )})}
          </Flex>
        )}
      </Box>
    </>
  )
}
