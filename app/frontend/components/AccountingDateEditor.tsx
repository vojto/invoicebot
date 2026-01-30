import { Pencil2Icon } from "@radix-ui/react-icons"
import { router } from "@inertiajs/react"
import { Button, Flex, Text, TextField, Theme } from "@radix-ui/themes"
import { useEffect, useState } from "react"
import * as Popover from "@radix-ui/react-popover"

type Props = {
  invoiceId: number
  accountingDate: string | null | undefined
}

function formatDateForInput(dateString: string | null | undefined): string {
  if (!dateString) return ""
  const date = new Date(dateString)
  return date.toISOString().split("T")[0] // YYYY-MM-DD format
}

export default function AccountingDateEditor({ invoiceId, accountingDate }: Props) {
  const [open, setOpen] = useState(false)
  const [value, setValue] = useState(formatDateForInput(accountingDate))

  useEffect(() => {
    if (open) {
      setValue(formatDateForInput(accountingDate))
    }
  }, [open, accountingDate])

  const submit = () => {
    router.post(
      `/invoices/${invoiceId}/update_accounting_date`,
      { accounting_date: value },
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
            style={{ width: 220 }}
          >
            <Flex direction="column" gap="2">
              <Text size="2" weight="medium">
                Edit accounting date
              </Text>
              <TextField.Root
                type="date"
                value={value}
                onChange={(event) => setValue(event.target.value)}
                placeholder="YYYY-MM-DD"
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
