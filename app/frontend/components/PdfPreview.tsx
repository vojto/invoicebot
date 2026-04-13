import { useState } from "react"
import { Document, Page, pdfjs } from "react-pdf"
import { Box, Flex, Button, Text } from "@radix-ui/themes"
import { ChevronLeftIcon, ChevronRightIcon } from "@radix-ui/react-icons"

import "react-pdf/dist/Page/AnnotationLayer.css"
import "react-pdf/dist/Page/TextLayer.css"

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  "pdfjs-dist/build/pdf.worker.min.mjs",
  import.meta.url,
).toString()

interface PdfPreviewProps {
  url: string
}

export default function PdfPreview({ url }: PdfPreviewProps) {
  const [numPages, setNumPages] = useState<number>(0)
  const [pageNumber, setPageNumber] = useState(1)
  const [error, setError] = useState(false)

  if (error) {
    return (
      <Box p="4">
        <Text color="gray">Could not load PDF preview.</Text>
      </Box>
    )
  }

  return (
    <Box>
      <Document
        file={url}
        onLoadSuccess={({ numPages }) => setNumPages(numPages)}
        onLoadError={() => setError(true)}
        loading={<Text color="gray" size="2">Loading PDF...</Text>}
      >
        <Page
          pageNumber={pageNumber}
          width={500}
          renderAnnotationLayer={false}
        />
      </Document>

      {numPages > 1 && (
        <Flex align="center" justify="center" gap="3" mt="3">
          <Button
            size="1"
            variant="soft"
            disabled={pageNumber <= 1}
            onClick={() => setPageNumber(p => p - 1)}
          >
            <ChevronLeftIcon />
          </Button>
          <Text size="2" color="gray">
            {pageNumber} / {numPages}
          </Text>
          <Button
            size="1"
            variant="soft"
            disabled={pageNumber >= numPages}
            onClick={() => setPageNumber(p => p + 1)}
          >
            <ChevronRightIcon />
          </Button>
        </Flex>
      )}
    </Box>
  )
}
