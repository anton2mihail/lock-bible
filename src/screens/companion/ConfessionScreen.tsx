import { useCallback, useEffect, useState } from "react"
import { AppState, Linking, View } from "react-native"
import { useFocusEffect, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import {
  companionStyles as s,
  Muted,
  Page,
  Panel,
  SectionTitle,
} from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import { TextField } from "@/components/TextField"
import { CONFESSION_SOURCE, CONFESSION_STEPS, EXAMINATION } from "@/services/companion/confession"
import { ACT_OF_CONTRITION } from "@/services/companion/prayers"

export function ConfessionScreen() {
  const router = useRouter(),
    [index, setIndex] = useState(0),
    [notes, setNotes] = useState(""),
    [notice, setNotice] = useState("")
  const clear = useCallback(() => setNotes(""), [])
  useFocusEffect(useCallback(() => () => clear(), [clear]))
  useEffect(() => {
    const listener = AppState.addEventListener("change", (state) => {
      if (state !== "active") {
        clear()
        setNotice("Your private notes were cleared when you left the app.")
      }
    })
    return () => listener.remove()
  }, [clear])
  const step = CONFESSION_STEPS[index]
  return (
    <Page
      key={index}
      title={step.title}
      eyebrow={`Prepare for Confession / ${index + 1} of ${CONFESSION_STEPS.length}`}
    >
      <Text text={step.body} style={s.body} />
      {index === 0 && (
        <>
          <Panel>
            <SectionTitle
              title="An examination of conscience"
              detail="Read slowly, in the light of God’s love. You can use these prompts without writing anything."
            />
            {EXAMINATION.map((section) => (
              <View key={section.title} style={s.smallGap}>
                <Text text={section.title} preset="subheading" />
                <Muted text={section.scripture} />
                {section.questions.map((question) => (
                  <Text key={question} text={question} style={s.body} />
                ))}
              </View>
            ))}
          </Panel>
          <TextField
            label="Private notes, if helpful"
            accessibilityLabel="Temporary confession notes"
            placeholder="These words will not be saved…"
            value={notes}
            onChangeText={setNotes}
            multiline
            autoCorrect={false}
            autoComplete="off"
            spellCheck={false}
            style={s.field}
          />
          <Muted text="These notes are never saved by John 1:1. They are cleared when you leave this guide or put the app in the background." />
          {!!notes && <Button text="Clear notes now" onPress={clear} />}
        </>
      )}
      {index === 2 && !!notes && (
        <Panel>
          <SectionTitle title="Your private notes" />
          <Text text={notes} style={s.body} />
        </Panel>
      )}
      {index === 3 && (
        <Panel>
          <SectionTitle title="Act of Contrition" />
          <Text text={ACT_OF_CONTRITION} style={s.serif} selectable />
        </Panel>
      )}
      <Button
        text={index === CONFESSION_STEPS.length - 1 ? "Finish & clear notes" : "Continue"}
        preset="reversed"
        onPress={() => {
          if (index === CONFESSION_STEPS.length - 1) {
            clear()
            if (router.canGoBack()) router.back()
            else router.replace("/")
          } else setIndex((i) => i + 1)
        }}
      />
      {index > 0 && <Button text="Previous" onPress={() => setIndex((i) => i - 1)} />}
      {!!notice && <Text text={notice} accessibilityLiveRegion="polite" />}
      <Muted text="Original preparation prompts, informed by the Ten Commandments, the Beatitudes, and USCCB guidance. Your priest can help with questions about your circumstances." />
      <Button
        text="USCCB preparation resources ↗"
        onPress={() => {
          clear()
          void Linking.openURL(CONFESSION_SOURCE).catch(() =>
            setNotice("The resources could not be opened. Please try again when connected."),
          )
        }}
      />
    </Page>
  )
}
