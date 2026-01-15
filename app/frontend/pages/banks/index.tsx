import { Head, router } from "@inertiajs/react"
import { Heading, Box, Text, Card, Flex, Avatar } from "@radix-ui/themes"
import { z } from "zod"

const InstitutionSchema = z.object({
  id: z.string(),
  name: z.string(),
  logo: z.string().nullable(),
  countries: z.array(z.string()).nullable(),
})

const PropsSchema = z.object({
  institutions: z.array(InstitutionSchema),
})

type Props = z.infer<typeof PropsSchema>

export default function BanksIndex(props: Props) {
  const { institutions } = PropsSchema.parse(props)

  const handleConnect = (institution: z.infer<typeof InstitutionSchema>) => {
    router.post("/banks/connect", {
      institution_id: institution.id,
      institution_name: institution.name,
    })
  }

  return (
    <>
      <Head title="Connect Bank Account" />
      <Box>
        <Heading size="6" mb="4">Connect Bank Account</Heading>
        <Text color="gray" mb="4" as="p">
          Select your bank to connect your account.
        </Text>
        <Box
          mt="4"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(4, 1fr)",
            gap: "var(--space-3)",
          }}
        >
          {institutions.map((institution) => (
            <Card
              key={institution.id}
              className="cursor-pointer transition-colors hover:bg-gray-100"
              onClick={() => handleConnect(institution)}
            >
              <Flex direction="column" align="center" gap="2" py="2">
                {institution.logo && (
                  <Avatar
                    src={institution.logo}
                    fallback={institution.name.charAt(0)}
                    size="4"
                  />
                )}
                <Text weight="medium" size="2" align="center">
                  {institution.name}
                </Text>
              </Flex>
            </Card>
          ))}
        </Box>
      </Box>
    </>
  )
}
