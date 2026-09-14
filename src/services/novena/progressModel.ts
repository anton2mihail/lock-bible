import { NOVENA_DAY_COUNT } from "./padrePioNovena"

export type NovenaProgress = {
  completedDays: number[]
  selectedDay: number
  intention: string
}

export const emptyNovenaProgress: NovenaProgress = {
  completedDays: [],
  selectedDay: 1,
  intention: "",
}

function isDay(value: unknown): value is number {
  return (
    typeof value === "number" && Number.isInteger(value) && value >= 1 && value <= NOVENA_DAY_COUNT
  )
}

export function normalizeNovenaProgress(value: unknown): NovenaProgress {
  if (!value || typeof value !== "object") return { ...emptyNovenaProgress }

  const candidate = value as Partial<NovenaProgress>
  const completedDays = Array.isArray(candidate.completedDays)
    ? [...new Set(candidate.completedDays.filter(isDay))].sort((a, b) => a - b)
    : []

  return {
    completedDays,
    selectedDay: isDay(candidate.selectedDay) ? candidate.selectedDay : 1,
    intention: typeof candidate.intention === "string" ? candidate.intention : "",
  }
}
