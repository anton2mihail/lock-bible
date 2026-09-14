import { useEffect, useMemo, useState } from "react"
import { View } from "react-native"
import { useLocalSearchParams, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { companionStyles as s, Muted, Page, Panel } from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import { getActiveTranslationMeta, getCurrentVerse } from "@/services/bible"
import { type PassageParams, resolvePassage } from "@/services/companion/passage"

const STEPS = [
  {
    title: "Read slowly",
    name: "Lectio",
    prompt:
      "Read the passage once, then again. Notice a word or phrase that catches your attention. Let the words arrive without rushing to explain them.",
  },
  {
    title: "Stay with a word",
    name: "Meditatio",
    prompt:
      "Return to the word or phrase that stayed with you. What does it reveal about God? Where does it meet your life today? You do not need to find a perfect answer.",
  },
  {
    title: "Speak to God",
    name: "Oratio",
    prompt:
      "Respond in your own words. Offer gratitude, a question, an intention, or something difficult to say. Speak as honestly as you can.",
  },
  {
    title: "Rest in his presence",
    name: "Contemplatio",
    prompt:
      "Let the words settle. Stay quietly with God. When your attention wanders, gently return. You may use a minute of silence or remain here as long as you wish.",
  },
  {
    title: "Carry it into your day",
    name: "Live the Word",
    prompt:
      "Choose one small response: a kindness, a conversation, an apology, a moment of trust. Let this time of prayer continue in the way you live.",
  },
]
export function LectioScreen() {
  const params = useLocalSearchParams<PassageParams>(),
    router = useRouter()
  const passage = useMemo(() => {
    if (params.book)
      return resolvePassage({
        book: params.book,
        chapter: params.chapter,
        startVerse: params.startVerse,
        endVerse: params.endVerse,
        translation: params.translation,
      })
    const verse = getCurrentVerse()
    return verse
      ? resolvePassage({
          book: verse.book,
          chapter: String(verse.chapter),
          startVerse: verse.verse,
          translation: getActiveTranslationMeta().id,
        })
      : null
  }, [params.book, params.chapter, params.startVerse, params.endVerse, params.translation])
  const [index, setIndex] = useState(0),
    [deadline, setDeadline] = useState<number | null>(null),
    [seconds, setSeconds] = useState(0)
  useEffect(() => {
    if (!deadline) return undefined
    const update = () => {
      const remaining = Math.max(0, Math.ceil((deadline - Date.now()) / 1000))
      setSeconds(remaining)
      if (!remaining) setDeadline(null)
    }
    update()
    const timer = setInterval(update, 250)
    return () => clearInterval(timer)
  }, [deadline])
  if (!passage)
    return (
      <Page title="Pray with Scripture">
        <Muted text="Choose a passage in the Bible reader, then select Pray." />
        <Button text="Open the Bible" onPress={() => router.push("/read")} />
      </Page>
    )
  const step = STEPS[index]
  return (
    <Page
      key={index}
      title={step.title}
      eyebrow={`Lectio divina / ${index + 1} of ${STEPS.length}`}
      subtitle={passage.reference}
    >
      <Panel>
        <Text text={step.name} style={s.eyebrow} />
        <Text text={step.prompt} style={s.body} />
      </Panel>
      {index === 3 ? (
        <Panel>
          <Text
            text={
              deadline
                ? `${seconds}s of quiet`
                : seconds === 0
                  ? "A moment of stillness"
                  : "Rest here for a while"
            }
            style={s.serif}
          />
          <Button
            text={deadline ? "End the timer" : "Begin one quiet minute"}
            onPress={() => {
              if (deadline) {
                setDeadline(null)
                setSeconds(0)
              } else {
                setSeconds(60)
                setDeadline(Date.now() + 60000)
              }
            }}
          />
          <Muted text="No sound or vibration. Continue whenever you are ready." />
        </Panel>
      ) : null}
      <View style={s.gap}>
        <Text text={passage.text} selectable style={s.serif} />
        <Muted text={`${passage.reference} · ${passage.translation}`} />
      </View>
      <View style={s.gap}>
        <Button
          text={index === STEPS.length - 1 ? "Finish prayer" : "Continue"}
          preset="reversed"
          onPress={() => {
            setDeadline(null)
            if (index === STEPS.length - 1) {
              if (router.canGoBack()) router.back()
              else router.replace("/")
            } else setIndex((i) => i + 1)
          }}
        />
        {index > 0 && (
          <Button
            text="Previous step"
            onPress={() => {
              setDeadline(null)
              setIndex((i) => i - 1)
            }}
          />
        )}
      </View>
      <Muted text={passage.attribution} />
    </Page>
  )
}
