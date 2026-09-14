import { FC, useCallback, useMemo, useState } from "react"
import { Image, Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { ActionRow, art, ArtCard } from "@/components/companion/Companion"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { TextField } from "@/components/TextField"
import { novenaArt } from "@/services/companion/artwork"
import {
  loadNovenaProgress,
  NOVENA_DAY_COUNT,
  novenas,
  searchNovenas,
  type Novena,
  type NovenaProgress,
} from "@/services/novena"
import { getRosaryReminderSummary, getSuggestedRosaryMysterySet } from "@/services/rosary"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

type ProgressById = Record<string, NovenaProgress>

function loadLibraryProgress(): ProgressById {
  return Object.fromEntries(novenas.map((novena) => [novena.id, loadNovenaProgress(novena.id)]))
}

export const NovenaLibraryScreen: FC = function NovenaLibraryScreen() {
  const { themed } = useAppTheme()
  const router = useRouter()
  const [query, setQuery] = useState("")
  const [progressById, setProgressById] = useState<ProgressById>(loadLibraryProgress)
  const [rosaryReminder, setRosaryReminder] = useState(getRosaryReminderSummary)
  const results = useMemo(() => searchNovenas(query), [query])
  const suggestedMysteries = getSuggestedRosaryMysterySet()

  useFocusEffect(
    useCallback(() => {
      setProgressById(loadLibraryProgress())
      setRosaryReminder(getRosaryReminderSummary())
    }, []),
  )

  const openNovena = useCallback(
    (novena: Novena) =>
      router.push({
        pathname: "/pray/[id]",
        params: { id: novena.id },
      }),
    [router],
  )

  return (
    <Screen
      preset="scroll"
      safeAreaEdges={["top"]}
      contentContainerStyle={themed($container)}
      ScrollViewProps={{ keyboardDismissMode: "on-drag", keyboardShouldPersistTaps: "handled" }}
    >
      <View style={themed($heading)}>
        <Text text="PRAYER LIBRARY" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text="Prayer" preset="heading" accessibilityRole="header" />
        <Text
          text="Everyday prayer, the Rosary, and Catholic novenas. A little space to be with God."
          size="sm"
          style={themed($subtitle)}
        />
      </View>

      <ArtCard
        title="Pray the Rosary"
        subtitle={`${suggestedMysteries.title} · ${rosaryReminder}`}
        image={art.mary}
        onPress={() => router.push("/pray/rosary")}
      />
      <View>
        <ActionRow
          title="Everyday prayers"
          subtitle="Morning offerings, the Angelus, and words for difficult days"
          onPress={() => router.push("/prayers")}
        />
        <ActionRow
          title="Pray with Scripture"
          subtitle="A quiet guide to lectio divina"
          onPress={() => router.push("/lectio")}
        />
        <ActionRow
          title="Prepare for Confession"
          subtitle="Return to mercy, one step at a time"
          onPress={() => router.push("/confession")}
        />
        <ActionRow
          title="Explore the Catholic faith"
          subtitle="Scripture and the Catechism"
          onPress={() => router.push("/learn")}
        />
      </View>

      <View style={themed($novenaHeading)}>
        <Text text="Novenas" preset="subheading" />
        <Text text="Nine days of prayer" size="xxs" style={themed($resultMeta)} />
      </View>

      <TextField
        testID="novena-search"
        accessibilityLabel="Search novenas"
        placeholder="Search by saint or need…"
        value={query}
        onChangeText={setQuery}
        returnKeyType="search"
        autoCapitalize="none"
        autoCorrect={false}
        inputWrapperStyle={themed($searchInput)}
      />

      <View style={themed($resultHeader)}>
        <Text
          text={query.trim() ? `${results.length} found` : `${novenas.length} novenas`}
          size="xs"
          weight="semiBold"
        />
        <Text text="Available offline" size="xs" style={themed($resultMeta)} />
      </View>

      {results.length > 0 ? (
        <View style={themed($list)}>
          {results.map((novena, index) => {
            const completedDays = progressById[novena.id]?.completedDays ?? []
            return (
              <Pressable
                key={novena.id}
                onPress={() => openNovena(novena)}
                accessibilityRole="button"
                accessibilityLabel={`${novena.title}. ${novena.subtitle}. ${completedDays.length} of 9 days prayed.`}
                testID={`novena-${novena.id}`}
                style={({ pressed }) =>
                  themed([$card, pressed && $cardPressed, index === 0 && $firstCard])
                }
              >
                <View style={themed($cardTop)}>
                  <Image source={novenaArt(novena.id)} style={$portrait} accessible={false} />
                  <View style={themed($cardCopy)}>
                    <Text text={novena.title} preset="subheading" />
                    <Text text={novena.subtitle} size="xs" style={themed($cardSubtitle)} />
                    <Text
                      text={`Patronage · ${novena.patronage}`}
                      size="xxs"
                      style={themed($cardPatronage)}
                    />
                  </View>
                  <Text text="›" size="xl" style={themed($chevron)} />
                </View>

                <View style={themed($beadRow)} accessibilityElementsHidden>
                  {Array.from({ length: NOVENA_DAY_COUNT }, (_, dayIndex) => {
                    const day = dayIndex + 1
                    const complete = completedDays.includes(day)
                    return (
                      <View key={day} style={themed([$miniBead, complete && $miniBeadComplete])} />
                    )
                  })}
                </View>

                <View style={themed($cardFooter)}>
                  <Text
                    text={
                      completedDays.length
                        ? `${completedDays.length} of 9 prayed`
                        : "Ready to begin"
                    }
                    size="xxs"
                    weight="semiBold"
                    style={themed($progressText)}
                  />
                  {novena.feastDay && (
                    <Text text={`Feast ${novena.feastDay}`} size="xxs" style={themed($feast)} />
                  )}
                </View>
              </Pressable>
            )
          })}
        </View>
      ) : (
        <View style={themed($empty)} accessibilityRole="summary">
          <Text text="No novenas found" preset="subheading" />
          <Text
            text="Try a saint’s name or a need such as healing or hope."
            size="sm"
            style={themed($subtitle)}
          />
        </View>
      )}
    </Screen>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.lg,
  paddingBottom: spacing.xl,
  gap: spacing.lg,
})

const $heading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })
const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.8,
})
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $searchInput: ThemedStyle<ViewStyle> = ({ colors }) => ({
  minHeight: 52,
  backgroundColor: colors.palette.neutral100,
  borderColor: colors.border,
  borderRadius: 14,
})

