import { Pencil2Icon } from "@radix-ui/react-icons"
import { router } from "@inertiajs/react"
import { Button, Flex, Text, TextField, Theme } from "@radix-ui/themes"
import { useEffect, useState } from "react"
import * as Popover from "@radix-ui/react-popover"

type Props = {
  transactionId: number
  vendorName: string | null
}

export default function VendorEditor({ transactionId, vendorName }: Props) {
  const [open, setOpen] = useState(false)
  const [value, setValue] = useState(vendorName || "")

  useEffect(() => {
    if (open) {
      setValue(vendorName || "")
    }
  }, [open, vendorName])

  const submit = () => {
    router.post(
      `/transactions/${transactionId}/update_vendor`,
      { vendor_name: value },
      { preserveScroll: true }
    )
    setOpen(false)
  }

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger asChild>
        <Button size="1" variant="ghost" color="gray">
          <Pencil2Icon />
        </Button>
      </Popover.Trigger>
      <Popover.Portal>
        <Theme asChild>
          <Popover.Content
            side="bottom"
            align="start"
            sideOffset={6}
            className="z-50 rounded-md border border-gray-200 bg-white p-3 shadow-lg"
            style={{ width: 260 }}
          >
            <Flex direction="column" gap="2">
              <Text size="2" weight="medium">
                Edit vendor
              </Text>
              <TextField.Root
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder="Vendor name"
              />
              <Flex justify="end" gap="2" mt="2">
                <Popover.Close asChild>
                  <Button size="1" variant="soft" color="gray">
                    Cancel
                  </Button>
                </Popover.Close>
                <Button size="1" variant="solid" onClick={submit}>
                  Save
                </Button>
              </Flex>
            </Flex>
            <Popover.Arrow className="fill-white" />
          </Popover.Content>
        </Theme>
      </Popover.Portal>
    </Popover.Root>
  )
}
