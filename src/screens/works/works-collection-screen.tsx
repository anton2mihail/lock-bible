import { FC, useMemo } from "react"
import { Pressable, TextStyle, View, ViewStyle } from "react-native"
import { useRouter } from "expo-router"

import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  formatReadingLength,
  getCollection,
  getCollectionWorks,
  plural,
  WORK_KIND_LABEL,
  WORK_KIND_ORDER,
  type WorkMeta,
} from "@/services/works"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

type WorksCollectionScreenProps = {
  collectionId?: string
}

export const WorksCollectionScreen: FC<WorksCollectionScreenProps> =
  function WorksCollectionScreen({ collectionId }) {
    const { themed } = useAppTheme()
    const router = useRouter()

    const collection = getCollection(collectionId)
    const works = getCollectionWorks(collectionId)

    // Grouped by what a work is, so the treatises and letters that expound no
    // chapter of Scripture get a heading of their own rather than trailing
    // behind the commentaries in one undifferentiated list.
    const groups = useMemo(() => {
      const byKind = new Map<string, WorkMeta[]>()
      for (const work of works) {
        const bucket = byKind.get(work.kind)
        if (bucket) bucket.push(work)
        else byKind.set(work.kind, [work])
      }
      return WORK_KIND_ORDER.filter((kind) => byKind.has(kind)).map((kind) => ({
        kind,
        label: WORK_KIND_LABEL[kind],
        works: byKind.get(kind)!,
      }))
    }, [works])

    if (!collection) {
      return (
        <Screen preset="fixed" safeAreaEdges={["top"]} contentContainerStyle={themed($missing)}>
          <Text text="That author isn’t available" preset="subheading" />
          <Pressable onPress={() => router.back()} accessibilityRole="button" hitSlop={8}>
            <Text text="Go back" size="sm" style={themed($tint)} />
          </Pressable>
        </Screen>
      )
    }

    return (
      <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
        <Pressable
          onPress={() => router.back()}
          accessibilityRole="button"
          accessibilityLabel="Back to the library"
          hitSlop={8}
          style={({ pressed }) => themed([$back, pressed && $pressed])}
        >
          <Text text="‹" size="xl" style={themed($backMark)} />
          <Text text="Library" size="sm" weight="semiBold" style={themed($tint)} />
        </Pressable>

        <View style={themed($heading)}>
          {collection.era && (
            <Text
              text={collection.era.toUpperCase()}
              size="xxs"
              weight="semiBold"
              style={themed($eyebrow)}
            />
          )}
          <Text text={collection.author} preset="heading" accessibilityRole="header" />
          <Text
            text={`${plural(collection.workCount, "work")} · ${plural(collection.sectionCount, "section")} · reads offline`}
            size="sm"
            style={themed($subtitle)}
          />
        </View>

        {groups.map((group) => (
          <View key={group.kind} style={themed($group)}>
            <Text
              text={group.label}
              preset="formLabel"
              style={themed($groupHeader)}
              accessibilityRole="header"
            />
            {group.works.map((work) => (
              <Pressable
                key={work.id}
                onPress={() => router.push({ pathname: "/works/[id]", params: { id: work.id } })}
                accessibilityRole="button"
                accessibilityLabel={`${work.title}. ${plural(work.sectionCount, "section")}. ${formatReadingLength(work.words)}.`}
                testID={`work-${work.id}`}
                style={({ pressed }) => themed([$row, pressed && $pressed])}
              >
                <View style={$flex}>
                  <Text text={work.title} weight="medium" />
                  <Text
                    text={
                      work.sectionCount > 1
                        ? `${plural(work.sectionCount, "section")} · ${formatReadingLength(work.words)}`
                        : formatReadingLength(work.words)
                    }
                    size="xxs"
                    style={themed($meta)}
                  />
                </View>
                <Text text="›" size="xl" style={themed($tint)} />
              </Pressable>
            ))}
          </View>
        ))}

        <Text text={collection.attribution} size="xxs" style={themed($attribution)} />
      </Screen>
    )
  }

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.md,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})
const $missing: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  alignItems: "center",
  justifyContent: "center",
  gap: spacing.sm,
})
const $back: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 40,
  alignSelf: "flex-start",
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.xxs,
})
const $backMark: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint, marginTop: -2 })
const $heading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })
const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.5,
  textTransform: "uppercase",
})
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $meta: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $group: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xxs })
const $groupHeader: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.textDim,
  marginBottom: spacing.xxs,
})
const $row: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 68,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.md,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
  paddingVertical: spacing.sm,
})
const $attribution: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $tint: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.7 })
const $flex: ViewStyle = { flex: 1 }
