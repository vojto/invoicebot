import { Text } from "@radix-ui/themes"

function getDaysDifference(
  emailDate: string | null | undefined,
  accountingDate: string | null | undefined
): { days: number; isAfter: boolean } | null {
  if (!emailDate || !accountingDate) return null

  const email = new Date(emailDate)
  const accounting = new Date(accountingDate)

  // Reset time to compare just dates
  email.setHours(0, 0, 0, 0)
  accounting.setHours(0, 0, 0, 0)

  const diffTime = email.getTime() - accounting.getTime()
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24))

  return {
    days: Math.abs(diffDays),
    isAfter: diffDays >= 0,
  }
}

type Props = {
  emailDate: string | null | undefined
  accountingDate: string | null | undefined
}

export default function DateDifferenceBadge({ emailDate, accountingDate }: Props) {
  const diff = getDaysDifference(emailDate, accountingDate)

  if (!diff || diff.days === 0) return null

  return (
    <Text
      size="2"
      weight="medium"
      color={diff.isAfter ? "green" : "red"}
      ml="2"
    >
      ({diff.isAfter ? "+" : "-"}{diff.days}d)
    </Text>
  )
}
