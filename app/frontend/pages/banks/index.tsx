import { Head } from "@inertiajs/react"
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

  return (
    <>
      <Head title="Connect Bank Account" />
      <Box>
        <Heading size="6" mb="4">Connect Bank Account</Heading>
        <Text color="gray" mb="4" as="p">
          Select your bank to connect your account.
        </Text>
        <Flex direction="column" gap="2" mt="4">
          {institutions.map((institution) => (
            <Card key={institution.id} style={{ cursor: "pointer" }}>
              <Flex align="center" gap="3">
                {institution.logo && (
                  <Avatar
                    src={institution.logo}
                    fallback={institution.name.charAt(0)}
                    size="3"
                  />
                )}
                <Text weight="medium">{institution.name}</Text>
              </Flex>
            </Card>
          ))}
        </Flex>
      </Box>
    </>
  )
}
