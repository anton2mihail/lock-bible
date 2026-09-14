import { readdirSync, readFileSync, rmSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { WIDGET_DATA_FILES, writeWidgetResources } from "./widget-data-format.mjs"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const dataRoot = join(root, "src", "services", "bible", "data")
const widgetTarget = join(root, "targets/widget")

// Remove the pre-translation corpus from older builds. Every current resource
// is prefixed by its translation id and selected at runtime by the widget.
Object.values(WIDGET_DATA_FILES).forEach((file) =>
  rmSync(join(widgetTarget, file), { force: true }),
)

for (const translationId of readdirSync(dataRoot)) {
  const payloadPath = join(dataRoot, translationId, "widgetVerses.json")
  try {
    const payload = JSON.parse(readFileSync(payloadPath, "utf8"))
    const result = writeWidgetResources(payload.verses, widgetTarget, translationId)
    console.log(
      `${translationId}: ${result.full} full, ${result.ot} OT/deuterocanon, ${result.nt} NT; ${result.bytes} bytes.`,
    )
  } catch (error) {
    if (error.code !== "ENOENT") throw error
  }
}
