import { Stack } from "expo-router"

import { WorksDatabaseProvider } from "@/services/database"

export default function WorksLayout() {
  return (
    <WorksDatabaseProvider>
      <Stack screenOptions={{ headerShown: false }} />
    </WorksDatabaseProvider>
  )
}
