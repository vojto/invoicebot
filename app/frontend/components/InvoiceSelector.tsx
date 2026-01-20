import { MagnifyingGlassIcon } from "@radix-ui/react-icons"
import { Box, Button, Flex, Text, Theme } from "@radix-ui/themes"
import * as Popover from "@radix-ui/react-popover"

export default function InvoiceSelector() {
  return (
    <Popover.Root>
      <Popover.Trigger asChild>
        <Button
          size="1"
          variant="soft"
          color="gray"
          className="gap-1 select-none text-xs font-semibold text-gray-600 data-[state=open]:bg-gray-200 data-[state=open]:text-gray-700"
        >
          <MagnifyingGlassIcon />
          <span className="text-inherit">Select invoice</span>
        </Button>
      </Popover.Trigger>
      <Popover.Portal>
        <Theme asChild>
          <Popover.Content
            align="end"
            sideOffset={6}
            className="z-50 rounded-md border border-gray-200 bg-white p-3 shadow-lg"
            style={{ width: 220 }}
          >
            <Box>
              <Text size="2" color="gray">
                Testing content.
              </Text>
              <Flex mt="3" justify="between">
                <Popover.Close asChild>
                  <Button size="1" variant="soft" color="gray">
                    Cancel
                  </Button>
                </Popover.Close>
                <Button size="1" variant="solid">
                  Confirm
                </Button>
              </Flex>
            </Box>
            <Popover.Arrow className="fill-white" />
          </Popover.Content>
        </Theme>
      </Popover.Portal>
    </Popover.Root>
  )
}
