import {
  Modal,
  ModalProps,
  Pressable,
  ScrollView,
  TextStyle,
  TouchableOpacity,
  useWindowDimensions,
  View,
  ViewStyle,
} from "react-native"
import { useSafeAreaInsets } from "react-native-safe-area-context"

import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

import { ReadingSettings } from "./ReadingSettings"
import { Text } from "./Text"

// iOS shows a modal in portrait only unless told otherwise, which would turn
// an iPad that is being held in landscape.
const ALL_ORIENTATIONS: ModalProps["supportedOrientations"] = [
  "portrait",
  "portrait-upside-down",
  "landscape-left",
  "landscape-right",
]

export interface TextSettingsSheetProps {
  visible: boolean
  onClose: () => void
}

/**
 * The reader's Aa sheet. It covers only the bottom of the screen and leaves
 * the chapter undimmed above, so each choice shows in the text as it is made.
 */
export function TextSettingsSheet({ visible, onClose }: TextSettingsSheetProps) {
  const { themed, theme } = useAppTheme()
  const insets = useSafeAreaInsets()
  const { height } = useWindowDimensions()

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
      supportedOrientations={ALL_ORIENTATIONS}
      statusBarTranslucent
      navigationBarTranslucent
    >
      <View style={$root}>
        {/* Tapping the chapter closes the sheet; VoiceOver users have Done and
            the escape gesture instead of an unlabelled target. */}
        <Pressable style={$dismissArea} onPress={onClose} accessible={false} />
        <View
          style={themed([$sheet, { paddingBottom: insets.bottom + theme.spacing.sm }])}
          onAccessibilityEscape={onClose}
          testID="text-settings-sheet"
        >
          <View style={themed($titleRow)}>
            {/* Wraps and stops growing well before the largest text sizes, so
                Done always stays on screen beside it. */}
            <Text
              text="Text settings"
              preset="subheading"
              accessibilityRole="header"
              maxFontSizeMultiplier={1.6}
              style={$title}
            />
            <TouchableOpacity
              onPress={onClose}
              style={themed($doneButton)}
              accessibilityRole="button"
              accessibilityLabel="Done"
            >
              <Text text="Done" weight="semiBold" style={themed($doneText)} />
            </TouchableOpacity>
          </View>
          {/* Half the screen stays on the chapter, so a change shows across
              several lines of Scripture; the less-used options scroll. */}
          <ScrollView style={{ maxHeight: height * 0.42 }} bounces={false}>
            <ReadingSettings />
          </ScrollView>
        </View>
      </View>
    </Modal>
  )
}

const $root: ViewStyle = { flex: 1, justifyContent: "flex-end" }

const $dismissArea: ViewStyle = { flex: 1 }

const $sheet: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  width: "100%",
  maxWidth: 600,
  alignSelf: "center",
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.xs,
  backgroundColor: colors.palette.neutral100,
  borderTopLeftRadius: 20,
  borderTopRightRadius: 20,
  borderWidth: 1,
  borderBottomWidth: 0,
  borderColor: colors.border,
  shadowColor: colors.palette.neutral800,
  shadowOffset: { width: 0, height: -6 },
  shadowOpacity: 0.1,
  shadowRadius: 16,
  elevation: 16,
})

const $title: TextStyle = { flexShrink: 1 }

const $titleRow: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 52,
  flexDirection: "row",
  alignItems: "center",
  justifyContent: "space-between",
  gap: spacing.sm,
})

const $doneButton: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingLeft: spacing.sm,
})

const $doneText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
