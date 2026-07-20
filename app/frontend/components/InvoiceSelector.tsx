import { ExternalLinkIcon, MagnifyingGlassIcon } from "@radix-ui/react-icons"
import { router } from "@inertiajs/react"
import { Badge, Box, Button, Flex, Text, TextField, Theme } from "@radix-ui/themes"
import { useCallback, useEffect, useRef, useState } from "react"
import * as Popover from "@radix-ui/react-popover"
import { z } from "zod"

const InvoiceMatchSchema = z.object({
  id: z.number(),
  vendor_name: z.string().nullable(),
  document_type: z.enum(["invoice", "credit_note"]),
  amount_label: z.string(),
  date_label: z.string(),
  date_offset_days: z.number().nullable(),
  amount_diff_label: z.string().nullable(),
})

const MatchesResponseSchema = z.object({ matches: z.array(InvoiceMatchSchema) })
const PropsSchema = z.object({ transactionId: z.number() })

type InvoiceMatch = z.infer<typeof InvoiceMatchSchema>
type Props = z.infer<typeof PropsSchema>

function formatOffset(offset: number | null): string {
  if (offset === null || Number.isNaN(offset)) return "—"
  if (offset === 0) return "Same day"
  const days = Math.abs(offset)
  return `${days} ${days === 1 ? "day" : "days"} ${offset < 0 ? "before" : "after"}`
}

function offsetTone(offset: number | null): "green" | "red" | "gray" {
  if (offset === null || Number.isNaN(offset)) return "gray"
  return Math.abs(offset) <= 14 ? "green" : "red"
}

function InvoiceMatchRow({ invoice, transactionId, onSelect }: { invoice: InvoiceMatch; transactionId: number; onSelect: () => void }) {
  const isCreditNote = invoice.document_type === "credit_note"

  return (
    <Flex
      align="start"
      gap="2"
      className="rounded-md border border-transparent px-1 py-1 hover:border-gray-200 hover:bg-gray-50"
    >
      <button
        type="button"
        className="min-w-0 flex-1 rounded-md px-2 py-2 text-left"
        onClick={() => {
          router.post(`/transactions/${transactionId}/link_invoice`, {
            invoice_id: invoice.id,
          }, { preserveScroll: true })
          onSelect()
        }}
      >
        <Flex direction="column" gap="1" align="start" className="w-full min-w-0">
          <Flex align="center" gap="2" className="w-full min-w-0">
            <Text size="2" weight="medium" className="min-w-0 flex-1 truncate text-left">
              {invoice.vendor_name || "Unknown vendor"}
            </Text>
            <Badge size="1" variant="soft" color={isCreditNote ? "green" : "gray"} className="shrink-0">
              {isCreditNote ? "Credit note" : "Invoice"}
            </Badge>
          </Flex>
          <Flex align="center" justify="between" className="w-full">
            <Flex align="center" gap="1">
              <Text size="2" weight="medium" color={isCreditNote ? "green" : "red"}>
                {isCreditNote ? "+" : "−"}{invoice.amount_label}
              </Text>
              <Text size="1" color="gray">· {invoice.date_label}</Text>
            </Flex>
            <Text size="2" weight="medium" color={offsetTone(invoice.date_offset_days)}>
              {formatOffset(invoice.date_offset_days)}
            </Text>
          </Flex>
        </Flex>
      </button>

      <Button size="1" variant="ghost" color="gray" asChild>
        <a
          href={`/invoices/${invoice.id}`}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={`Open ${invoice.vendor_name || "invoice"} in a new tab`}
          title="Open invoice in a new tab"
        >
          <ExternalLinkIcon />
        </a>
      </Button>
    </Flex>
  )
}

export default function InvoiceSelector(props: Props) {
  const { transactionId } = PropsSchema.parse(props)
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
        const json = MatchesResponseSchema.parse(await response.json())
        setExactMatches(json.matches)
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
      const json = MatchesResponseSchema.parse(await response.json())
      setSearchResults(json.matches)
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
          <span className="text-inherit">Select document</span>
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
                  <Text size="2" weight="medium">Matching documents</Text>
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
                    placeholder="Search documents by vendor..."
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
                      <Text size="1" color="gray">No documents found.</Text>
                    ) : searchResults.length > 0 ? (
                      <Flex direction="column" gap="2">
                        {searchResults.map((invoice) => (
                          <InvoiceMatchRow key={invoice.id} invoice={invoice} transactionId={transactionId} onSelect={() => setOpen(false)} />
                        ))}
                      </Flex>
                    ) : (
                      <Text size="1" color="gray">Type to search documents.</Text>
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
