import { createContext, ReactNode, useContext } from "react"
import { SQLiteProvider, useSQLiteContext, type SQLiteDatabase } from "expo-sqlite"

import { migrateLibraryDatabase } from "./libraryDatabase"

const SearchDatabaseContext = createContext<SQLiteDatabase | null>(null)

interface AppDatabaseProviderProps {
  children: ReactNode
}

/**
 * The two databases the whole app needs: the bundled Scripture search index
 * and the writable user library. The patristic works database is deliberately
 * not here - it is 43MB and only the /works route needs it, so it mounts there
 * instead (see WorksDatabaseProvider).
 */
export function AppDatabaseProvider({ children }: AppDatabaseProviderProps) {
  return (
    <SQLiteProvider
      databaseName="bible-search.db"
      assetSource={{ assetId: require("@assets/bible/bible-search.db") }}
      // Without a handler expo-sqlite rethrows from its own render body, which
      // nothing catches. Search degrades; the rest of the app keeps working.
      onError={(error) => console.warn("Scripture search unavailable:", error)}
    >
      <SearchDatabaseBridge>{children}</SearchDatabaseBridge>
    </SQLiteProvider>
  )
}

function SearchDatabaseBridge({ children }: AppDatabaseProviderProps) {
  const searchDatabase = useSQLiteContext()
  return (
    <SearchDatabaseContext.Provider value={searchDatabase}>
      <SQLiteProvider databaseName="user-library.db" onInit={migrateLibraryDatabase}>
        {children}
      </SQLiteProvider>
    </SearchDatabaseContext.Provider>
  )
}

export function useSearchDatabase(): SQLiteDatabase {
  const database = useContext(SearchDatabaseContext)
  if (!database) throw new Error("Search database is not available.")
  return database
}

export function useLibraryDatabase(): SQLiteDatabase {
  return useSQLiteContext()
}
