import { load, save } from "@/utils/storage"

import { normalizeNovenaProgress, type NovenaProgress } from "./progressModel"

function progressKey(novenaId: string): string {
  return `novena.${novenaId}.progress.v1`
}

export function loadNovenaProgress(novenaId: string): NovenaProgress {
  return normalizeNovenaProgress(load<unknown>(progressKey(novenaId)))
}

export function saveNovenaProgress(novenaId: string, progress: NovenaProgress): boolean {
  return save(progressKey(novenaId), normalizeNovenaProgress(progress))
}
