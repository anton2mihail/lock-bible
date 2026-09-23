import {
  getReaderLayout,
  getReaderLineSpacing,
  getReaderTextSize,
  getReaderTypeface,
  setReaderLayout,
  setReaderLineSpacing,
  setReaderTextSize,
  setReaderTypeface,
  useReadingPreference,
  type ReaderLayout,
  type ReaderLineSpacing,
  type ReaderTextSize,
  type ReaderTypeface,
} from "@/services/bible"
import { useAppTheme } from "@/theme/context"

import { PreferencePicker } from "./PreferencePicker"

type AppearancePreference = "system" | "light" | "dark"

const TEXT_SIZE_OPTIONS: readonly { value: ReaderTextSize; label: string }[] = [
  { value: "small", label: "Small" },
  { value: "medium", label: "Default" },
  { value: "large", label: "Large" },
  { value: "extraLarge", label: "Extra large" },
]

const LINE_SPACING_OPTIONS: readonly { value: ReaderLineSpacing; label: string }[] = [
  { value: "compact", label: "Compact" },
  { value: "comfortable", label: "Comfortable" },
  { value: "relaxed", label: "Relaxed" },
]

const TYPEFACE_OPTIONS: readonly { value: ReaderTypeface; label: string }[] = [
  { value: "serif", label: "Serif" },
  { value: "sans", label: "Sans" },
]

const LAYOUT_OPTIONS: readonly { value: ReaderLayout; label: string }[] = [
  { value: "paragraphs", label: "Paragraphs" },
  { value: "verses", label: "Verse by verse" },
]

const APPEARANCE_OPTIONS: readonly { value: AppearancePreference; label: string }[] = [
  { value: "system", label: "System" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
]

/**
 * How Scripture looks. Settings and the reader's Aa sheet show the same
 * controls, and every screen showing Scripture follows a change at once.
 */
export function ReadingSettings() {
  const { setThemeContextOverride, themeContextOverride } = useAppTheme()
  const textSize = useReadingPreference(getReaderTextSize)
  const lineSpacing = useReadingPreference(getReaderLineSpacing)
  const typeface = useReadingPreference(getReaderTypeface)
  const layout = useReadingPreference(getReaderLayout)
  const appearance: AppearancePreference = themeContextOverride ?? "system"

  return (
    <>
      <PreferencePicker
        label="Text size"
        value={textSize}
        options={TEXT_SIZE_OPTIONS}
        onSelect={setReaderTextSize}
      />
      <PreferencePicker
        label="Line spacing"
        value={lineSpacing}
        options={LINE_SPACING_OPTIONS}
        onSelect={setReaderLineSpacing}
        topSeparator
      />
      <PreferencePicker
        label="Scripture typeface"
        value={typeface}
        options={TYPEFACE_OPTIONS}
        onSelect={setReaderTypeface}
        topSeparator
      />
      <PreferencePicker
        label="Layout"
        value={layout}
        options={LAYOUT_OPTIONS}
        onSelect={setReaderLayout}
        hint="With VoiceOver on, the reader always goes verse by verse."
        topSeparator
      />
      <PreferencePicker
        label="Appearance"
        value={appearance}
        options={APPEARANCE_OPTIONS}
        onSelect={(value) => setThemeContextOverride(value === "system" ? undefined : value)}
        topSeparator
      />
    </>
  )
}
