import { useCallback, useState } from "react"
import { Image, View } from "react-native"
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import {
  ActionRow,
  companionStyles as s,
  Muted,
  Page,
  SectionTitle,
} from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import { TextField } from "@/components/TextField"
import { prayerArt } from "@/services/companion/artwork"
import { favoritePrayers, toggleFavoritePrayer } from "@/services/companion/preferences"
import { getPrayer, PRAYERS } from "@/services/companion/prayers"

export function PrayerScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>(),
    router = useRouter(),
    prayer = getPrayer(id)
  const [favorites, setFavorites] = useState(favoritePrayers),
    [query, setQuery] = useState(""),
    [feedback, setFeedback] = useState("")
  useFocusEffect(useCallback(() => setFavorites(favoritePrayers()), []))
  if (id && !prayer)
    return (
      <Page title="Prayer not found">
        <Muted text="This prayer is not in the library." />
        <Button text="Prayer library" onPress={() => router.replace("/prayers")} />
      </Page>
    )
  if (prayer)
    return (
      <Page title={prayer.title} eyebrow={prayer.category} subtitle={prayer.subtitle}>
        <Image source={prayerArt(prayer.id)} style={s.heroImage} accessible={false} />
        <Text text={prayer.text} style={s.serif} selectable />
        {prayer.id === "angelus" && (
          <ActionRow
            title="Hail Mary"
            subtitle="Open the complete prayer"
            onPress={() => router.push({ pathname: "/prayer", params: { id: "hail-mary" } })}
          />
        )}
        <Button
          text={favorites.includes(prayer.id) ? "Remove from favorites" : "Keep in favorites"}
          onPress={() => {
            if (toggleFavoritePrayer(prayer.id)) {
              setFavorites(favoritePrayers())
              setFeedback("")
            } else setFeedback("Could not update favorites. Please try again.")
          }}
        />
        {!!feedback && <Text text={feedback} accessibilityLiveRegion="polite" />}
        <Muted text={prayer.source} />
      </Page>
    )
  const results = PRAYERS.filter((p) =>
    `${p.title} ${p.subtitle} ${p.category}`.toLowerCase().includes(query.trim().toLowerCase()),
  )
  const open = (prayerId: string) => router.push({ pathname: "/prayer", params: { id: prayerId } })
  return (
    <Page
      title="Prayer for every day"
      eyebrow="Keep a little quiet"
      subtitle="Familiar words for ordinary moments, and the difficult ones too."
    >
      <TextField
        accessibilityLabel="Search everyday prayers"
        placeholder="Find a prayer…"
        value={query}
        onChangeText={setQuery}
      />
      {!query && favorites.length > 0 && (
        <View>
          <SectionTitle title="Kept close" />
          {PRAYERS.filter((p) => favorites.includes(p.id)).map((p) => (
            <ActionRow
              key={p.id}
              title={p.title}
              subtitle={p.subtitle}
              icon="heart"
              onPress={() => open(p.id)}
            />
          ))}
        </View>
      )}
      {["Daily rhythm", "Traditional prayers", "In times of need"].map((category) => {
        const items = results.filter((p) => p.category === category)
        return items.length ? (
          <View key={category}>
            <SectionTitle title={category} />
            {items.map((p) => (
              <ActionRow
                key={p.id}
                title={p.title}
                subtitle={p.subtitle}
                onPress={() => open(p.id)}
              />
            ))}
          </View>
        ) : null
      })}
      {!results.length && <Muted text="No prayers found. Try morning, Mary, or suffering." />}
    </Page>
  )
}
