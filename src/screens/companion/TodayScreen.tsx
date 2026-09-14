import { useCallback, useState } from "react"
import { View } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import {
  ActionRow,
  art,
  ArtCard,
  companionStyles as s,
  Muted,
  Page,
  Panel,
  SectionTitle,
} from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import { getActiveTranslationMeta, getCurrentVerse } from "@/services/bible"
import {
  CALENDAR_LABEL,
  celebrationFor,
  dateKey,
  readingsFor,
  SEASON_NAMES,
  seasonFor,
  upcomingSunday,
} from "@/services/companion/calendar"
import { loadNovenaProgress, novenas } from "@/services/novena"
import { getSuggestedRosaryMysterySet } from "@/services/rosary"

export function TodayScreen() {
  const router = useRouter(),
    [now, setNow] = useState(() => new Date())
  useFocusEffect(
    useCallback(() => {
      setNow(new Date())
      const timer = setInterval(() => setNow(new Date()), 60000)
      return () => clearInterval(timer)
    }, []),
  )
  const season = seasonFor(now),
    entry = readingsFor(now),
    celebration = celebrationFor(now),
    verse = getCurrentVerse(now),
    rosary = getSuggestedRosaryMysterySet(now)
  const ongoing = novenas
    .map((novena) => ({ novena, progress: loadNovenaProgress(novena.id) }))
    .filter(
      ({ progress }) =>
        (progress.completedDays.length > 0 || progress.intention.trim()) &&
        progress.completedDays.length < 9,
    )
  const date = now.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })
  return (
    <Page
      title="A little closer to God."
      eyebrow={`John 1:1  /  ${date}`}
      subtitle="Scripture for your day. Space for your soul."
      back={false}
    >
      <ArtCard
        title={entry?.title ?? celebration?.title ?? SEASON_NAMES[season]}
        subtitle={`${SEASON_NAMES[season]} · Today’s readings`}
        image={art[season]}
        onPress={() => router.push({ pathname: "/daily", params: { date: dateKey(now) } })}
      />
      <Muted text={CALENDAR_LABEL} />
      <View style={s.gap}>
        <SectionTitle title="Make room for prayer" />
        <ActionRow
          title="Pray the Rosary"
          subtitle={rosary.title}
          image={art.mary}
          onPress={() =>
            router.push({ pathname: "/pray/rosary-guide", params: { set: rosary.id } })
          }
        />
        <ActionRow
          title={now.getHours() < 17 ? "A morning offering" : "An evening examen"}
          subtitle={
            now.getHours() < 17
              ? "Offer this day, just as it is"
              : "Look back with gratitude and honesty"
          }
          image={art.prayer}
          onPress={() =>
            router.push({
              pathname: "/prayer",
              params: { id: now.getHours() < 17 ? "morning" : "evening" },
            })
          }
        />
        {ongoing.map(({ novena, progress }) => (
          <ActionRow
            key={novena.id}
            title={novena.title}
            subtitle={`Continue with day ${Array.from({ length: 9 }, (_, i) => i + 1).find((day) => !progress.completedDays.includes(day)) ?? 9}`}
            onPress={() => router.push({ pathname: "/pray/[id]", params: { id: novena.id } })}
          />
        ))}
      </View>
      {verse && (
        <Panel>
          <Text text="A WORD TO CARRY WITH YOU" style={s.eyebrow} />
          <Text text={verse.text} style={s.serif} selectable />
          <Muted text={`${verse.ref} · ${getActiveTranslationMeta().abbreviation}`} />
          <Button
            text="Pray with this passage"
            preset="reversed"
            onPress={() =>
              router.push({
                pathname: "/lectio",
                params: {
                  book: verse.book,
                  chapter: String(verse.chapter),
                  startVerse: verse.verse,
                  translation: getActiveTranslationMeta().id,
                },
              })
            }
          />
          <ActionRow
            title="Verse & lock screen widget"
            subtitle="Read in context, share, or set up your widget"
            onPress={() => router.push("/verse")}
          />
        </Panel>
      )}
      <ArtCard
        title="Come ready for Sunday"
        subtitle={`${upcomingSunday(now).toLocaleDateString("en-US", { month: "long", day: "numeric" })} · Read, reflect, return`}
        image={art.scripture}
        onPress={() => router.push("/sunday")}
      />
      <View>
        <ActionRow
          title="Explore the Catholic faith"
          subtitle="Scripture alongside the Catechism"
          onPress={() => router.push("/learn")}
        />
        <ActionRow
          title="Prepare for Confession"
          subtitle="A gentle guide to returning to mercy"
          onPress={() => router.push("/confession")}
        />
      </View>
      <Muted text="Your Bible, prayers, and reflections stay close. No account needed." />
    </Page>
  )
}
