import { useLocalSearchParams } from "expo-router"

import { RosaryMediaScreen } from "@/screens/rosary/rosary-media-screen"

export default function RosaryMediaRoute() {
  const { episode } = useLocalSearchParams<{ episode?: string }>()
  return <RosaryMediaScreen episodeId={episode} />
}
