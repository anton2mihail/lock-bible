import { useState } from "react"
import { Image, Linking } from "react-native"
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
import { getTeaching, TEACHINGS } from "@/services/companion/teaching"

export function TeachingScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>(),
    router = useRouter(),
    teaching = getTeaching(id),
    [error, setError] = useState("")
  if (id && !teaching)
    return (
      <Page title="Topic not found">
        <Button text="Explore the faith" onPress={() => router.replace("/learn")} />
      </Page>
    )
  if (!teaching)
    return (
      <Page
        title="Faith, rooted in Scripture"
        eyebrow="Explore & understand"
        subtitle="Small introductions to Catholic belief, with places to read more."
      >
        {TEACHINGS.map((item) => (
          <ArtCard
            key={item.id}
            title={item.title}
            subtitle={item.subtitle}
            image={art[item.artwork]}
            onPress={() => router.push({ pathname: "/teaching", params: { id: item.id } })}
          />
        ))}
      </Page>
    )
  return (
    <Page
      title={teaching.title}
      eyebrow="Scripture & Catholic teaching"
      subtitle={teaching.subtitle}
    >
      <Image source={art[teaching.artwork]} style={s.heroImage} accessible={false} />
      <Text text={teaching.summary} style={s.body} selectable />
      <Panel>
        <SectionTitle title="Read in Scripture" />
        {teaching.references.map((reference) => (
          <ActionRow
            key={reference}
            title={reference}
            subtitle="Open in context · WEB-CE"
            onPress={() => router.push({ pathname: "/passage", params: { reference } })}
          />
        ))}
      </Panel>
      <Panel>
        <SectionTitle title="Bring it to prayer" />
        <Text text={teaching.reflection} style={s.serif} />
      </Panel>
      <Muted
        text={`John 1:1 introduction · Based on ${teaching.catechism}. This summary is not a quotation from the Catechism.`}
      />
      <Button
        text={`Read ${teaching.catechism} ↗`}
        onPress={() => {
          void Linking.openURL(teaching.url).catch(() =>
            setError("The Catechism could not be opened. Please try again when connected."),
          )
        }}
      />
      {!!error && <Text text={error} accessibilityLiveRegion="polite" />}
    </Page>
  )
}
