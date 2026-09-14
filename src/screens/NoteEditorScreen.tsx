import { FC, useEffect, useMemo, useState } from "react"
import { KeyboardAvoidingView, Platform, TextStyle, View, ViewStyle } from "react-native"
import { useLocalSearchParams, useRouter } from "expo-router"

import { Button } from "@/components/Button"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import { TextField } from "@/components/TextField"
import { getActiveTranslationMeta, listBooks } from "@/services/bible"
import { useLibraryDatabase } from "@/services/database"
import {
  deleteNote,
  getNote,
  passageReference,
  saveNote,
  selectionFromReference,
} from "@/services/library"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

export const NoteEditorScreen: FC = function NoteEditorScreen() {
  const params = useLocalSearchParams<{
    book?: string
    chapter?: string
    startVerse?: string
    endVerse?: string
  }>()
  const database = useLibraryDatabase()
  const router = useRouter()
  const { themed } = useAppTheme()
  const [noteText, setNoteText] = useState("")
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState("")

  const selection = useMemo(() => {
    const book = listBooks().find((candidate) => candidate.code === params.book)
    const chapter = Number(params.chapter)
    if (!book || !Number.isInteger(chapter) || !params.startVerse) return null
    return selectionFromReference(
      getActiveTranslationMeta().id,
      book,
      chapter,
      params.startVerse,
      params.endVerse ?? params.startVerse,
    )
  }, [params.book, params.chapter, params.endVerse, params.startVerse])

  useEffect(() => {
    if (!selection) {
      setIsLoading(false)
      return
    }
    getNote(database, selection)
      .then(setNoteText)
      .catch(() => setError("This note could not be opened. Return to the reader and try again."))
      .finally(() => setIsLoading(false))
  }, [database, selection])

  const reference = selection
    ? passageReference(
        selection.bookName,
        selection.chapter,
        selection.startVerse,
        selection.endVerse,
      )
    : "Note"

  const save = async () => {
    if (!selection) return
    setIsSaving(true)
    setError("")
    try {
      await saveNote(database, selection, noteText)
      router.back()
    } catch {
      setError("Your note could not be saved. It is still visible here so you can try again.")
    } finally {
      setIsSaving(false)
    }
  }

  const remove = async () => {
    if (!selection) return
    setIsSaving(true)
    try {
      await deleteNote(database, selection)
      router.back()
    } catch {
      setError("Your note could not be deleted. Try again.")
      setIsSaving(false)
    }
  }

  if (!selection && !isLoading) {
    return (
      <Screen
        preset="fixed"
        safeAreaEdges={["top", "bottom"]}
        contentContainerStyle={themed($errorScreen)}
      >
        <Text text="Passage not found" preset="heading" />
        <Text text="Return to the reader and select the passage again." />
        <Button text="Return" onPress={() => router.back()} />
      </Screen>
    )
  }

  return (
    <KeyboardAvoidingView
      style={themed($flex)}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <Screen
        preset="fixed"
        safeAreaEdges={["top", "bottom"]}
        contentContainerStyle={themed($screen)}
      >
        <View style={themed($header)}>
          <Button
            text="Cancel"
            preset="reversed"
            onPress={() => router.back()}
            style={themed($headerButton)}
          />
          <Text text={reference} weight="semiBold" style={themed($headerTitle)} numberOfLines={1} />
          <Button
            text={isSaving ? "Saving…" : "Save"}
            onPress={save}
            disabled={!selection || isSaving || isLoading}
            style={themed($headerButton)}
          />
        </View>
        {selection && (
          <Text text={selection.scriptureText} style={themed($scripture)} numberOfLines={8} />
        )}
        <TextField
          value={noteText}
          onChangeText={setNoteText}
          multiline
          autoFocus={!isLoading}
          textAlignVertical="top"
          placeholder="Write a private note…"
          style={themed($noteInput)}
          containerStyle={themed($noteInputContainer)}
          inputWrapperStyle={themed($noteInputWrapper)}
          accessibilityLabel={`Note for ${reference}`}
          testID="note-editor-input"
        />
        {!!error && (
          <Text
            text={error}
            size="xs"
            style={themed($errorText)}
            accessibilityLiveRegion="assertive"
          />
        )}
        {!!noteText.trim() && (
          <Button
            text="Delete note"
            onPress={remove}
            disabled={isSaving}
            style={themed($deleteButton)}
            textStyle={themed($deleteText)}
          />
        )}
      </Screen>
    </KeyboardAvoidingView>
  )
}

const $flex: ThemedStyle<ViewStyle> = () => ({ flex: 1 })
const $screen: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  paddingHorizontal: spacing.lg,
})
const $header: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  gap: spacing.xs,
  paddingVertical: spacing.sm,
})
const $headerButton: ThemedStyle<ViewStyle> = () => ({ minHeight: 44, minWidth: 76 })
const $headerTitle: ThemedStyle<TextStyle> = () => ({ flex: 1, textAlign: "center" })
const $scripture: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.text,
  fontFamily: "Georgia",
  fontSize: 17,
  lineHeight: 27,
  paddingVertical: spacing.lg,
  borderBottomWidth: 1,
  borderBottomColor: colors.separator,
})
const $noteInput: ThemedStyle<TextStyle> = ({ colors, typography, spacing }) => ({
  flex: 1,
  color: colors.text,
  fontFamily: typography.primary.normal,
  fontSize: 18,
  lineHeight: 28,
  paddingTop: spacing.lg,
  paddingHorizontal: 0,
})
const $noteInputContainer: ThemedStyle<ViewStyle> = () => ({ flex: 1 })
const $noteInputWrapper: ThemedStyle<ViewStyle> = () => ({
  flex: 1,
  borderWidth: 0,
  backgroundColor: "transparent",
})
const $errorText: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.error,
  paddingVertical: spacing.xs,
})
const $deleteButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  marginVertical: spacing.sm,
  borderWidth: 0,
  backgroundColor: "transparent",
})
const $deleteText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.error })
const $errorScreen: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flex: 1,
  justifyContent: "center",
  padding: spacing.lg,
  gap: spacing.md,
})
