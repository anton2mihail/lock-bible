import { useMemo, useRef, useState } from "react"
import { ImageBackground, Platform, Share, StyleSheet, View } from "react-native"
import { useLocalSearchParams } from "expo-router"
import * as Sharing from "expo-sharing"
import { captureRef, releaseCapture } from "react-native-view-shot"

import { Button } from "@/components/Button"
import { companionStyles as s, Muted, Page } from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import { type PassageParams, resolvePassage } from "@/services/companion/passage"

const CARD_COLORS = { ivory: "#F4EADB", plum: "#2F1D2C" }
const BACKGROUNDS = {
  ivory: require("../../../assets/artwork/share-ivory.jpg"),
  plum: require("../../../assets/artwork/share-plum.jpg"),
}
export function ShareCardScreen() {
  const params = useLocalSearchParams<PassageParams>(),
    passage = useMemo(
      () =>
        resolvePassage({
          book: params.book,
          chapter: params.chapter,
          startVerse: params.startVerse,
          endVerse: params.endVerse,
          translation: params.translation,
        }),
      [params.book, params.chapter, params.startVerse, params.endVerse, params.translation],
    )
  const [appearance, setAppearance] = useState<"ivory" | "plum">("ivory"),
    [busy, setBusy] = useState(false),
    [ready, setReady] = useState(false),
    [error, setError] = useState("")
  const card = useRef<View>(null)
  if (!passage)
    return (
      <Page title="Create a Scripture card">
        <Muted text="Select a passage in the Bible reader to create a card." />
      </Page>
    )
  const shareText = () =>
    Share.share({
      message: `${passage.text}\n\n${passage.reference} (${passage.translation})\nJohn 1:1 · Scripture & Prayer`,
    })
  const share = async () => {
    setBusy(true)
    setError("")
    let uri: string | undefined
    try {
      if (Platform.OS === "web" || !(await Sharing.isAvailableAsync())) {
        await shareText()
        return
      }
      uri = await captureRef(card, { format: "png", quality: 1, result: "tmpfile", width: 1080 })
      await Sharing.shareAsync(uri, {
        mimeType: "image/png",
        UTI: "public.png",
        dialogTitle: "Share Scripture",
      })
    } catch {
      setError("The card could not be shared. Please try again, or share the text.")
    } finally {
      if (uri) releaseCapture(uri)
      setBusy(false)
    }
  }
  const color = appearance === "ivory" ? "#34262D" : "#FFF7E8"
  return (
    <Page
      title="A word worth sharing"
      eyebrow="Scripture cards"
      subtitle="Choose a background. Keep the words at the center."
    >
      <View style={s.row}>
        {(["ivory", "plum"] as const).map((value) => (
          <Button
            key={value}
            text={value === "ivory" ? "Warm ivory" : "Evening plum"}
            accessibilityState={{ selected: appearance === value }}
            preset={appearance === value ? "reversed" : "default"}
            onPress={() => {
              if (value !== appearance) {
                setReady(false)
                setAppearance(value)
              }
            }}
          />
        ))}
      </View>
      <View
        ref={card}
        collapsable={false}
        style={[styles.card, appearance === "ivory" ? styles.ivory : styles.plum]}
      >
        <ImageBackground
          key={appearance}
          source={BACKGROUNDS[appearance]}
          resizeMode="cover"
          style={styles.background}
          onLoad={() => setReady(true)}
          onError={() => {
            setReady(true)
            setError("Artwork could not load. You can still share the words on a plain background.")
          }}
        >
          <Text text="JOHN 1:1" style={[styles.wordmark, { color }]} />
          <Text
            text={passage.text}
            style={[
              styles.quote,
              { color },
              passage.text.length > 900 ? styles.longQuote : styles.shortQuote,
            ]}
          />
          <View style={styles.reference}>
            <Text text={passage.reference} weight="medium" style={{ color }} />
            <Text text={passage.translation} size="xs" style={{ color }} />
          </View>
        </ImageBackground>
      </View>
      <Button
        text={busy ? "Preparing…" : Platform.OS === "web" ? "Share text" : "Share Scripture card"}
        preset="reversed"
        disabled={busy || (Platform.OS !== "web" && !ready)}
        onPress={() => void share()}
      />
      {Platform.OS !== "web" && (
        <Button
          text="Share text instead"
          disabled={busy}
          onPress={() => {
            void shareText().catch(() => setError("The share sheet could not be opened."))
          }}
        />
      )}
      {Platform.OS === "web" && (
        <Muted text="Image sharing is available in the iOS and Android app. This browser shares the passage as text." />
      )}
      {!!error && <Text text={error} accessibilityLiveRegion="polite" />}
      <Muted text={passage.attribution} />
    </Page>
  )
}
const styles = StyleSheet.create({
  background: { gap: 32, minHeight: 480, padding: 32, paddingBottom: 88 },
  card: { borderRadius: 8, overflow: "hidden", width: "100%" },
  ivory: { backgroundColor: CARD_COLORS.ivory },
  longQuote: { fontSize: 20, lineHeight: 31 },
  plum: { backgroundColor: CARD_COLORS.plum },
  quote: { fontFamily: "loraRegular" },
  reference: { gap: 4, marginTop: 12 },
  shortQuote: { fontSize: 26, lineHeight: 39 },
  wordmark: { fontSize: 11, letterSpacing: 5 },
})
