import { useEffect } from "react"
import { AccessibilityInfo, Platform } from "react-native"

/**
 * Speaks a status message to VoiceOver each time it changes. VoiceOver ignores
 * `accessibilityLiveRegion`, which only TalkBack reads, so screens keep the
 * live region for Android and call this for iOS. A polite message waits for
 * current speech to finish; an assertive one interrupts it.
 */
export function useAnnouncement(
  message: string | false | null | undefined,
  politeness: "polite" | "assertive" = "polite",
): void {
  useEffect(() => {
    if (Platform.OS !== "ios" || !message) return
    AccessibilityInfo.announceForAccessibilityWithOptions(message, {
      queue: politeness === "polite",
    })
  }, [message, politeness])
}
