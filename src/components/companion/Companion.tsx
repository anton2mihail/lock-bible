/* eslint-disable react-native/no-unused-styles -- exported styles are consumed by companion screens */
import type { ReactNode } from "react"
import { Image, ImageSourcePropType, Pressable, StyleSheet, View } from "react-native"
import { useRouter } from "expo-router"
import { Feather } from "@expo/vector-icons"

import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { useAppTheme } from "@/theme/context"

export const art = {
  scripture: require("../../../assets/artwork/scripture.jpg"),
  prayer: require("../../../assets/artwork/prayer.jpg"),
  mary: require("../../../assets/artwork/mary.jpg"),
  advent: require("../../../assets/artwork/advent.jpg"),
  christmas: require("../../../assets/artwork/christmas.jpg"),
  lent: require("../../../assets/artwork/lent.jpg"),
  triduum: require("../../../assets/artwork/triduum.jpg"),
  easter: require("../../../assets/artwork/easter.jpg"),
  ordinary: require("../../../assets/artwork/ordinary.jpg"),
  eucharist: require("../../../assets/artwork/eucharist.jpg"),
  confession: require("../../../assets/artwork/confession.jpg"),
  morning: require("../../../assets/artwork/morning.jpg"),
  evening: require("../../../assets/artwork/evening.jpg"),
  departed: require("../../../assets/artwork/departed.jpg"),
  "mental-health": require("../../../assets/artwork/mental-health.jpg"),
}
// Shared styles are consumed by companion screens across files.
// eslint-disable-next-line react-native/no-unused-styles
export const companionStyles = StyleSheet.create({
  body: { fontSize: 17, lineHeight: 28 },
  container: {
    alignSelf: "center",
    gap: 24,
    maxWidth: 740,
    padding: 24,
    paddingBottom: 48,
    width: "100%",
  },
  eyebrow: { fontSize: 11, letterSpacing: 2, lineHeight: 18, textTransform: "uppercase" },
  field: { minHeight: 140, textAlignVertical: "top" },
  flex: { flex: 1 },
  gap: { gap: 16 },
  heroImage: { aspectRatio: 1.7, borderRadius: 18, height: "auto", width: "100%" },
  row: { alignItems: "center", flexDirection: "row", flexWrap: "wrap", gap: 12 },
  serif: { fontFamily: "loraRegular", fontSize: 24, lineHeight: 36 },
  smallGap: { gap: 8 },
  spread: {
    alignItems: "center",
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
    justifyContent: "space-between",
  },
  title: { fontFamily: "loraRegular", fontSize: 36, letterSpacing: -0.8, lineHeight: 46 },
})
export function Page({
  children,
  title,
  eyebrow,
  subtitle,
  back = true,
}: {
  children: ReactNode
  title: string
  eyebrow?: string
  subtitle?: string
  back?: boolean
}) {
  const { theme } = useAppTheme()
  const router = useRouter()
  return (
    <Screen
      preset="scroll"
      safeAreaEdges={["top", "bottom"]}
      contentContainerStyle={companionStyles.container}
      ScrollViewProps={{ keyboardShouldPersistTaps: "handled", keyboardDismissMode: "on-drag" }}
    >
      {back && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Back"
          onPress={() => (router.canGoBack() ? router.back() : router.replace("/"))}
          style={styles.back}
        >
          <Feather name="arrow-left" size={20} color={theme.colors.tint} />
          <Text text="Back" size="xs" />
        </Pressable>
      )}
      <View style={companionStyles.smallGap}>
        {eyebrow && (
          <Text text={eyebrow} style={[companionStyles.eyebrow, { color: theme.colors.tint }]} />
        )}
        <Text text={title} accessibilityRole="header" style={companionStyles.title} />
        {subtitle && <Text text={subtitle} style={{ color: theme.colors.textDim }} />}
      </View>
      {children}
    </Screen>
  )
}
export function Panel({ children }: { children: ReactNode }) {
  const { theme } = useAppTheme()
  return (
    <View
      style={[
        styles.panel,
        { backgroundColor: theme.colors.palette.neutral100, borderColor: theme.colors.separator },
      ]}
    >
      {children}
    </View>
  )
}
export function SectionTitle({ title, detail }: { title: string; detail?: string }) {
  const { theme } = useAppTheme()
  return (
    <View style={companionStyles.smallGap}>
      <Text text={title} preset="subheading" accessibilityRole="header" />
      {detail && <Text text={detail} size="xs" style={{ color: theme.colors.textDim }} />}
    </View>
  )
}
export function ActionRow({
  title,
  subtitle,
  onPress,
  icon = "arrow-up-right",
  image,
}: {
  title: string
  subtitle?: string
  onPress: () => void
  icon?: keyof typeof Feather.glyphMap
  image?: ImageSourcePropType
}) {
  const { theme } = useAppTheme()
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`${title}${subtitle ? `. ${subtitle}` : ""}`}
      style={({ pressed }) => [
        styles.action,
        { borderBottomColor: theme.colors.separator, opacity: pressed ? 0.65 : 1 },
      ]}
    >
      {image && <Image source={image} style={styles.thumb} accessible={false} />}
      <View style={companionStyles.flex}>
        <Text text={title} weight="medium" />
        {subtitle && <Text text={subtitle} size="xs" style={{ color: theme.colors.textDim }} />}
      </View>
      <Feather name={icon} size={19} color={theme.colors.tint} />
    </Pressable>
  )
}
export function ArtCard({
  title,
  subtitle,
  image,
  onPress,
}: {
  title: string
  subtitle: string
  image: ImageSourcePropType
  onPress: () => void
}) {
  const { theme } = useAppTheme()
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${title}. ${subtitle}`}
      onPress={onPress}
      style={({ pressed }) => [
        styles.artCard,
        { opacity: pressed ? 0.8 : 1, backgroundColor: theme.colors.palette.neutral100 },
      ]}
    >
      <Image source={image} style={styles.cardImage} accessible={false} />
      <View style={styles.cardCopy}>
        <View style={companionStyles.flex}>
          <Text text={title} style={styles.cardTitle} />
          <Text text={subtitle} size="xs" style={{ color: theme.colors.textDim }} />
        </View>
        <Feather name="arrow-up-right" size={21} color={theme.colors.tint} />
      </View>
    </Pressable>
  )
}
export function Muted({ text }: { text: string }) {
  const { theme } = useAppTheme()
  return <Text text={text} size="xs" style={{ color: theme.colors.textDim }} />
}
const styles = StyleSheet.create({
  action: {
    alignItems: "center",
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: "row",
    gap: 16,
    minHeight: 72,
    paddingVertical: 12,
  },
  artCard: { borderCurve: "continuous", borderRadius: 18, overflow: "hidden" },
  back: {
    alignItems: "center",
    alignSelf: "flex-start",
    flexDirection: "row",
    gap: 10,
    minHeight: 44,
  },
  cardCopy: { alignItems: "center", flexDirection: "row", gap: 16, padding: 20 },
  cardImage: { aspectRatio: 2, height: "auto", width: "100%" },
  cardTitle: { fontFamily: "loraRegular", fontSize: 23, lineHeight: 31 },
  panel: { borderRadius: 18, borderWidth: StyleSheet.hairlineWidth, gap: 16, padding: 20 },
  thumb: { borderRadius: 8, height: 76, width: 64 },
})
