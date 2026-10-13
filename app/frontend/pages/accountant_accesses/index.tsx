import { Head, router } from "@inertiajs/react"
import { Badge, Box, Button, Flex, Heading, Table, Text, TextField } from "@radix-ui/themes"
import { FormEvent, useState } from "react"
import { z } from "zod"

const AccountantAccessSchema = z.object({
  id: z.number(),
  name: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  last_accessed_at: z.string().nullable(),
  public_url: z.string().nullable(),
})

const PropsSchema = z.object({
  accountant_accesses: z.array(AccountantAccessSchema),
})

type Props = z.infer<typeof PropsSchema>
type AccountantAccess = z.infer<typeof AccountantAccessSchema>

function formatDate(value: string | null) {
  if (!value) return "Never"
  return new Intl.DateTimeFormat("en-US", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value))
}

function AccessRow({ access }: { access: AccountantAccess }) {
  const copyLink = () => {
    if (access.public_url) void navigator.clipboard.writeText(access.public_url)
  }

  const revoke = () => {
    if (!window.confirm(`Revoke access for “${access.name}”? Their existing link will stop working.`)) return
    router.post(`/accountant_accesses/${access.id}/revoke`)
  }

  const rotate = () => {
    if (!window.confirm(`Regenerate the link for “${access.name}”? Their existing link will stop working.`)) return
    router.post(`/accountant_accesses/${access.id}/rotate`)
  }

  return (
    <Table.Row>
      <Table.Cell>
        <Text weight="medium">{access.name}</Text>
      </Table.Cell>
      <Table.Cell>
        <Badge color={access.active ? "green" : "gray"}>{access.active ? "Active" : "Revoked"}</Badge>
      </Table.Cell>
      <Table.Cell>{formatDate(access.last_accessed_at)}</Table.Cell>
      <Table.Cell>
        {access.public_url && (
          <Flex gap="2" wrap="wrap">
            <Button size="1" variant="soft" asChild>
              <a href={access.public_url} target="_blank" rel="noreferrer">Open</a>
            </Button>
            <Button size="1" variant="soft" color="gray" onClick={copyLink}>Copy link</Button>
            <Button size="1" variant="soft" color="gray" onClick={rotate}>Regenerate</Button>
            <Button size="1" variant="soft" color="red" onClick={revoke}>Revoke</Button>
          </Flex>
        )}
      </Table.Cell>
    </Table.Row>
  )
}

export default function AccountantAccessesIndex(props: Props) {
  const { accountant_accesses } = PropsSchema.parse(props)
  const [name, setName] = useState("")
  const [isCreating, setIsCreating] = useState(false)

  const createAccess = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsCreating(true)
    router.post(
      "/accountant_accesses",
      { accountant_access: { name } },
      {
        preserveScroll: true,
        onSuccess: () => setName(""),
        onFinish: () => setIsCreating(false),
      },
    )
  }

  return (
    <>
      <Head title="Accountants" />
      <Box>
        <Heading size="6" mb="2">Accountant access</Heading>
        <Text color="gray" as="p" mb="5">
          Create read-only links for accountants. Anyone with a link can view your invoices.
        </Text>

        <form onSubmit={createAccess}>
          <Flex gap="2" align="center" mb="6">
            <TextField.Root
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="Accountant name"
              aria-label="Accountant name"
              maxLength={100}
              style={{ width: "320px" }}
            />
            <Button type="submit" disabled={isCreating || name.trim() === ""}>
              Create access
            </Button>
          </Flex>
        </form>

        {accountant_accesses.length === 0 ? (
          <Text color="gray">No accountant access created yet.</Text>
        ) : (
          <Box className="overflow-x-auto">
            <Table.Root variant="surface">
              <Table.Header>
                <Table.Row>
                  <Table.ColumnHeaderCell>Name</Table.ColumnHeaderCell>
                  <Table.ColumnHeaderCell width="100px">Status</Table.ColumnHeaderCell>
                  <Table.ColumnHeaderCell width="190px">Last opened</Table.ColumnHeaderCell>
                  <Table.ColumnHeaderCell width="390px">Actions</Table.ColumnHeaderCell>
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {accountant_accesses.map((access) => <AccessRow key={access.id} access={access} />)}
              </Table.Body>
            </Table.Root>
          </Box>
        )}
      </Box>
    </>
  )
}
