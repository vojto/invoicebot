import { MagnifyingGlassIcon } from "@radix-ui/react-icons"
import { router } from "@inertiajs/react"
import { Box, Button, Flex, Text, Theme } from "@radix-ui/themes"
import { useEffect, useState } from "react"
import * as Popover from "@radix-ui/react-popover"

type InvoiceMatch = {
  id: number
  vendor_name: string | null
  amount_label: string
  date_label: string
  date_offset_days: number | null
}

type Props = {
  transactionId: number
}

function formatOffset(offset: number | null): string {
  if (offset === null || Number.isNaN(offset)) return "—"
  if (offset === 0) return "0"
  const sign = offset > 0 ? "+" : ""
  return `${sign}${offset}`
}

function offsetTone(offset: number | null): "green" | "red" | "gray" {
  if (offset === null || Number.isNaN(offset)) return "gray"
  return Math.abs(offset) <= 14 ? "green" : "red"
}

export default function InvoiceSelector({ transactionId }: Props) {
  const [open, setOpen] = useState(false)
  const [matches, setMatches] = useState<InvoiceMatch[] | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    if (!open || matches !== null || isLoading) return

    const loadMatches = async () => {
      setIsLoading(true)
      try {
        const response = await fetch(`/transactions/${transactionId}/invoice_matches`)
        const data = await response.json()
        setMatches(data.matches || [])
      } catch {
        setMatches([])
      } finally {
        setIsLoading(false)
      }
    }

    loadMatches()
  }, [open, matches, isLoading, transactionId])

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger asChild>
        <Button
          size="1"
          variant="soft"
          color="gray"
          className="gap-1 select-none text-xs font-semibold text-gray-600 data-[state=open]:bg-gray-200 data-[state=open]:text-gray-700"
        >
          <MagnifyingGlassIcon />
          <span className="text-inherit">Select invoice</span>
        </Button>
      </Popover.Trigger>
      <Popover.Portal>
        <Theme asChild>
          <Popover.Content
            side="bottom"
            align="end"
            sideOffset={6}
            className="z-50 rounded-md border border-gray-200 bg-white p-3 shadow-lg"
            style={{ width: 300 }}
          >
            <Box>
              <Text size="2" weight="medium">
                Matching invoices
              </Text>
              <Box mt="2">
                {isLoading ? (
                  <Flex align="center" justify="center" py="3">
                    <span className="h-4 w-4 animate-spin rounded-full border-2 border-gray-200 border-t-gray-500" />
                  </Flex>
                ) : matches && matches.length > 0 ? (
                  <Flex direction="column" gap="2">
                    {matches.map((invoice) => (
                      <Button
                        key={invoice.id}
                        variant="ghost"
                        className="h-auto w-full justify-start px-2 py-2 text-left"
                        onClick={() => {
                          router.post(
                            `/transactions/${transactionId}/link_invoice`,
                            { invoice_id: invoice.id },
                            { preserveScroll: true }
                          )
                          setOpen(false)
                        }}
                      >
                        <Flex direction="column" gap="1" align="start" className="w-full">
                          <Text size="2" weight="medium">
                            {invoice.vendor_name || "Unknown vendor"}
                          </Text>
                          <Flex align="center" justify="between" className="w-full">
                            <Flex align="center" gap="2">
                              <Text size="2" color="gray">
                                {invoice.amount_label}
                              </Text>
                              <Text size="2" color="gray">
                                {invoice.date_label}
                              </Text>
                            </Flex>
                            <Text size="2" weight="medium" color={offsetTone(invoice.date_offset_days)}>
                              {formatOffset(invoice.date_offset_days)}d
                            </Text>
                          </Flex>
                        </Flex>
                      </Button>
                    ))}
                  </Flex>
                ) : (
                  <Text size="1" color="gray">
                    No matching invoices found.
                  </Text>
                )}
              </Box>
            </Box>
            <Popover.Arrow className="fill-white" />
          </Popover.Content>
        </Theme>
      </Popover.Portal>
    </Popover.Root>
  )
}
