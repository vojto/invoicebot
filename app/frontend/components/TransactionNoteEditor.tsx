import { router } from "@inertiajs/react"
import { Pencil2Icon } from "@radix-ui/react-icons"
import * as Popover from "@radix-ui/react-popover"
import { Button, Flex, Text, TextArea, Theme } from "@radix-ui/themes"
import { useEffect, useState } from "react"

type Props = {
  transactionId: number
  customNote: string | null
  vendorName: string | null
  textClassName?: string
}

function displayValue(customNote: string | null, vendorName: string | null): string {
  return customNote === null ? (vendorName ?? "") : customNote
}

export default function TransactionNoteEditor({ transactionId, customNote, vendorName, textClassName }: Props) {
  const [open, setOpen] = useState(false)
  const [value, setValue] = useState(displayValue(customNote, vendorName))

  useEffect(() => {
    if (open) {
      setValue(displayValue(customNote, vendorName))
    }
  }, [open, customNote, vendorName])

  const save = () => {
    router.post(
      `/transactions/${transactionId}/update_custom_note`,
      { custom_note: value },
      { preserveScroll: true }
    )
    setOpen(false)
  }

  const resetToVendor = () => {
    setValue(vendorName ?? "")
  }

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Flex align="center" gap="1">
        <Text size="2" className={`min-h-5 whitespace-pre-wrap ${textClassName ?? ""}`.trim()}>
          {displayValue(customNote, vendorName) || "\u00A0"}
        </Text>
        <Popover.Trigger asChild>
          <Button size="1" variant="ghost" color="gray">
            <Pencil2Icon />
          </Button>
        </Popover.Trigger>
      </Flex>
      <Popover.Portal>
        <Theme asChild>
          <Popover.Content
            side="bottom"
            align="start"
            sideOffset={6}
            className="z-50 rounded-md border border-gray-200 bg-white p-3 shadow-lg"
            style={{ width: 320 }}
          >
            <Flex direction="column" gap="2">
              <Text size="2" weight="medium">
                Edit note
              </Text>
              <TextArea
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder="Add a custom note"
                rows={4}
                autoFocus
              />
              <Flex justify="between" gap="2" mt="2">
                <Button size="1" variant="soft" color="gray" onClick={resetToVendor}>
                  Reset
                </Button>
                <Flex gap="2">
                  <Popover.Close asChild>
                    <Button size="1" variant="soft" color="gray">
                      Cancel
                    </Button>
                  </Popover.Close>
                  <Button size="1" variant="solid" onClick={save}>
                    Save
                  </Button>
                </Flex>
              </Flex>
            </Flex>
            <Popover.Arrow className="fill-white" />
          </Popover.Content>
        </Theme>
      </Popover.Portal>
    </Popover.Root>
  )
}