const $resultHeader: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  justifyContent: "space-between",
  alignItems: "baseline",
  gap: spacing.sm,
})
const $resultMeta: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $list: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.md })

const $novenaHeading: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  justifyContent: "space-between",
  alignItems: "baseline",
  gap: spacing.sm,
})

const $card: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 176,
  backgroundColor: colors.palette.neutral100,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 20,
  padding: spacing.lg,
  gap: spacing.lg,
})
const $firstCard: ThemedStyle<ViewStyle> = ({ colors }) => ({ borderTopColor: colors.tint })
const $cardPressed: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.background,
  transform: [{ scale: 0.99 }],
})
const $cardTop: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "flex-start",
  gap: spacing.md,
})
const $cardCopy: ThemedStyle<ViewStyle> = ({ spacing }) => ({ flex: 1, gap: spacing.xs })
const $cardSubtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $cardPatronage: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginTop: spacing.xxs,
  lineHeight: 18,
})
const $chevron: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint, marginTop: -5 })

const $beadRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  gap: spacing.xs,
})
const $miniBead: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 10,
  height: 10,
  borderRadius: 5,
  borderWidth: 1,
  borderColor: colors.border,
  backgroundColor: colors.background,
})
const $miniBeadComplete: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})

const $cardFooter: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  justifyContent: "space-between",
  flexWrap: "wrap",
  gap: spacing.sm,
})
const $progressText: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textTransform: "uppercase",
  letterSpacing: 1,
})
const $feast: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $empty: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 20,
  padding: spacing.lg,
  gap: spacing.sm,
})

const $portrait = { width: 76, height: 92, borderRadius: 10 }
