export default function formatCurrency(amountCents: number, currency: string | null): string {
  const currencyCode = currency || "EUR"

  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currencyCode,
      currencyDisplay: "narrowSymbol",
    }).format(amountCents / 100)
  } catch {
    return `${(amountCents / 100).toFixed(2)} ${currencyCode}`
  }
}
