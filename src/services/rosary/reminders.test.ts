import { DEFAULT_ROSARY_REMINDER, normalizeRosaryReminder } from "./reminders"

describe("Rosary reminders", () => {
  test("uses a safe local default for invalid storage", () => {
    expect(normalizeRosaryReminder(null)).toEqual(DEFAULT_ROSARY_REMINDER)
  })

  test("preserves valid daily and weekly schedules", () => {
    expect(
      normalizeRosaryReminder({
        enabled: true,
        frequency: "weekly",
        hour: 7,
        minute: 35,
        weekday: 6,
        notificationId: "local-id",
      }),
    ).toEqual({
      enabled: true,
      frequency: "weekly",
      hour: 7,
      minute: 35,
      weekday: 6,
      notificationId: "local-id",
    })
  })

  test("rejects out-of-range calendar values", () => {
    expect(
      normalizeRosaryReminder({
        enabled: true,
        frequency: "other",
        hour: 24,
        minute: -1,
        weekday: 0,
      }),
    ).toEqual({ ...DEFAULT_ROSARY_REMINDER, enabled: true })
  })
})
