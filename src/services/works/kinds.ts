import type { WorkKind } from "./types"

/**
 * How the library groups an author's shelf. Most of the corpus expounds no
 * particular chapter of Scripture - treatises, rules, letters, autobiography -
 * so a work's kind, not the book it comments on, is what gives it a place.
 *
 * The order is the reading order a browser expects: what walks Scripture
 * first, then what was preached, then what was written.
 */
export const WORK_KIND_ORDER: readonly WorkKind[] = [
  "commentary",
  "sermons",
  "letters",
  "treatise",
  "devotional",
  "prayers",
  "autobiography",
  "rule",
  "history",
]

export const WORK_KIND_LABEL: Record<WorkKind, string> = {
  commentary: "On Scripture",
  sermons: "Sermons & Homilies",
  letters: "Letters",
  treatise: "Treatises",
  devotional: "Devotional",
  prayers: "Prayers & Meditations",
  autobiography: "Life & Confessions",
  rule: "Rules of Life",
  history: "History",
}

/**
 * What one section of a work is called, for the reader's navigation labels.
 * The corpus is mostly not homilies, so announcing "next homily" over a
 * treatise or a letter tells a screen-reader user something untrue.
 */
export const WORK_SECTION_NOUN: Record<WorkKind, string> = {
  commentary: "section",
  sermons: "homily",
  letters: "letter",
  treatise: "chapter",
  devotional: "chapter",
  prayers: "prayer",
  autobiography: "book",
  history: "chapter",
  rule: "chapter",
}

/** "1 work" / "3 works" - six collections ship exactly one. */
export function plural(count: number, noun: string): string {
  return `${count} ${noun}${count === 1 ? "" : "s"}`
}
