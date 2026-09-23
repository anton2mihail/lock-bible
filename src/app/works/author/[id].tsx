import { useLocalSearchParams } from "expo-router"

import { WorksCollectionScreen } from "@/screens/works/works-collection-screen"

export default function WorksAuthorRoute() {
  const { id } = useLocalSearchParams<{ id?: string }>()
  return <WorksCollectionScreen collectionId={id} />
}
