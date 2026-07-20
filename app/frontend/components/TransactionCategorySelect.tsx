import { router } from "@inertiajs/react"
import { Select } from "@radix-ui/themes"
import { useEffect, useState } from "react"
import { z } from "zod"

export const CategorySchema = z.object({
  id: z.number(),
  name: z.string(),
})

export type Category = z.infer<typeof CategorySchema>

const PropsSchema = z.object({
  transactionId: z.number().nullable(),
  category: CategorySchema.nullable(),
  categories: z.array(CategorySchema),
})

type Props = z.infer<typeof PropsSchema>

const UNCATEGORIZED_VALUE = "uncategorized"

export default function TransactionCategorySelect(props: Props) {
  const { transactionId, category, categories } = PropsSchema.parse(props)
  const persistedValue = category?.id.toString() ?? UNCATEGORIZED_VALUE
  const [value, setValue] = useState(persistedValue)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => setValue(persistedValue), [persistedValue])

  const updateCategory = (nextValue: string) => {
    if (!transactionId || nextValue === value) return

    const previousValue = value
    setValue(nextValue)
    setIsSaving(true)

    router.patch(
      `/transactions/${transactionId}/category`,
      { category_id: nextValue === UNCATEGORIZED_VALUE ? null : Number(nextValue) },
      {
        preserveScroll: true,
        onError: () => setValue(previousValue),
        onFinish: () => setIsSaving(false),
      },
    )
  }

  return (
    <Select.Root size="1" value={value} onValueChange={updateCategory} disabled={isSaving || !transactionId}>
      <Select.Trigger
        aria-label="Transaction category"
        variant="soft"
        color="gray"
        className="font-medium"
        style={{ minWidth: "150px", maxWidth: "190px", backgroundColor: "var(--gray-3)" }}
      />
      <Select.Content position="popper">
        <Select.Item value={UNCATEGORIZED_VALUE}>Uncategorized</Select.Item>
        {categories.map((availableCategory) => (
          <Select.Item key={availableCategory.id} value={availableCategory.id.toString()}>
            {availableCategory.name}
          </Select.Item>
        ))}
      </Select.Content>
    </Select.Root>
  )
}
