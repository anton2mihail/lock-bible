import { useMemo, useState } from "react"
import { Pressable, View } from "react-native"
import { useLocalSearchParams, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { companionStyles as s, Muted, Page } from "@/components/companion/Companion"
import { Text } from "@/components/Text"
import { getTranslation } from "@/services/bible/translations"
import { referenceTarget } from "@/services/companion/passage"
import { useReaderTypography } from "@/theme/useReaderTypography"

export function PassageScreen() {
  const { reference } = useLocalSearchParams<{ reference?: string }>(),
    router = useRouter()
  const passageStyle = useReaderTypography()
  const target = useMemo(() => referenceTarget(reference ?? ""), [reference])
  const [chapterNumber, setChapterNumber] = useState(() => Number(target?.chapter ?? 1))
  const bible = getTranslation("web-ce"),
    book = target ? bible.loadBook(target.book) : undefined
  const chapter = book?.chapters.find((c) => c.c === chapterNumber)
  if (!book || !chapter)
    return (
      <Page title="Passage unavailable">
        <Muted text="This reference could not be opened. You can find the passage using Bible search." />
        <Button text="Search the Bible" onPress={() => router.push("/search")} />
      </Page>
    )
  return (
    <Page
      key={chapterNumber}
      title={`${book.name} ${chapterNumber}`}
      eyebrow="Scripture in context"
      subtitle={`Reading reference: ${reference}`}
    >
      <Muted text="WEB-CE · Complete chapter. References with lettered verse portions or multiple chapters are shown in context; use Next chapter to continue." />
      <Muted text="Tap a verse to pray with it." />
      {chapter.verses.map((verse) => (
        <Pressable
          key={verse.n}
          accessibilityRole="button"
          accessibilityLabel={`Pray with verse ${verse.n}. ${verse.t}`}
          onPress={() =>
            router.push({
              pathname: "/lectio",
              params: {
                book: book.code,
                chapter: String(chapterNumber),
                startVerse: verse.n,
                translation: "web-ce",
              },
            })
          }
        >
          <Text style={passageStyle}>
            <Text text={`${verse.n}  `} size="xs" style={{ lineHeight: passageStyle.lineHeight }} />
            {verse.t}
          </Text>
        </Pressable>
      ))}
      <View style={s.spread}>
        <Button
          text="Previous chapter"
          disabled={chapterNumber <= 1}
          onPress={() => setChapterNumber((n) => n - 1)}
        />
        <Button
          text="Next chapter"
          disabled={chapterNumber >= book.chapters.length}
          onPress={() => setChapterNumber((n) => n + 1)}
        />
      </View>
      <Muted text={bible.meta.attribution} />
    </Page>
  )
}
