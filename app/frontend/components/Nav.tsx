import { Link } from "@inertiajs/react"
import { Flex } from "@radix-ui/themes"

export default function Nav() {
  return (
    <Flex asChild gap="4">
      <nav>
        <Link
          href="/dashboard"
          style={{
            color: "var(--gray-11)",
            textDecoration: "none",
            fontSize: "var(--font-size-2)",
          }}
        >
          Dashboard
        </Link>
        <Link
          href="/transactions"
          style={{
            color: "var(--gray-11)",
            textDecoration: "none",
            fontSize: "var(--font-size-2)",
          }}
        >
          Transactions
        </Link>
      </nav>
    </Flex>
  )
}
