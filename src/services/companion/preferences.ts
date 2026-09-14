import { load, saveString } from "@/utils/storage"

export type Reflection = { before: string; after: string }
export function loadReflection(date: string): Reflection {
  const data = load<Partial<Reflection>>(`vesper.sunday.${date}`)
  return {
    before: typeof data?.before === "string" ? data.before : "",
    after: typeof data?.after === "string" ? data.after : "",
  }
}
export function saveReflection(date: string, value: Reflection): boolean {
  return saveString(`vesper.sunday.${date}`, JSON.stringify(value))
}
export function favoritePrayers(): string[] {
  const value = load<unknown>("vesper.prayer.favorites")
  return Array.isArray(value) ? value.filter((id): id is string => typeof id === "string") : []
}
export function toggleFavoritePrayer(id: string): boolean {
  const current = favoritePrayers()
  return saveString(
    "vesper.prayer.favorites",
    JSON.stringify(current.includes(id) ? current.filter((x) => x !== id) : [...current, id]),
  )
}
