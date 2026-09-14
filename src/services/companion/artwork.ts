import type { ImageSourcePropType } from "react-native"

export const saintArt: Record<string, ImageSourcePropType> = {
  "st-padre-pio": require("../../../assets/artwork/st-padre-pio.jpg"),
  "st-jude": require("../../../assets/artwork/st-jude.jpg"),
  "st-peregrine": require("../../../assets/artwork/st-peregrine.jpg"),
  "st-joseph": require("../../../assets/artwork/st-joseph.jpg"),
  "st-therese": require("../../../assets/artwork/st-therese.jpg"),
  "st-anthony": require("../../../assets/artwork/st-anthony.jpg"),
  "st-anne": require("../../../assets/artwork/st-anne.jpg"),
  "st-rita": require("../../../assets/artwork/st-rita.jpg"),
  "st-monica": require("../../../assets/artwork/st-monica.jpg"),
  "st-michael": require("../../../assets/artwork/st-michael.jpg"),
  "st-benedict": require("../../../assets/artwork/st-benedict.jpg"),
  "st-francis-assisi": require("../../../assets/artwork/st-francis-assisi.jpg"),
  "st-dymphna": require("../../../assets/artwork/st-dymphna.jpg"),
}
export const mysteryArt: Record<string, ImageSourcePropType[]> = {
  joyful: [
    require("../../../assets/artwork/joyful-1.jpg"),
    require("../../../assets/artwork/joyful-2.jpg"),
    require("../../../assets/artwork/joyful-3.jpg"),
    require("../../../assets/artwork/joyful-4.jpg"),
    require("../../../assets/artwork/joyful-5.jpg"),
  ],
  sorrowful: [
    require("../../../assets/artwork/sorrowful-1.jpg"),
    require("../../../assets/artwork/sorrowful-2.jpg"),
    require("../../../assets/artwork/sorrowful-3.jpg"),
    require("../../../assets/artwork/sorrowful-4.jpg"),
    require("../../../assets/artwork/sorrowful-5.jpg"),
  ],
  glorious: [
    require("../../../assets/artwork/glorious-1.jpg"),
    require("../../../assets/artwork/glorious-2.jpg"),
    require("../../../assets/artwork/glorious-3.jpg"),
    require("../../../assets/artwork/glorious-4.jpg"),
    require("../../../assets/artwork/glorious-5.jpg"),
  ],
  luminous: [
    require("../../../assets/artwork/luminous-1.jpg"),
    require("../../../assets/artwork/luminous-2.jpg"),
    require("../../../assets/artwork/luminous-3.jpg"),
    require("../../../assets/artwork/luminous-4.jpg"),
    require("../../../assets/artwork/luminous-5.jpg"),
  ],
}
export const rosaryCover = {
  joyful: mysteryArt.joyful[2],
  sorrowful: mysteryArt.sorrowful[0],
  glorious: mysteryArt.glorious[0],
  luminous: mysteryArt.luminous[4],
}
export function novenaArt(id: string): ImageSourcePropType {
  if (saintArt[id]) return saintArt[id]
  if (id === "holy-spirit") return mysteryArt.glorious[2]
  if (id === "assumption") return mysteryArt.glorious[3]
  if (id === "sacred-heart" || id === "divine-mercy" || id === "christ-the-king")
    return mysteryArt.glorious[0]
  if (id.includes("lady") || id === "miraculous-medal" || id === "immaculate-conception")
    return require("../../../assets/artwork/mary.jpg")
  return require("../../../assets/artwork/prayer.jpg")
}
