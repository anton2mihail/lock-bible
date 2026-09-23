import { useLocalSearchParams } from "expo-router"

import { WorkReaderScreen } from "@/screens/works/work-reader-screen"

export default function WorkRoute() {
  const { id, section } = useLocalSearchParams<{ id?: string; section?: string }>()
  return <WorkReaderScreen workId={id} section={section} />
}
