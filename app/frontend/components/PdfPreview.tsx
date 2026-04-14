import { useState, useEffect } from "react"
import { Box, Flex, Button, Text } from "@radix-ui/themes"
import { ChevronLeftIcon, ChevronRightIcon, Link2Icon, ReloadIcon } from "@radix-ui/react-icons"

interface PageData {
  page_number: number
  image_url: string
}

interface PdfPreviewProps {
  invoiceId: number
  onUnlink?: () => void
}

export default function PdfPreview({ invoiceId, onUnlink }: PdfPreviewProps) {
  const [pages, setPages] = useState<PageData[]>([])
  const [pageIndex, setPageIndex] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  const fetchPages = () => {
    setLoading(true)
    setError(false)
    fetch(`/invoices/${invoiceId}/pages`)
      .then(res => res.json())
      .then(data => {
        setPages(data.pages)
        setLoading(false)
      })
      .catch(() => {
        setError(true)
        setLoading(false)
      })
  }

  useEffect(fetchPages, [invoiceId])

  const hasPages = !loading && !error && pages.length > 0
  const currentPage = hasPages ? pages[pageIndex] : null

  return (
    <Box
      style={{
        border: "1px solid var(--gray-5)",
        borderRadius: "var(--radius-3)",
        overflow: "hidden",
      }}
    >
      {currentPage ? (
        <img
          src={currentPage.image_url}
          alt={`Page ${currentPage.page_number}`}
          style={{ width: "100%", display: "block" }}
        />
      ) : (
        <Flex
          align="center"
          justify="center"
          direction="column"
          gap="3"
          style={{
            aspectRatio: "1 / 1.4142",
            backgroundColor: "var(--gray-a2)",
          }}
        >
          {loading ? (
            <Text size="3" color="gray">Loading preview...</Text>
          ) : (
            <>
              <Text size="3" color="gray" weight="medium">
                Preview is being generated
              </Text>
              <Button size="2" variant="soft" color="gray" onClick={fetchPages}>
                <ReloadIcon /> Refresh
              </Button>
            </>
          )}
        </Flex>
      )}

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
          <Button
            size="1"
            variant="ghost"
            disabled={!hasPages || pageIndex <= 0}
            onClick={() => setPageIndex(i => i - 1)}
          >
            <ChevronLeftIcon />
          </Button>
          <Text size="2" color="gray">
            {hasPages ? `${pageIndex + 1} / ${pages.length}` : "— / —"}
          </Text>
          <Button
            size="1"
            variant="ghost"
            disabled={!hasPages || pageIndex >= pages.length - 1}
            onClick={() => setPageIndex(i => i + 1)}
          >
            <ChevronRightIcon />
          </Button>
        </Flex>

        {onUnlink && (
          <Button
            size="1"
            variant="ghost"
            color="red"
            onClick={onUnlink}
          >
            <Link2Icon /> Unlink invoice
          </Button>
        )}
      </Flex>
    </Box>
  )
}
