import { useEffect, useState } from "react"
import { Linking, View } from "react-native"
import { useLocalSearchParams, useRouter } from "expo-router"

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
import { TextField } from "@/components/TextField"
import {
  addDays,
  CALENDAR_LABEL,
  celebrationFor,
  dateKey,
  parseDate,
  readingsFor,
  readingsUrl,
  SEASON_NAMES,
  seasonFor,
  upcomingSunday,
} from "@/services/companion/calendar"
import { loadReflection, saveReflection } from "@/services/companion/preferences"

export function ReadingsScreen({ sunday = false }: { sunday?: boolean }) {
  const params = useLocalSearchParams<{ date?: string }>(),
    router = useRouter()
  const [day, setDay] = useState(() =>
    parseDate(params.date, sunday ? upcomingSunday() : new Date()),
  )
  const key = dateKey(day),
    entry = readingsFor(day),
    celebration = celebrationFor(day),
    season = seasonFor(day)
  const [reflection, setReflection] = useState(() => loadReflection(key)),
    [feedback, setFeedback] = useState("")
  useEffect(() => {
    const next = parseDate(params.date, sunday ? upcomingSunday() : new Date())
    setDay(next)
    setReflection(loadReflection(dateKey(next)))
    setFeedback("")
  }, [params.date, sunday])
  const move = (offset: number) => {
    const next = addDays(day, offset)
    setDay(next)
    setReflection(loadReflection(dateKey(next)))
    setFeedback("")
  }
  const persist = () =>
    setFeedback(
      saveReflection(key, reflection)
        ? "Reflection saved on this device."
        : "Could not save. Please try again.",
    )
  const openOfficial = () => {
    void Linking.openURL(readingsUrl(day)).catch(() =>
      setFeedback("The readings website could not be opened. Please try again when connected."),
    )
  }
  return (
    <Page
      key={key}
      title={sunday ? "Come ready for Sunday" : "Today’s readings"}
      eyebrow={`${CALENDAR_LABEL} / ${SEASON_NAMES[season]}`}
    >
      <View style={s.spread}>
        <Button text="Previous" onPress={() => move(sunday ? -7 : -1)} />
        <Text
          text={day.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
            year: "numeric",
          })}
          weight="medium"
        />
        <Button text="Next" onPress={() => move(sunday ? 7 : 1)} />
      </View>
      <ArtCard
        title={entry?.title ?? celebration?.title ?? SEASON_NAMES[season]}
        subtitle={day.toLocaleDateString("en-US", {
          weekday: "long",
          month: "long",
          day: "numeric",
        })}
        image={art[season]}
        onPress={openOfficial}
      />
      <Muted text="USCCB reading selections. Transferred feasts and optional celebrations may differ at your parish." />
      <Panel>
        <SectionTitle
          title="Listen to the Word"
          detail="Open each reading in its biblical context. Scripture uses the offline WEB-CE edition; wording and verse divisions may differ from those proclaimed at Mass."
        />
        {entry ? (
          entry.readings.map((reading, index) => (
            <ActionRow
              key={`${reading.label}-${index}`}
              title={reading.reference}
              subtitle={reading.label}
              onPress={() =>
                router.push({ pathname: "/passage", params: { reference: reading.reference } })
              }
            />
          ))
        ) : (
          <Muted text="Reading references for this date aren’t in your offline library. Open the official readings when you’re connected." />
        )}
        <Button text="Official readings ↗" onPress={openOfficial} />
      </Panel>
      {sunday && (
        <>
          <Panel>
            <SectionTitle title="Read them together" />
            <Text
              text={connectionFor(
                entry?.readings.find((r) => r.label === "Gospel")?.reference ?? "",
              )}
              style={s.body}
            />
            <Muted text="A reading guide from John 1:1" />
          </Panel>
          <Panel>
            <SectionTitle
              title="Before Mass"
              detail="What word, question, or intention will you bring with you?"
            />
            <TextField
              accessibilityLabel="Before Mass reflection"
              placeholder="Something I want to carry into Mass…"
              value={reflection.before}
              onChangeText={(before) => {
                setReflection({ ...reflection, before })
                setFeedback("")
              }}
              multiline
              style={s.field}
            />
            <SectionTitle
              title="After Mass"
              detail="Return to the same Sunday to remember what you heard and how you want to respond."
            />
            <TextField
              accessibilityLabel="After Mass reflection"
              placeholder="A word to remember. A step to take…"
              value={reflection.after}
              onChangeText={(after) => {
                setReflection({ ...reflection, after })
                setFeedback("")
              }}
              multiline
              style={s.field}
            />
            <Button text="Save reflection" preset="reversed" onPress={persist} />
            <Muted text="Saved only when you choose. Reflections are kept on this device." />
          </Panel>
        </>
      )}
      {!!feedback && <Text text={feedback} accessibilityLiveRegion="polite" />}
    </Page>
  )
}
function connectionFor(gospel: string): string {
  if (/Matthew 18:21/.test(gospel))
    return "Sirach asks us to set anger aside, and Jesus’ parable presses the question further: can we receive mercy while refusing it to another? Paul reminds us that we belong to the Lord. Read with this question in mind: where is God inviting me to let mercy shape a relationship?"
  if (/Luke 15:/.test(gospel))
    return "Watch who is lost, who searches, and who rejoices in this Gospel. Then return to the first reading and the psalm: what do they reveal about God’s patience and mercy? Let your prayer include someone who longs for a welcome home."
  if (/John 6:/.test(gospel))
    return "Listen for what Jesus says about hunger, life, and the gift of himself. Read the first reading beside the Gospel and notice images of food or God’s provision. Bring your own hunger to Christ as you prepare for the Eucharist."
  return "Begin with the Gospel: what does Jesus reveal about God, and what response does he invite? Read the first reading alongside it and look for a shared image, promise, or question. Let the psalm become your reply in prayer. Then notice how the second reading speaks to the way a Christian community lives. You do not need to force every reading into a single theme."
}
