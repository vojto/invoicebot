import { useState, useEffect, useRef, useCallback } from "react"
import { Text, Flex, Spinner } from "@radix-ui/themes"
import { MagnifyingGlassIcon } from "@radix-ui/react-icons"
import { createPortal } from "react-dom"

interface PageData {
  page_number: number
  image_url: string
}

interface InvoicePdfPopoverProps {
  invoiceId: number
}

export default function InvoicePdfPopover({ invoiceId }: InvoicePdfPopoverProps) {
  const [visible, setVisible] = useState(false)
  const [page, setPage] = useState<PageData | null>(null)
  const [loading, setLoading] = useState(false)
  const [fetched, setFetched] = useState(false)
  const [position, setPosition] = useState<{ top: number; left: number; width: number; height: number } | null>(null)
  const iconRef = useRef<HTMLButtonElement>(null)

  const fetchFirstPage = useCallback(() => {
    if (fetched) return
    setLoading(true)
    fetch(`/invoices/${invoiceId}/pages`)
      .then(res => res.json())
      .then(data => {
        if (data.pages && data.pages.length > 0) {
          setPage(data.pages[0])
        }
        setFetched(true)
        setLoading(false)
      })
      .catch(() => {
        setFetched(true)
        setLoading(false)
      })
  }, [invoiceId, fetched])

  const computePosition = useCallback(() => {
    if (!iconRef.current) return null

    const rect = iconRef.current.getBoundingClientRect()
    const vh = window.innerHeight
    const vw = window.innerWidth
    const popoverHeight = vh * 0.9
    const top = (vh - popoverHeight) / 2
    const iconCenterX = rect.left + rect.width / 2
    const gap = 12

    // A4 aspect ratio
    const popoverWidth = popoverHeight / 1.4142

    if (iconCenterX < vw / 2) {
      // Icon is on the left half — show popover to the right
      return { top, left: rect.right + gap, width: popoverWidth, height: popoverHeight }
    } else {
      // Icon is on the right half — show popover to the left
      return { top, left: rect.left - gap - popoverWidth, width: popoverWidth, height: popoverHeight }
    }
  }, [])

  const handleMouseEnter = () => {
    fetchFirstPage()
    setPosition(computePosition())
    setVisible(true)
  }

  const handleMouseLeave = () => {
    setVisible(false)
  }

  useEffect(() => {
    if (!visible) return
    const onScroll = () => setPosition(computePosition())
    window.addEventListener("scroll", onScroll, true)
    return () => window.removeEventListener("scroll", onScroll, true)
  }, [visible, computePosition])

  const popover = visible && position && createPortal(
    <div
      style={{
        position: "fixed",
        top: position.top,
        left: position.left,
        width: position.width,
        height: position.height,
        zIndex: 9999,
        borderRadius: 8,
        overflow: "hidden",
        backgroundColor: "white",
        border: "1px solid var(--gray-5)",
        pointerEvents: "none",
      }}
    >
      {loading ? (
        <Flex align="center" justify="center" style={{ width: "100%", height: "100%" }}>
          <Spinner size="3" />
        </Flex>
      ) : page ? (
        <img
          src={page.image_url}
          alt={`Invoice ${invoiceId} preview`}
          style={{ width: "100%", height: "100%", objectFit: "contain", backgroundColor: "var(--gray-a2)" }}
        />
      ) : (
        <Flex align="center" justify="center" style={{ width: "100%", height: "100%" }}>
          <Text size="2" color="gray">No preview</Text>
        </Flex>
      )}
    </div>,
    document.body
  )

  return (
    <>
      <button
        ref={iconRef}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        style={{
          background: "none",
          border: "none",
          cursor: "pointer",
          padding: 2,
          display: "inline-flex",
          alignItems: "center",
          color: "var(--gray-8)",
        }}
      >
        <MagnifyingGlassIcon width={14} height={14} />
      </button>
      {popover}
    </>
  )
}
