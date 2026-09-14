import { useLocalSearchParams } from "expo-router"

import { RosaryGuideScreen } from "@/screens/rosary/rosary-guide-screen"

export default function RosaryGuideRoute() {
  const { set } = useLocalSearchParams<{ set?: string }>()
  return <RosaryGuideScreen mysterySetId={set} />
}
