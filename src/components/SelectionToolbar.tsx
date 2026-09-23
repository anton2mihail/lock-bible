import { ComponentProps } from "react"
import { TextStyle, TouchableOpacity, useWindowDimensions, View, ViewStyle } from "react-native"
import { Feather } from "@expo/vector-icons"

import { passageReference, type HighlightColor, type PassageSelection } from "@/services/library"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"
import { useReadingColumn } from "@/theme/useReaderTypography"

import { HIGHLIGHT_FILLS } from "./ChapterText"
import { Text } from "./Text"

const HIGHLIGHT_COLORS = Object.keys(HIGHLIGHT_FILLS) as HighlightColor[]

/**
 * The bar's labels stop growing here. It sits over the chapter, and uncapped
 * at the largest text sizes it grew taller than the screen, hiding both the
 * verses it acts on and its own last actions.
 */
const TOOLBAR_TEXT_SCALE = 1.5

export interface SelectionToolbarProps {
  passage: PassageSelection
  /** The highlight every selected verse shares, if they share one. */
  highlightColor?: HighlightColor
  /** Whether any selected verse is highlighted, so there is something to remove. */
  highlighted: boolean
  bookmarked: boolean
  /** The latest action's result, shown under the actions. */
  feedback: string
  onClose: () => void
  onHighlight: (color: HighlightColor) => void | Promise<void>
  onClearHighlight: () => void | Promise<void>
  onBookmark: () => void | Promise<void>
  onNote: () => void
  onCopy: () => void | Promise<void>
  onShare: () => void | Promise<void>
  onPray: () => void
  onCard: () => void
}

interface Action {
  /** Spoken with the reference, e.g. "Bookmark John 3:16". */
  name: string
  label: string
  icon: ComponentProps<typeof Feather>["name"]
  onPress: () => void | Promise<void>
  active?: boolean
}

/**
 * What can be done with the selected verses: highlight colours inline, then
 * the actions, each an icon with a short label so none breaks mid-word.
 */
