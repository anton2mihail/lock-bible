import { FC, useCallback, useEffect, useState } from "react"
import { FlatList, Pressable, TextStyle, TouchableOpacity, View, ViewStyle } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { useLibraryDatabase } from "@/services/database"
import {
  deleteSavedItem,
  listSavedItems,
  restoreSavedItem,
  type SavedFilter,
  type SavedItem,
} from "@/services/library"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const FILTERS: readonly { value: SavedFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "bookmark", label: "Bookmarks" },
  { value: "highlight", label: "Highlights" },
  { value: "note", label: "Notes" },
]

const HIGHLIGHT_FILLS = {
  gold: "#F4D89A",
  sage: "#C8D6C0",
  rose: "#E6C5C8",
  blue: "#C6D5E6",
} as const

export const SavedScreen: FC = function SavedScreen() {
  const database = useLibraryDatabase()
  const router = useRouter()
  const { themed } = useAppTheme()
  const [filter, setFilter] = useState<SavedFilter>("all")
  const [items, setItems] = useState<SavedItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState("")
  const [deletedItem, setDeletedItem] = useState<SavedItem | null>(null)

  const loadItems = useCallback(() => {
    setIsLoading(true)
    setError("")
    listSavedItems(database, filter)
      .then(setItems)
      .catch(() => setError("Saved passages could not be loaded. Close and reopen this tab."))
      .finally(() => setIsLoading(false))
  }, [database, filter])

  useFocusEffect(loadItems)

  useEffect(() => {
    if (!deletedItem) return
    const timeout = setTimeout(() => setDeletedItem(null), 10_000)
    return () => clearTimeout(timeout)
  }, [deletedItem])

  const openItem = (item: SavedItem) => {
    if (item.kind === "note") {
      router.push({
        pathname: "/note",
        params: {
          book: item.bookCode,
          chapter: String(item.chapter),
          startVerse: item.startVerse,
          endVerse: item.endVerse,
        },
      } as never)
      return
    }
    router.push({
      pathname: "/read",
      params: {
        book: item.bookCode,
        chapter: String(item.chapter),
        verse: item.startVerse,
        endVerse: item.endVerse,
        contextRequest: String(Date.now()),
      },
    })
  }

  const removeItem = async (item: SavedItem) => {
    try {
      await deleteSavedItem(database, item)
      setItems((current) => current.filter((candidate) => candidate.id !== item.id))
      setDeletedItem(item)
    } catch {
      setError("That saved item could not be deleted. Try again.")
    }
  }

  const undoDelete = async () => {
    if (!deletedItem) return
    try {
      await restoreSavedItem(database, deletedItem)
      setDeletedItem(null)
      loadItems()
    } catch {
      setError("That saved item could not be restored.")
    }
  }

  const emptyText = error
    ? error
    : isLoading
      ? "Loading saved passages…"
      : filter === "all"
        ? "Nothing saved yet. Select a verse while reading to bookmark, highlight, or add a note."
        : `No ${FILTERS.find((item) => item.value === filter)?.label.toLocaleLowerCase("en")} yet.`

  return (
    <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($screen)}>
      <Text text="Saved" preset="heading" style={themed($title)} accessibilityRole="header" />
      <View style={themed($filterRow)} accessibilityRole="tablist">
        {FILTERS.map((item) => {
          const selected = item.value === filter
          return (
            <TouchableOpacity
              key={item.value}
              onPress={() => setFilter(item.value)}
              style={themed([$filterButton, selected && $filterButtonSelected])}
              accessibilityRole="tab"
              accessibilityState={{ selected }}
              testID={`saved-filter-${item.value}`}
            >
              <Text
                text={item.label}
                size="xs"
                weight="medium"
                style={themed(selected ? $filterTextSelected : $filterText)}
              />
            </TouchableOpacity>
          )
        })}
      </View>

      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        contentContainerStyle={themed(items.length ? $list : $emptyList)}
        ListEmptyComponent={<Text text={emptyText} style={themed($emptyText)} />}
        renderItem={({ item }) => (
          <View style={themed($row)}>
            <View
              style={[
                themed($marker),
                item.color && { backgroundColor: HIGHLIGHT_FILLS[item.color] },
              ]}
              accessible={false}
            />
            <Pressable
              onPress={() => openItem(item)}
              style={({ pressed }) => [themed($rowContent), pressed && themed($rowPressed)]}
              accessibilityRole="button"
              accessibilityLabel={`${item.reference}, ${item.kind}. ${item.scriptureText}${item.noteText ? `. Private note: ${item.noteText}` : ""}`}
              accessibilityHint={item.kind === "note" ? "Opens note editor" : "Opens in reader"}
              testID={`saved-item-${item.kind}-${item.bookCode}-${item.chapter}-${item.startVerse}-${item.endVerse}`}
            >
              <Text text={item.reference} weight="semiBold" />
              <Text text={item.scriptureText} numberOfLines={3} style={themed($scriptureExcerpt)} />
              {item.noteText && (
                <Text
                  text={item.noteText}
                  numberOfLines={2}
                  size="xs"
                  style={themed($noteExcerpt)}
                />
              )}
              <Text text={labelFor(item)} size="xxs" style={themed($kindLabel)} />
            </Pressable>
            <TouchableOpacity
              onPress={() => removeItem(item)}
              style={themed($deleteButton)}
              accessibilityRole="button"
              accessibilityLabel={`Delete saved ${item.reference}`}
              testID={`delete-saved-${item.kind}-${item.bookCode}-${item.chapter}-${item.startVerse}-${item.endVerse}`}
            >
              <Text text="Delete" size="xxs" style={themed($deleteText)} />
            </TouchableOpacity>
          </View>
        )}
      />
      {deletedItem && (
        <View style={themed($undoBar)} accessibilityLiveRegion="polite">
          <Text text={`${deletedItem.reference} deleted`} size="xs" numberOfLines={1} />
          <TouchableOpacity
            onPress={undoDelete}
            style={themed($undoButton)}
            accessibilityRole="button"
            accessibilityLabel={`Undo deleting ${deletedItem.reference}`}
            testID="saved-undo"
          >
            <Text text="Undo" size="xs" weight="semiBold" style={themed($undoText)} />
          </TouchableOpacity>
        </View>
      )}
    </Screen>
  )
}

