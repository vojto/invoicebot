import { router } from "@inertiajs/react"
import { Button } from "@radix-ui/themes"
import { ChangeEvent, useRef, useState } from "react"

type Props = {
  transactionId: number
}

export default function TransactionInvoiceUploadButton({ transactionId }: Props) {
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [isUploading, setIsUploading] = useState(false)

  const openFilePicker = () => {
    if (isUploading) return

    if (fileInputRef.current) {
      fileInputRef.current.value = ""
      fileInputRef.current.click()
    }
  }

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    setIsUploading(true)
    router.post(`/transactions/${transactionId}/upload_invoice`, { file }, {
      forceFormData: true,
      preserveScroll: true,
      onFinish: () => {
        setIsUploading(false)

        if (fileInputRef.current) {
          fileInputRef.current.value = ""
        }
      },
    })
  }

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept="application/pdf,.pdf"
        className="hidden"
        onChange={handleFileChange}
      />
      <Button
        size="1"
        variant="soft"
        color="gray"
        className="gap-1 select-none text-xs font-semibold text-gray-600"
        onClick={openFilePicker}
        disabled={isUploading}
      >
        {isUploading ? "Uploading..." : "Upload invoice"}
      </Button>
    </>
  )
}
