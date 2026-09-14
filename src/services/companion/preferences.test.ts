import { load, saveString } from "@/utils/storage"

import {
  favoritePrayers,
  loadReflection,
  saveReflection,
  toggleFavoritePrayer,
} from "./preferences"

jest.mock("@/utils/storage", () => ({ load: jest.fn(), saveString: jest.fn() }))
const mockLoad = load as jest.Mock,
  mockSave = saveString as jest.Mock
beforeEach(() => {
  jest.clearAllMocks()
  mockSave.mockReturnValue(true)
})
test("malformed saved values cannot break the prayer library", () => {
  mockLoad.mockReturnValue({ before: 12, after: "A kind word" })
  expect(loadReflection("2026-09-13")).toEqual({ before: "", after: "A kind word" })
  mockLoad.mockReturnValue(["morning", 42, null])
  expect(favoritePrayers()).toEqual(["morning"])
})
test("Sunday reflections remain separated by date and storage failures are reported", () => {
  saveReflection("2026-09-13", { before: "A question", after: "A response" })
  expect(mockSave).toHaveBeenCalledWith(
    "vesper.sunday.2026-09-13",
    JSON.stringify({ before: "A question", after: "A response" }),
  )
  mockSave.mockReturnValue(false)
  expect(saveReflection("2026-09-20", { before: "", after: "" })).toBe(false)
})
test("favorite toggling removes an existing favorite without affecting the others", () => {
  mockLoad.mockReturnValue(["morning", "angelus"])
  toggleFavoritePrayer("morning")
  expect(mockSave).toHaveBeenCalledWith("vesper.prayer.favorites", JSON.stringify(["angelus"]))
})
