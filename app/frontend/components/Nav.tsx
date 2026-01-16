import { Link, usePage } from "@inertiajs/react"
import { Flex } from "@radix-ui/themes"

interface NavLinkProps {
  href: string
  children: React.ReactNode
  isActive: boolean
}

function NavLink({ href, children, isActive }: NavLinkProps) {
  return (
    <Link
      href={href}
      className={`px-3 py-1.5 rounded-md text-sm no-underline ${
        isActive
          ? "bg-white text-gray-900 border border-gray-200"
          : "text-gray-600 hover:text-gray-900 border border-transparent"
      }`}
    >
      {children}
    </Link>
  )
}

export default function Nav() {
  const { url } = usePage()

  return (
    <Flex asChild gap="1" align="center">
      <nav>
        <NavLink href="/dashboard" isActive={url.startsWith("/dashboard")}>
          Dashboard
        </NavLink>
        <NavLink href="/transactions" isActive={url.startsWith("/transactions")}>
          Transactions
        </NavLink>
      </nav>
    </Flex>
  )
}
