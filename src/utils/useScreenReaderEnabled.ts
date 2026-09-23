import { useEffect, useState } from "react"
import { AccessibilityInfo, Platform } from "react-native"

/** Whether VoiceOver or TalkBack is running, kept current as it is switched on and off. */
export function useScreenReaderEnabled(): boolean {
  const [enabled, setEnabled] = useState(false)
  useEffect(() => {
    // react-native-web cannot detect a screen reader and always answers yes.
    if (Platform.OS === "web") return
    let active = true
    AccessibilityInfo.isScreenReaderEnabled()
      .then((value) => {
        if (active) setEnabled(value)
      })
      .catch(() => {})
    const subscription = AccessibilityInfo.addEventListener("screenReaderChanged", setEnabled)
    return () => {
      active = false
      subscription.remove()
    }
  }, [])
  return enabled
}
