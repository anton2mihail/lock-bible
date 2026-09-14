import { FC, useEffect, useMemo, useState } from "react"
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  TextStyle,
  TouchableOpacity,
  View,
  ViewStyle,
} from "react-native"
import { useRouter } from "expo-router"

import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { TextField } from "@/components/TextField"
import {
  searchBible,
  type BibleSearchResponse,
  type BibleSearchResult,
  type SearchScope,
} from "@/services/bible/searchService"
import { useSearchDatabase } from "@/services/database"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const SCOPES: readonly { value: SearchScope; label: string }[] = [
  { value: "all", label: "All" },
  { value: "ot", label: "Old Testament" },
  { value: "nt", label: "New Testament" },
]

const EMPTY_RESPONSE: BibleSearchResponse = { results: [], isReference: false }

export const SearchScreen: FC = function SearchScreen() {
  const database = useSearchDatabase()
  const router = useRouter()
  const { themed, theme } = useAppTheme()
  const [query, setQuery] = useState("")
  const [scope, setScope] = useState<SearchScope>("all")
  const [response, setResponse] = useState<BibleSearchResponse>(EMPTY_RESPONSE)
  const [isSearching, setIsSearching] = useState(false)
  const [error, setError] = useState("")

  useEffect(() => {
    const trimmed = query.trim()
    if (trimmed.length < 2) {
      setResponse(EMPTY_RESPONSE)
      setIsSearching(false)
      setError("")
      return
    }

    let cancelled = false
    setIsSearching(true)
    setError("")
    const timeout = setTimeout(() => {
      searchBible(database, trimmed, scope)
        .then((nextResponse) => {
          if (!cancelled) setResponse(nextResponse)
        })
        .catch(() => {
          if (!cancelled) setError("Search could not be completed. Try a different phrase.")
        })
        .finally(() => {
          if (!cancelled) setIsSearching(false)
        })
    }, 220)

    return () => {
      cancelled = true
      clearTimeout(timeout)
    }
  }, [database, query, scope])

  const searchTerms = useMemo(
    () =>
      (response.correctedQuery ?? query)
        .replace(/["“”]/g, "")
        .toLocaleLowerCase("en")
        .match(/[\p{Letter}\p{Number}]+/gu) ?? [],
    [query, response.correctedQuery],
  )

  const openResult = (result: BibleSearchResult) => {
    router.push({
      pathname: "/read",
      params: {
        book: result.bookCode,
        chapter: String(result.chapter),
        verse: result.verse,
        contextRequest: String(Date.now()),
      },
    })
  }

  const renderResult = ({ item }: { item: BibleSearchResult }) => (
    <Pressable
      onPress={() => openResult(item)}
      style={({ pressed }) => themed([$result, pressed && $resultPressed])}
      accessibilityRole="button"
      accessibilityLabel={`${item.reference}. ${item.text}`}
      accessibilityHint="Opens this verse in context"
      testID={`search-result-${item.bookCode}-${item.chapter}-${item.verse}`}
    >
      <Text text={item.reference} weight="semiBold" style={themed($reference)} />
      <HighlightedResult text={item.text} terms={searchTerms} />
    </Pressable>
  )

  const hasQuery = query.trim().length >= 2
  const emptyText = error
    ? error
    : hasQuery && !isSearching
      ? "No passages found. Try fewer words or check the reference."
      : "Search by reference, keyword, or exact phrase."

  return (
    <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($screen)}>
      <View style={themed($titleRow)}>
        <Text text="Search Scripture" preset="heading" accessibilityRole="header" />
        <TouchableOpacity
          onPress={() => router.back()}
          style={themed($cancelButton)}
          accessibilityRole="button"
          accessibilityLabel="Close search"
        >
          <Text text="Cancel" weight="medium" style={themed($cancelText)} />
        </TouchableOpacity>
      </View>

      <View style={themed($searchField)}>
        <Text text="⌕" size="xl" style={themed($searchGlyph)} accessible={false} />
        <TextField
          value={query}
          onChangeText={setQuery}
          placeholder="Search Scripture"
          autoFocus
          autoCorrect={false}
          returnKeyType="search"
          clearButtonMode="while-editing"
          style={themed($searchInput)}
          containerStyle={themed($searchInputContainer)}
          inputWrapperStyle={themed($searchInputWrapper)}
          accessibilityLabel="Search Scripture"
          testID="scripture-search-input"
        />
        {isSearching && (
          <ActivityIndicator color={theme.colors.tint} accessibilityLabel="Searching" />
        )}
      </View>

      <View style={themed($scopeRow)} accessibilityRole="radiogroup">
        {SCOPES.map((item) => {
          const selected = item.value === scope
          return (
            <TouchableOpacity
              key={item.value}
              onPress={() => setScope(item.value)}
              style={themed([$scopeButton, selected && $scopeButtonSelected])}
              accessibilityRole="radio"
              accessibilityState={{ checked: selected }}
              accessibilityLabel={`Search ${item.label}`}
            >
              <Text
                text={item.label}
                size="xs"
                weight="medium"
                style={themed(selected ? $scopeTextSelected : $scopeText)}
              />
            </TouchableOpacity>
          )
        })}
      </View>

      {response.correctedQuery && (
        <Text
          text={`Showing results for “${response.correctedQuery}”`}
          size="xs"
          style={themed($correction)}
          accessibilityLiveRegion="polite"
        />
      )}
      {response.results.length > 0 && (
        <Text
          text={`${response.results.length}${response.results.length === 60 ? "+" : ""} results`}
          size="xs"
          style={themed($resultCount)}
          accessibilityLiveRegion="polite"
        />
      )}

      <FlatList
        data={response.results}
        keyExtractor={(item) => String(item.id)}
        renderItem={renderResult}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={themed(response.results.length ? $results : $emptyContainer)}
        ListEmptyComponent={<Text text={emptyText} style={themed($emptyText)} />}
      />
    </Screen>
  )
}

function HighlightedResult({ text, terms }: { text: string; terms: string[] }) {
  const { themed } = useAppTheme()
  if (!terms.length) return <Text text={text} style={themed($resultText)} />
  const escaped = terms.map((term) => term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
  const pattern = new RegExp(`(${escaped.join("|")})`, "gi")
  const parts = text.split(pattern)
  const normalizedTerms = new Set(terms.map((term) => term.toLocaleLowerCase("en")))
  return (
    <Text style={themed($resultText)}>
      {parts.map((part, index) =>
        normalizedTerms.has(part.toLocaleLowerCase("en")) ? (
          <Text key={`${part}-${index}`} text={part} weight="semiBold" style={themed($match)} />
        ) : (
          part
        ),
      )}
    </Text>
  )
}

const $screen: ThemedStyle<ViewStyle> = ({ spacing }) => ({ flex: 1, paddingTop: spacing.md })
const $titleRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  paddingHorizontal: spacing.lg,
  gap: spacing.sm,
})
const $cancelButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingHorizontal: spacing.xs,
})
const $cancelText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $searchField: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 48,
  flexDirection: "row",
  alignItems: "center",
  marginHorizontal: spacing.lg,
  marginTop: spacing.md,
  paddingHorizontal: spacing.sm,
  backgroundColor: colors.palette.neutral100,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 12,
  gap: spacing.xs,
})
const $searchInputContainer: ThemedStyle<ViewStyle> = () => ({ flex: 1 })
const $searchInputWrapper: ThemedStyle<ViewStyle> = () => ({
  flex: 1,
  borderWidth: 0,
  backgroundColor: "transparent",
})
const $searchGlyph: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $searchInput: ThemedStyle<TextStyle> = ({ colors, typography }) => ({
  flex: 1,
  minHeight: 44,
  color: colors.text,
  fontFamily: typography.primary.normal,
  fontSize: 16,
})
const $scopeRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  paddingHorizontal: spacing.lg,
  paddingVertical: spacing.sm,
  gap: spacing.xs,
})
const $scopeButton: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flex: 1,
  minHeight: 44,
  justifyContent: "center",
  alignItems: "center",
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 10,
  paddingHorizontal: spacing.xxs,
})
const $scopeButtonSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})
const $scopeText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  textAlign: "center",
})
const $scopeTextSelected: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
  textAlign: "center",
})
const $correction: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.tint,
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xs,
})
const $resultCount: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  paddingHorizontal: spacing.lg,
  paddingVertical: spacing.xs,
})
const $results: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingBottom: spacing.xxl,
})
const $result: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  paddingVertical: spacing.md,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
  gap: spacing.xs,
})
const $resultPressed: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.palette.neutral100,
})
const $reference: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text })
const $resultText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  fontFamily: "Georgia",
  fontSize: 17,
  lineHeight: 26,
})
const $match: ThemedStyle<TextStyle> = ({ colors, isDark }) => ({
  color: colors.text,
  backgroundColor: isDark ? "rgba(244, 216, 154, 0.24)" : "#F4D89A",
})
const $emptyContainer: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexGrow: 1,
  justifyContent: "center",
  paddingHorizontal: spacing.xl,
  paddingBottom: spacing.xxl,
})
const $emptyText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.textDim,
  textAlign: "center",
})
