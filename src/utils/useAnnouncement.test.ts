import { AccessibilityInfo, Platform } from "react-native"
import { renderHook } from "@testing-library/react-native"

import { useAnnouncement } from "./useAnnouncement"

describe("useAnnouncement", () => {
  const announce = jest
    .spyOn(AccessibilityInfo, "announceForAccessibilityWithOptions")
    .mockImplementation(() => {})

  beforeEach(() => announce.mockClear())

  it("speaks each new status message to VoiceOver after current speech", () => {
    const { rerender } = renderHook(
      ({ message }: { message: string }) => useAnnouncement(message),
      { initialProps: { message: "" } },
    )
    expect(announce).not.toHaveBeenCalled()

    rerender({ message: "3 results" })
    rerender({ message: "3 results" })
    expect(announce).toHaveBeenCalledTimes(1)
    expect(announce).toHaveBeenCalledWith("3 results", { queue: true })

    rerender({ message: "No passages found" })
    expect(announce).toHaveBeenLastCalledWith("No passages found", { queue: true })
  })

  it("interrupts current speech for an assertive message", () => {
    renderHook(() => useAnnouncement("The note could not be saved", "assertive"))
    expect(announce).toHaveBeenCalledWith("The note could not be saved", { queue: false })
  })

  it("leaves Android to the live regions TalkBack already reads", () => {
    const platform = jest.replaceProperty(Platform, "OS", "android")
    try {
      renderHook(() => useAnnouncement("Copied"))
      expect(announce).not.toHaveBeenCalled()
    } finally {
      platform.restore()
    }
  })
})
