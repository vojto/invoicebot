import { Head, router } from "@inertiajs/react"
import { Box, Button, Flex, Heading, Table, Text, TextField } from "@radix-ui/themes"
import { FormEvent, useState } from "react"
import { z } from "zod"

const CategorySchema = z.object({
  id: z.number(),
  name: z.string(),
  invoices_count: z.number(),
})

const PropsSchema = z.object({
  categories: z.array(CategorySchema),
})

type Props = z.infer<typeof PropsSchema>
type Category = z.infer<typeof CategorySchema>

function CategoryRow({ category }: { category: Category }) {
  const [name, setName] = useState(category.name)
  const [isSaving, setIsSaving] = useState(false)

  const saveCategory = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsSaving(true)
    router.patch(
      `/categories/${category.id}`,
      { category: { name } },
      {
        preserveScroll: true,
        onFinish: () => setIsSaving(false),
      },
    )
  }

  const deleteCategory = () => {
    if (!window.confirm(`Delete “${category.name}”? Its invoices will become uncategorized.`)) return

    router.delete(`/categories/${category.id}`, { preserveScroll: true })
  }

  const unchanged = name.trim() === category.name

  return (
    <Table.Row>
      <Table.Cell>
        <form onSubmit={saveCategory}>
          <Flex gap="2" align="center">
            <TextField.Root
              value={name}
              onChange={(event) => setName(event.target.value)}
              aria-label={`Category name: ${category.name}`}
              maxLength={100}
              style={{ width: "280px" }}
            />
            <Button type="submit" size="1" variant="soft" disabled={isSaving || unchanged || name.trim() === ""}>
              Save
            </Button>
          </Flex>
        </form>
      </Table.Cell>
      <Table.Cell>{category.invoices_count}</Table.Cell>
      <Table.Cell>
        <Button size="1" variant="soft" color="red" onClick={deleteCategory}>
          Delete
        </Button>
      </Table.Cell>
    </Table.Row>
  )
}

export default function CategoriesIndex(props: Props) {
  const { categories } = PropsSchema.parse(props)
  const [name, setName] = useState("")
  const [isCreating, setIsCreating] = useState(false)

  const createCategory = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsCreating(true)
    router.post(
      "/categories",
      { category: { name } },
      {
        preserveScroll: true,
        onSuccess: () => setName(""),
        onFinish: () => setIsCreating(false),
      },
    )
  }

  return (
    <>
      <Head title="Categories" />
      <Box>
        <Heading size="6" mb="2">Categories</Heading>
        <Text color="gray" as="p" mb="5">
          Create categories for classifying your invoices.
        </Text>

        <form onSubmit={createCategory}>
          <Flex gap="2" align="center" mb="6">
            <TextField.Root
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="New category name"
              aria-label="New category name"
              maxLength={100}
              style={{ width: "320px" }}
            />
            <Button type="submit" disabled={isCreating || name.trim() === ""}>
              Add category
            </Button>
          </Flex>
        </form>

        {categories.length === 0 ? (
          <Text color="gray">No categories yet.</Text>
        ) : (
          <Table.Root variant="surface" style={{ maxWidth: "700px" }}>
            <Table.Header>
              <Table.Row>
                <Table.ColumnHeaderCell>Name</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell width="140px">Invoices</Table.ColumnHeaderCell>
                <Table.ColumnHeaderCell width="100px">Actions</Table.ColumnHeaderCell>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {categories.map((category) => <CategoryRow key={category.id} category={category} />)}
            </Table.Body>
          </Table.Root>
        )}
      </Box>
    </>
  )
}
