import { useState, useEffect, useCallback, ReactNode } from "react"
import { router } from "@inertiajs/react"
import { Box, Text } from "@radix-ui/themes"

interface PdfDropZoneProps {
  enabled: boolean
  children: ReactNode
}

export default function PdfDropZone({ enabled, children }: PdfDropZoneProps) {
  const [isDragging, setIsDragging] = useState(false)

  const handleDrop = useCallback((e: DragEvent) => {
    e.preventDefault()
    setIsDragging(false)

    if (!enabled) return

    const files = e.dataTransfer?.files
    if (!files || files.length === 0) return

    const file = files[0]
    if (file.type !== "application/pdf") return

    router.post("/invoices/upload", { file }, {
      forceFormData: true,
    })
  }, [enabled])

  const handleDragOver = useCallback((e: DragEvent) => {
    e.preventDefault()
    if (enabled) {
      setIsDragging(true)
    }
  }, [enabled])

  const handleDragLeave = useCallback((e: DragEvent) => {
    e.preventDefault()
    // Only set dragging to false if we're leaving the window
    if (e.relatedTarget === null) {
      setIsDragging(false)
    }
  }, [])

  useEffect(() => {
    window.addEventListener("drop", handleDrop)
    window.addEventListener("dragover", handleDragOver)
    window.addEventListener("dragleave", handleDragLeave)

    return () => {
      window.removeEventListener("drop", handleDrop)
      window.removeEventListener("dragover", handleDragOver)
      window.removeEventListener("dragleave", handleDragLeave)
    }
  }, [handleDrop, handleDragOver, handleDragLeave])

  return (
    <>
      {isDragging && (
        <Box
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "var(--accent-a4)",
            border: "4px dashed var(--accent-9)",
            zIndex: 9999,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            pointerEvents: "none",
          }}
        >
          <Text size="6" weight="bold" style={{ color: "var(--accent-11)" }}>
            Drop PDF to upload invoice
          </Text>
        </Box>
      )}
      {children}
    </>
  )
}
