import { Callout, Flex } from "@radix-ui/themes"
import { UpdateIcon, CrossCircledIcon, CheckCircledIcon } from "@radix-ui/react-icons"
import { z } from "zod"

export const BankSyncStatusSchema = z.object({
  id: z.number(),
  bank_name: z.string(),
  sync_running: z.boolean(),
  sync_completed_at: z.string(),
  sync_error: z.string().nullable(),
})

export type BankSyncStatus = z.infer<typeof BankSyncStatusSchema>

export default function BankSyncStatusList({ bankSyncStatuses }: { bankSyncStatuses: BankSyncStatus[] }) {
  if (bankSyncStatuses.length === 0) return null

  return (
    <Flex direction="column" gap="2" mb="4">
      {bankSyncStatuses.map((status) => {
        if (status.sync_running) {
          return (
            <Callout.Root key={status.id} color="blue">
              <Callout.Icon>
                <UpdateIcon style={{ animation: "spin 1s linear infinite" }} />
              </Callout.Icon>
              <Callout.Text>Syncing transactions for {status.bank_name}...</Callout.Text>
            </Callout.Root>
          )
        }

        if (status.sync_error) {
          return (
            <Callout.Root key={status.id} color="red">
              <Callout.Icon>
                <CrossCircledIcon />
              </Callout.Icon>
              <Callout.Text>
                Last transaction sync failed for {status.bank_name}: {status.sync_error}
              </Callout.Text>
            </Callout.Root>
          )
        }

        return (
          <Callout.Root key={status.id} color="gray">
            <Callout.Icon>
              <CheckCircledIcon />
            </Callout.Icon>
            <Callout.Text>
              Last transaction sync for {status.bank_name}: {status.sync_completed_at}
            </Callout.Text>
          </Callout.Root>
        )
      })}
    </Flex>
  )
}
