import { createContext, ReactNode, useContext, useEffect, useState } from "react"
import {
  deleteDatabaseAsync,
  importDatabaseFromAssetAsync,
  openDatabaseAsync,
  type SQLiteDatabase,
} from "expo-sqlite"

/**
 * The patristic library's database, opened for the /works route rather than at
 * the app root.
 *
 * It is 43MB, and expo-sqlite copies a bundled asset into the app's own
 * storage the first time it is opened - work that has no business happening
 * while someone waits for the day's Scripture.
 *
 * It opens by hand rather than through SQLiteProvider because that component
 * renders null until the database is ready, and null here would blank the
 * library and the author shelves for the length of a 43MB copy. Those screens
 * read the bundled catalog and need no database at all; only the reader does,
 * and it already has somewhere to put a spinner.
 *
 * The Bible reader's "Fathers on this chapter" is likewise catalog-only, so it
 * never touches this provider.
 */

/**
 * Part of the file name, so a release that rebuilds the corpus imports a fresh
 * copy. The import is skipped whenever the destination merely exists, so
 * without this an updated app would keep the previous database while using the
 * new catalog, and the two would disagree about what section 40 is.
 * Bump whenever works.db is rebuilt with different content.
 */
const WORKS_DB_VERSION = 2
const WORKS_DB_NAME = `works-v${WORKS_DB_VERSION}.db`

/** Names this version supersedes, deleted once it is open, to reclaim space. */
const SUPERSEDED = [
  "works.db",
  ...Array.from({ length: WORKS_DB_VERSION - 1 }, (_, index) => `works-v${index + 1}.db`),
]

export type WorksDatabaseState = "opening" | "ready" | "failed"

const WorksDatabaseContext = createContext<SQLiteDatabase | null>(null)
const WorksDatabaseStateContext = createContext<WorksDatabaseState>("opening")

export function WorksDatabaseProvider({ children }: { children: ReactNode }) {
  const [database, setDatabase] = useState<SQLiteDatabase | null>(null)
  const [state, setState] = useState<WorksDatabaseState>("opening")

  useEffect(() => {
    let cancelled = false
    let opened: SQLiteDatabase | null = null

    async function open() {
      try {
        await importDatabaseFromAssetAsync(WORKS_DB_NAME, {
          assetId: require("@assets/works/works.db"),
        })
        opened = await openDatabaseAsync(WORKS_DB_NAME)
        if (cancelled) {
          await opened.closeAsync()
          return
        }
        setDatabase(opened)
        setState("ready")
        // Best effort: a superseded copy left behind is wasted space, not a
        // fault, and on most devices there is nothing to delete.
        for (const name of SUPERSEDED) {
          try {
            await deleteDatabaseAsync(name)
          } catch {
            // Never imported on this device, which is the common case.
          }
        }
      } catch {
        // Out of space, or a corrupt copy. The library says so; the rest of
        // the app is unaffected because nothing else opens this.
        if (!cancelled) setState("failed")
      }
    }

    open()
    return () => {
      cancelled = true
      opened?.closeAsync().catch(() => {})
    }
  }, [])

  return (
    <WorksDatabaseStateContext.Provider value={state}>
      <WorksDatabaseContext.Provider value={database}>{children}</WorksDatabaseContext.Provider>
    </WorksDatabaseStateContext.Provider>
  )
}

/** Null until the copy finishes, and for good if it failed. */
export function useWorksDatabase(): SQLiteDatabase | null {
  return useContext(WorksDatabaseContext)
}

export function useWorksDatabaseState(): WorksDatabaseState {
  return useContext(WorksDatabaseStateContext)
}
