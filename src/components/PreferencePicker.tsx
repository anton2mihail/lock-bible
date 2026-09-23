import { TextStyle, TouchableOpacity, View, ViewStyle } from "react-native"

import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

import { Text } from "./Text"

export interface PreferencePickerProps<T extends string> {
  label: string
  value: T
  options: readonly { value: T; label: string }[]
  onSelect: (value: T) => void
  hint?: string
  topSeparator?: boolean
}

/** A labelled row of choices, one of which is always selected. */
export function PreferencePicker<T extends string>({
  label,
  value,
  options,
  onSelect,
  hint,
  topSeparator,
}: PreferencePickerProps<T>) {
  const { themed } = useAppTheme()
  return (
    <View style={themed([$preference, topSeparator && $preferenceSeparator])}>
      <Text text={label} size="xs" weight="medium" />
      <View style={themed($preferenceOptions)} accessibilityRole="radiogroup">
        {options.map((option) => {
          const selected = option.value === value
          return (
            <TouchableOpacity
              key={option.value}
              onPress={() => onSelect(option.value)}
              style={themed([$preferenceOption, selected && $preferenceOptionSelected])}
              accessibilityRole="radio"
              accessibilityState={{ checked: selected }}
              accessibilityLabel={`${label}, ${option.label}`}
            >
              <Text
                text={option.label}
                size="xs"
                weight="medium"
                style={themed(selected ? $preferenceOptionTextSelected : $preferenceOptionText)}
              />
            </TouchableOpacity>
          )
        })}
      </View>
      {hint && <Text text={hint} size="xxs" style={themed($preferenceHint)} />}
    </View>
  )
}

const $preference: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingVertical: spacing.sm,
  gap: spacing.xs,
})

const $preferenceSeparator: ThemedStyle<ViewStyle> = ({ colors }) => ({
  borderTopWidth: 1,
  borderTopColor: colors.separator,
})

const $preferenceOptions: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  flexWrap: "wrap",
  gap: spacing.xs,
})

const $preferenceOption: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 44,
  justifyContent: "center",
  paddingHorizontal: spacing.sm,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: 10,
  backgroundColor: colors.background,
})

const $preferenceOptionSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
  borderColor: colors.tint,
})

const $preferenceOptionText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.text })

const $preferenceHint: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })

const $preferenceOptionTextSelected: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
})
