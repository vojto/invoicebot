import { Head, router } from "@inertiajs/react"
import { Badge, Box, Button, Flex, Heading, Text, TextArea, TextField } from "@radix-ui/themes"
import { FormEvent, ReactNode, useState } from "react"
import { z } from "zod"

const CategorySchema = z.object({
  id: z.number(),
  name: z.string(),
  note: z.string().nullable(),
  invoices_count: z.number(),
})

const PropsSchema = z.object({
  categories: z.array(CategorySchema),
  uncategorized_count: z.number(),
})

type Props = z.infer<typeof PropsSchema>
type Category = z.infer<typeof CategorySchema>

const SERIF = "Iowan Old Style, Palatino, Georgia, serif"
const HAIRLINE = "1px solid var(--gray-a5)"

function pluralize(count: number, singular: string) {
  return count === 1 ? `${count} ${singular}` : `${count} ${singular}s`
}

function TextLink({
  children,
  color,
  onClick,
}: {
  children: ReactNode
  color?: "gray" | "red"
  onClick: () => void
}) {
  return (
    <Text asChild size="2" color={color}>
      <button
        type="button"
        onClick={onClick}
        style={{
          background: "none",
          border: "none",
          padding: 0,
          font: "inherit",
          color: "inherit",
          cursor: "pointer",
          textDecoration: "underline",
          textUnderlineOffset: "3px",
        }}
      >
        {children}
      </button>
    </Text>
  )
}

function CategoryForm({
  category,
  onCancel,
  onDelete,
}: {
  category: Category | null
  onCancel: () => void
  onDelete?: () => void
}) {
  const [name, setName] = useState(category?.name ?? "")
  const [note, setNote] = useState(category?.note ?? "")
  const [isSaving, setIsSaving] = useState(false)

  const save = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsSaving(true)

    const options = {
      preserveScroll: true,
      onSuccess: () => onCancel(),
      onFinish: () => setIsSaving(false),
    }
    const payload = { category: { name, note } }

    if (category) {
      router.patch(`/categories/${category.id}`, payload, options)
    } else {
      router.post("/categories", payload, options)
    }
  }

  return (
    <Box
      py="4"
      px="4"
      style={{
        backgroundColor: "var(--gray-a2)",
        borderRadius: "var(--radius-3)",
        margin: "0.6rem 0",
      }}
    >
      <form onSubmit={save}>
        <Flex direction="column" gap="3">
          <TextField.Root
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Category name"
            aria-label="Category name"
            maxLength={100}
            autoFocus
          />
          <TextArea
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Describe what belongs here, like you'd brief a bookkeeper."
            aria-label="Category note"
            rows={3}
            resize="vertical"
          />
          <Flex align="center" gap="4">
            <Button type="submit" color="green" radius="full" disabled={isSaving || name.trim() === ""}>
              Save changes
            </Button>
            <TextLink color="gray" onClick={onCancel}>
              Cancel
            </TextLink>
            {onDelete && (
              <Box style={{ marginLeft: "auto" }}>
                <TextLink color="red" onClick={onDelete}>
                  Delete…
                </TextLink>
              </Box>
            )}
          </Flex>
        </Flex>
      </form>
    </Box>
  )
}

function CategoryRow({ category }: { category: Category }) {
  const [isEditing, setIsEditing] = useState(false)

  const deleteCategory = () => {
    if (!window.confirm(`Delete “${category.name}”? Its invoices will become uncategorized.`)) return

    router.delete(`/categories/${category.id}`, { preserveScroll: true })
  }

  if (isEditing) {
    return (
      <Box style={{ borderTop: HAIRLINE }}>
        <CategoryForm category={category} onCancel={() => setIsEditing(false)} onDelete={deleteCategory} />
      </Box>
    )
  }

  return (
    <Box style={{ borderTop: HAIRLINE, padding: "1.1rem 0" }}>
      <Flex justify="between" align="center" gap="4">
        <Flex
          align="center"
          gap="3"
          onClick={() => setIsEditing(true)}
          style={{ cursor: "pointer" }}
        >
          <Text weight="bold" style={{ fontSize: "16px" }}>
            {category.name}
          </Text>
          <Text size="2" color="gray">
            {pluralize(category.invoices_count, "invoice")}
          </Text>
          {!category.note && (
            <Badge color="yellow" radius="full">
              No note yet
            </Badge>
          )}
        </Flex>
        <TextLink color="gray" onClick={() => setIsEditing(true)}>
          Edit
        </TextLink>
      </Flex>

      <Box mt="1" onClick={() => setIsEditing(true)} style={{ cursor: "pointer" }}>
        {category.note ? (
          <Text as="p" color="gray" style={{ fontSize: "14px", lineHeight: 1.6 }}>
            {category.note}
          </Text>
        ) : (
          <Text as="p" color="gray" style={{ fontSize: "14px", fontStyle: "italic" }}>
            Write a note so invoices can be filed here automatically.
          </Text>
        )}
      </Box>
    </Box>
  )
}

function AddCategory() {
  const [isAdding, setIsAdding] = useState(false)

  if (isAdding) {
    return <CategoryForm category={null} onCancel={() => setIsAdding(false)} />
  }

  return (
    <Flex justify="center" mt="4">
      <TextLink onClick={() => setIsAdding(true)}>Add a category</TextLink>
    </Flex>
  )
}

function UncategorizedNote({ count }: { count: number }) {
  return (
    <Box mt="6" pt="4" style={{ borderTop: HAIRLINE }}>
      <Text as="p" align="center" color="gray" style={{ fontSize: "12px" }}>
        {count === 0
          ? "Every invoice has a category."
          : `${pluralize(count, "invoice")} ${count === 1 ? "doesn't" : "don't"} have a category yet. Once your notes are ready, we'll take a pass at them.`}
      </Text>
    </Box>
  )
}

export default function CategoriesIndex(props: Props) {
  const { categories, uncategorized_count } = PropsSchema.parse(props)

  return (
    <>
      <Head title="Categories" />
      <Box style={{ maxWidth: "640px", margin: "0 auto", padding: "3rem 1.5rem" }}>
        <Heading align="center" size="8" mb="3" style={{ fontFamily: SERIF, fontWeight: 400 }}>
          Where does the money go?
        </Heading>
        <Text as="p" align="center" color="gray" style={{ fontSize: "15px", lineHeight: 1.7 }}>
          These are your categories. Describe each one like you'd brief a bookkeeper — every new invoice gets read and
          filed against these notes.
        </Text>

        <AddCategory />

        <Box mt="6">
          {categories.map((category) => (
            <CategoryRow key={category.id} category={category} />
          ))}
        </Box>

        <UncategorizedNote count={uncategorized_count} />
      </Box>
    </>
  )
}
