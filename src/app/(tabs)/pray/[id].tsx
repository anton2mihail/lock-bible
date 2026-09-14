import { useLocalSearchParams } from "expo-router"

import { NovenaScreen } from "@/screens/NovenaScreen"

export default function NovenaRoute() {
  const { id } = useLocalSearchParams<{ id?: string }>()
  return <NovenaScreen novenaId={id} />
}
