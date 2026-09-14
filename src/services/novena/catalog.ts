import { expandedNovenas } from "./expandedNovenas"
import { padrePioNovena, type Novena } from "./padrePioNovena"
import { perpetualHelpNovena } from "./perpetualHelpNovena"
import { stJosephNovena } from "./stJosephNovena"
import { stJudeNovena } from "./stJudeNovena"
import { stPeregrineNovena } from "./stPeregrineNovena"
import { stThereseNovena } from "./stThereseNovena"

export const novenas: Novena[] = [
  padrePioNovena,
  stJudeNovena,
  stPeregrineNovena,
  stJosephNovena,
  stThereseNovena,
  perpetualHelpNovena,
  ...expandedNovenas,
]

export function getNovena(id: string | undefined): Novena | undefined {
  return novenas.find((novena) => novena.id === id)
}

export function searchNovenas(query: string): Novena[] {
  const normalizedQuery = query.trim().toLocaleLowerCase()
  if (!normalizedQuery) return novenas

  return novenas.filter((novena) =>
    [novena.title, novena.subtitle, novena.about, novena.patronage, ...novena.searchTerms]
      .join(" ")
      .toLocaleLowerCase()
      .includes(normalizedQuery),
  )
}
