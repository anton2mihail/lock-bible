import { useLocalSearchParams } from "expo-router"

import { ChapterCommentaryScreen } from "@/screens/works/chapter-commentary-screen"

export default function ChapterCommentaryRoute() {
  const { book, chapter } = useLocalSearchParams<{ book?: string; chapter?: string }>()
  return <ChapterCommentaryScreen book={book} chapter={chapter} />
}