function labelFor(item: SavedItem): string {
  if (item.kind === "bookmark") return "Bookmark"
  if (item.kind === "note") return "Note"
  return `${item.color ? item.color[0].toUpperCase() + item.color.slice(1) : ""} highlight`
}

const $screen: ThemedStyle<ViewStyle> = ({ spacing }) => ({ flex: 1, paddingTop: spacing.md })
const $title: ThemedStyle<TextStyle> = ({ spacing }) => ({ paddingHorizontal: spacing.lg })
const $filterRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  paddingHorizontal: spacing.lg,
  paddingVertical: spacing.md,
  gap: spacing.xs,
})
const $filterButton: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flex: 1,
  minHeight: 44,
  justifyContent: "center",
  alignItems: "center",
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 10,
  paddingHorizontal: spacing.xxs,
})
const $filterButtonSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})
const $filterText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  textAlign: "center",
})
const $filterTextSelected: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
  textAlign: "center",
})
const $list: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xxl,
})
const $row: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flexDirection: "row",
  alignItems: "stretch",
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
  minHeight: 128,
  gap: spacing.sm,
})
const $marker: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 4,
  marginVertical: 16,
  borderRadius: 2,
  backgroundColor: colors.tint,
})
const $rowContent: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  justifyContent: "center",
  paddingVertical: spacing.md,
  gap: spacing.xs,
})
const $rowPressed: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.palette.neutral100,
})
const $scriptureExcerpt: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  fontFamily: "Georgia",
  fontSize: 16,
  lineHeight: 23,
})
const $noteExcerpt: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $kindLabel: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $deleteButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minWidth: 52,
  minHeight: 44,
  alignSelf: "center",
  alignItems: "flex-end",
  justifyContent: "center",
  paddingLeft: spacing.xs,
})
const $deleteText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.error })
const $emptyList: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexGrow: 1,
  justifyContent: "center",
  paddingHorizontal: spacing.xl,
  paddingBottom: spacing.xxl,
})
const $emptyText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
})
const $undoBar: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 52,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  marginHorizontal: spacing.md,
  marginBottom: spacing.sm,
  paddingLeft: spacing.md,
  paddingRight: spacing.xs,
  borderRadius: 12,
  backgroundColor: colors.palette.neutral100,
  borderWidth: 1,
  borderColor: colors.border,
  gap: spacing.sm,
})
const $undoButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minWidth: 56,
  minHeight: 44,
  alignItems: "center",
  justifyContent: "center",
  paddingHorizontal: spacing.xs,
})
const $undoText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
