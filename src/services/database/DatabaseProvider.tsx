import { createContext, ReactNode, useContext } from "react"
import { SQLiteProvider, useSQLiteContext, type SQLiteDatabase } from "expo-sqlite"

import { migrateLibraryDatabase } from "./libraryDatabase"

const SearchDatabaseContext = createContext<SQLiteDatabase | null>(null)

interface AppDatabaseProviderProps {
  children: ReactNode
}

export function AppDatabaseProvider({ children }: AppDatabaseProviderProps) {
  return (
    <SQLiteProvider
      databaseName="bible-search.db"
      assetSource={{ assetId: require("@assets/bible/bible-search.db") }}
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
