import { MagnifyingGlassIcon } from "@radix-ui/react-icons"
import { router } from "@inertiajs/react"
import { Box, Button, Flex, Text, TextField, Theme } from "@radix-ui/themes"
import { useCallback, useEffect, useRef, useState } from "react"
import * as Popover from "@radix-ui/react-popover"

type InvoiceMatch = {
  id: number
  vendor_name: string | null
  amount_label: string
  date_label: string
  date_offset_days: number | null
  amount_diff_label: string | null
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

function InvoiceMatchRow({ invoice, transactionId, onSelect }: { invoice: InvoiceMatch; transactionId: number; onSelect: () => void }) {
  return (
    <Button
      variant="ghost"
      className="h-auto w-full justify-start px-2 py-2 text-left"
      onClick={() => {
        router.post(`/transactions/${transactionId}/link_invoice`, {
          invoice_id: invoice.id,
        }, { preserveScroll: true })
        onSelect()
      }}
    >
      <Flex direction="column" gap="1" align="start" className="w-full">
        <Text size="2" weight="medium">
          {invoice.vendor_name || "Unknown vendor"}
        </Text>
        <Flex align="center" justify="between" className="w-full">
          <Text size="2" color="gray">
            {invoice.amount_label}
          </Text>
          <Text size="2" weight="medium" color={offsetTone(invoice.date_offset_days)}>
            {formatOffset(invoice.date_offset_days)}d
          </Text>
        </Flex>
      </Flex>
    </Button>
  )
}

export default function InvoiceSelector({ transactionId }: Props) {
  const [open, setOpen] = useState(false)
  const [exactMatches, setExactMatches] = useState<InvoiceMatch[] | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const [searchResults, setSearchResults] = useState<InvoiceMatch[]>([])
  const [isSearching, setIsSearching] = useState(false)
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (!open || exactMatches !== null || isLoading) return

    const loadMatches = async () => {
      setIsLoading(true)
      try {
        const response = await fetch(`/transactions/${transactionId}/invoice_matches`)
        const json = await response.json()
        setExactMatches(json.matches || [])
      } catch {
        setExactMatches([])
      } finally {
        setIsLoading(false)
      }
    }

    loadMatches()
  }, [open, exactMatches, isLoading, transactionId])

  const doSearch = useCallback(async (query: string) => {
    if (query.trim().length === 0) {
      setSearchResults([])
      setIsSearching(false)
      return
    }

    setIsSearching(true)
    try {
      const response = await fetch(`/transactions/${transactionId}/search_invoices?q=${encodeURIComponent(query)}`)
      const json = await response.json()
      setSearchResults(json.matches || [])
    } catch {
      setSearchResults([])
    } finally {
      setIsSearching(false)
    }
  }, [transactionId])

  const handleSearchChange = (value: string) => {
    setSearchQuery(value)
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current)
    searchTimerRef.current = setTimeout(() => doSearch(value), 300)
  }

  // Reset state when closed
  useEffect(() => {
    if (!open) {
      setExactMatches(null)
      setSearchQuery("")
      setSearchResults([])
    }
  }, [open])

  const hasExactMatches = exactMatches !== null && exactMatches.length > 0
  const showSearch = exactMatches !== null && exactMatches.length === 0

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
            style={{ width: 320 }}
          >
            <Box>
              {isLoading ? (
                <Flex align="center" justify="center" py="3">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-gray-200 border-t-gray-500" />
                </Flex>
              ) : hasExactMatches ? (
                <>
                  <Text size="2" weight="medium">Matching invoices</Text>
                  <Flex direction="column" gap="2" mt="2">
                    {exactMatches!.map((invoice) => (
                      <InvoiceMatchRow key={invoice.id} invoice={invoice} transactionId={transactionId} onSelect={() => setOpen(false)} />
                    ))}
                  </Flex>
                </>
              ) : showSearch ? (
                <>
                  <TextField.Root
                    size="2"
                    placeholder="Search invoices by vendor..."
                    value={searchQuery}
                    onChange={(e) => handleSearchChange(e.target.value)}
                    autoFocus
                  >
                    <TextField.Slot>
                      <MagnifyingGlassIcon />
                    </TextField.Slot>
                  </TextField.Root>
                  <Box mt="2">
                    {isSearching ? (
                      <Flex align="center" justify="center" py="3">
                        <span className="h-4 w-4 animate-spin rounded-full border-2 border-gray-200 border-t-gray-500" />
                      </Flex>
                    ) : searchQuery.trim().length > 0 && searchResults.length === 0 ? (
                      <Text size="1" color="gray">No invoices found.</Text>
                    ) : searchResults.length > 0 ? (
                      <Flex direction="column" gap="2">
                        {searchResults.map((invoice) => (
                          <InvoiceMatchRow key={invoice.id} invoice={invoice} transactionId={transactionId} onSelect={() => setOpen(false)} />
                        ))}
                      </Flex>
                    ) : (
                      <Text size="1" color="gray">Type to search invoices.</Text>
                    )}
                  </Box>
                </>
              ) : null}
            </Box>
            <Popover.Arrow className="fill-white" />
          </Popover.Content>
        </Theme>
      </Popover.Portal>
    </Popover.Root>
  )
}