export function SelectionToolbar({
  passage,
  highlightColor,
  highlighted,
  bookmarked,
  feedback,
  onClose,
  onHighlight,
  onClearHighlight,
  onBookmark,
  onNote,
  onCopy,
  onShare,
  onPray,
  onCard,
}: SelectionToolbarProps) {
  const { themed, theme } = useAppTheme()
  const { fontScale } = useWindowDimensions()
  // On an iPad the bar spans the screen but its controls line up with the text.
  const readingColumn = useReadingColumn()
  const reference = passageReference(
    passage.bookName,
    passage.chapter,
    passage.startVerse,
    passage.endVerse,
  )

  const actions: Action[] = [
    {
      name: "Bookmark",
      // Short enough to fit six across on the smallest phones.
      label: bookmarked ? "Saved" : "Bookmark",
      icon: "bookmark",
      onPress: onBookmark,
      active: bookmarked,
    },
    { name: "Note", label: "Note", icon: "edit-3", onPress: onNote },
    { name: "Copy", label: "Copy", icon: "copy", onPress: onCopy },
    { name: "Share", label: "Share", icon: "share", onPress: onShare },
    { name: "Pray", label: "Pray", icon: "heart", onPress: onPray },
    { name: "Create card", label: "Card", icon: "image", onPress: onCard },
  ]
  // Six across fit a phone at the default text size; larger text wraps them
  // onto a second row rather than squeezing the labels.
  const actionBasis = 56 * Math.min(Math.max(1, fontScale), TOOLBAR_TEXT_SCALE)

  return (
    <View style={themed($toolbar)} accessibilityRole="toolbar">
      <View style={[themed($toolbarContent), readingColumn]}>
        <View style={themed($summary)}>
          <Text
            text={reference}
            size="xs"
            weight="semiBold"
            maxFontSizeMultiplier={TOOLBAR_TEXT_SCALE}
            style={themed($reference)}
          />
          <TouchableOpacity
            onPress={onClose}
            style={themed($close)}
            accessibilityRole="button"
            accessibilityLabel="Clear passage selection"
          >
            <Feather name="x" size={20} color={theme.colors.text} />
          </TouchableOpacity>
        </View>

        <View style={themed($swatches)}>
          {HIGHLIGHT_COLORS.map((color) => {
            const active = color === highlightColor
            return (
              <TouchableOpacity
                key={color}
                onPress={() => (active ? onClearHighlight() : onHighlight(color))}
                style={themed($swatchTarget)}
                accessibilityRole="button"
                accessibilityState={{ selected: active }}
                accessibilityLabel={
                  active ? `Remove ${color} highlight` : `Apply ${color} highlight`
                }
              >
                <View
                  style={[
                    themed($swatch),
                    // The light fills read as colours on either background.
                    { backgroundColor: HIGHLIGHT_FILLS[color].light },
                    active && themed($swatchActive),
                  ]}
                >
                  {active && (
                    <Feather name="check" size={16} color={theme.colors.palette.neutral800} />
                  )}
                </View>
              </TouchableOpacity>
            )
          })}
          {highlighted && !highlightColor && (
            <TouchableOpacity
              onPress={onClearHighlight}
              style={themed($swatchTarget)}
              accessibilityRole="button"
              accessibilityLabel="Remove highlight"
            >
              <View style={themed([$swatch, $clearSwatch])}>
                <Feather name="slash" size={16} color={theme.colors.textDim} />
              </View>
            </TouchableOpacity>
          )}
        </View>

        <View style={themed($actions)}>
          {actions.map((action) => (
            <TouchableOpacity
              key={action.name}
              onPress={action.onPress}
              style={[themed($action), { flexBasis: actionBasis }]}
              accessibilityRole="button"
              accessibilityLabel={`${action.name} ${reference}`}
              accessibilityState={
                action.active === undefined ? undefined : { selected: action.active }
              }
            >
              <View style={themed([$actionIcon, action.active && $actionIconActive])}>
                <Feather
                  name={action.icon}
                  size={20}
                  color={action.active ? theme.colors.palette.neutral100 : theme.colors.text}
                />
              </View>
              <Text
                text={action.label}
                size="xxs"
                weight="medium"
                numberOfLines={1}
                adjustsFontSizeToFit
                minimumFontScale={0.8}
                maxFontSizeMultiplier={TOOLBAR_TEXT_SCALE}
                style={themed([$actionLabel, action.active && $actionLabelActive])}
              />
            </TouchableOpacity>
          ))}
        </View>

        {!!feedback && (
          <Text
            text={feedback}
            size="xxs"
            maxFontSizeMultiplier={TOOLBAR_TEXT_SCALE}
            style={themed($feedback)}
          />
        )}
      </View>
    </View>
  )
}

const $toolbar: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderTopWidth: 1,
  borderTopColor: colors.border,
  paddingHorizontal: spacing.sm,
  paddingTop: spacing.xxs,
  paddingBottom: spacing.xs,
})

const $toolbarContent: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xxs })

const $summary: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  paddingLeft: spacing.xs,
})

const $reference: ThemedStyle<TextStyle> = () => ({ flexShrink: 1 })

const $close: ThemedStyle<ViewStyle> = () => ({
  width: 44,
  height: 44,
  alignItems: "center",
  justifyContent: "center",
})

const $swatches: ThemedStyle<ViewStyle> = () => ({
  flexDirection: "row",
  flexWrap: "wrap",
})

const $swatchTarget: ThemedStyle<ViewStyle> = () => ({
  width: 48,
  height: 44,
  alignItems: "center",
  justifyContent: "center",
})

const $swatch: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 30,
  height: 30,
  borderRadius: 15,
  alignItems: "center",
  justifyContent: "center",
  borderWidth: 1,
  borderColor: colors.border,
})

const $swatchActive: ThemedStyle<ViewStyle> = ({ colors }) => ({
  borderWidth: 2,
  borderColor: colors.tint,
})

const $clearSwatch: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.background,
})

const $actions: ThemedStyle<ViewStyle> = () => ({
  flexDirection: "row",
  flexWrap: "wrap",
})

const $action: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexGrow: 1,
  minHeight: 56,
  alignItems: "center",
  justifyContent: "center",
  gap: spacing.xxxs,
  paddingVertical: spacing.xxxs,
})

const $actionIcon: ThemedStyle<ViewStyle> = () => ({
  width: 36,
  height: 36,
  borderRadius: 18,
  alignItems: "center",
  justifyContent: "center",
})

const $actionIconActive: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
})

const $actionLabel: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.text,
  textAlign: "center",
})

const $actionLabelActive: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
})

const $feedback: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textAlign: "center",
})
