import { useState, useEffect } from "react"
import { Box, Flex, Button, Text } from "@radix-ui/themes"
import { ChevronLeftIcon, ChevronRightIcon } from "@radix-ui/react-icons"

interface PageData {
  page_number: number
  image_url: string
}

interface PdfPreviewProps {
  invoiceId: number
}

export default function PdfPreview({ invoiceId }: PdfPreviewProps) {
  const [pages, setPages] = useState<PageData[]>([])
  const [pageIndex, setPageIndex] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  useEffect(() => {
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
  }, [invoiceId])

  if (loading) {
    return <Text color="gray" size="2">Loading preview...</Text>
  }

  if (error || pages.length === 0) {
    return <Text color="gray" size="2">No preview available.</Text>
  }

  const currentPage = pages[pageIndex]

  return (
    <Box>
      <img
        src={currentPage.image_url}
        alt={`Page ${currentPage.page_number}`}
        style={{ width: "100%", border: "1px solid var(--gray-5)", borderRadius: 8 }}
      />

      {pages.length > 1 && (
        <Flex align="center" justify="center" gap="3" mt="3">
          <Button
            size="1"
            variant="soft"
            disabled={pageIndex <= 0}
            onClick={() => setPageIndex(i => i - 1)}
          >
            <ChevronLeftIcon />
          </Button>
          <Text size="2" color="gray">
            {pageIndex + 1} / {pages.length}
          </Text>
          <Button
            size="1"
            variant="soft"
            disabled={pageIndex >= pages.length - 1}
            onClick={() => setPageIndex(i => i + 1)}
          >
            <ChevronRightIcon />
          </Button>
        </Flex>
      )}
    </Box>
  )
}
