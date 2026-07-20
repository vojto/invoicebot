import { Link2Icon, ReloadIcon } from "@radix-ui/react-icons"
import { Box, Button, Flex, Spinner, Text } from "@radix-ui/themes"
import { useCallback, useEffect, useState } from "react"

interface PageData {
  page_number: number
  image_url: string
}

interface PdfPreviewProps {
  invoiceId: number
  pagesUrl?: string
  className?: string
  onUnlink?: () => void
}

export default function PdfPreview({ invoiceId, pagesUrl, className, onUnlink }: PdfPreviewProps) {
  const [pages, setPages] = useState<PageData[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  const fetchPages = useCallback(() => {
    setLoading(true)
    setError(false)

    fetch(pagesUrl || `/invoices/${invoiceId}/pages`)
      .then((response) => {
        if (!response.ok) throw new Error("Unable to load PDF preview")
        return response.json()
      })
      .then((data) => {
        setPages(data.pages || [])
        setLoading(false)
      })
      .catch(() => {
        setPages([])
        setError(true)
        setLoading(false)
      })
  }, [invoiceId, pagesUrl])

  useEffect(fetchPages, [fetchPages])

  return (
    <Box
      className={className}
      style={{
        border: "1px solid var(--gray-5)",
        borderRadius: "var(--radius-3)",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
      }}
    >
      <div className="min-h-0 flex-1 overflow-y-auto bg-[var(--gray-a3)] p-3">
        {loading ? (
          <Flex minHeight="320px" align="center" justify="center" direction="column" gap="3">
            <Spinner size="3" />
            <Text size="3" color="gray">Loading preview…</Text>
          </Flex>
        ) : pages.length > 0 ? (
          <Flex direction="column" gap="3" align="center">
            {pages.map((page, index) => (
              <figure key={page.page_number} className="m-0 w-full max-w-[920px]">
                <img
                  src={page.image_url}
                  alt={`Page ${page.page_number}`}
                  loading={index === 0 ? "eager" : "lazy"}
                  className="block h-auto w-full bg-white shadow-sm"
                />
                <figcaption className="mt-1 text-center text-xs text-[var(--gray-10)]">
                  Page {page.page_number}
                </figcaption>
              </figure>
            ))}
          </Flex>
        ) : (
          <Flex
            align="center"
            justify="center"
            direction="column"
            gap="3"
            minHeight="320px"
            style={{ backgroundColor: "var(--gray-a2)" }}
          >
            <Text size="3" color="gray" weight="medium">
              {error ? "Preview could not be loaded" : "Preview is being generated"}
            </Text>
            <Button size="2" variant="soft" color="gray" onClick={fetchPages}>
              <ReloadIcon /> Refresh
            </Button>
          </Flex>
        )}
      </div>

      <Flex
        align="center"
        justify="between"
        py="2"
        px="3"
        style={{
          backgroundColor: "var(--gray-a2)",
          borderTop: "1px solid var(--gray-5)",
        }}
      >
        <Flex align="center" gap="2">
          <Text size="2" color="gray">
            {pages.length === 1 ? "1 page" : `${pages.length} pages`}
          </Text>
          <Button size="1" variant="ghost" color="gray" onClick={fetchPages} aria-label="Refresh preview">
            <ReloadIcon />
          </Button>
        </Flex>

        {onUnlink && (
          <Button size="1" variant="ghost" color="red" onClick={onUnlink}>
            <Link2Icon /> Unlink invoice
          </Button>
        )}
      </Flex>
    </Box>
  )
}
