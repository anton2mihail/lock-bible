import { createHash } from "node:crypto"
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import {
  ROSARY_MEDIA_EPISODES,
  ROSARY_MYSTERY_SETS,
  SEVEN_SORROWS,
  getRosaryDevotion,
  getRosaryMediaEpisode,
  getSuggestedRosaryMysterySet,
  hasApprovedRosaryMedia,
} from "../../../../src/services/rosary/catalog.ts"
import { buildRosarySession } from "../../../../src/services/rosary/prayers.ts"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..")
const output = resolve(process.argv[2] ?? join(root, "build/native-evidence/L10-L11/rosary-session-fixtures.json"))
mkdirSync(dirname(output), { recursive: true })

const sourcePaths = [
  "scripts/native/source-fixtures/content/rosary-session-fixtures.ts",
  "src/services/rosary/index.ts",
  "src/services/rosary/catalog.ts",
  "src/services/rosary/prayers.ts",
  "src/services/rosary/types.ts",
  "src/services/rosary/catalog.test.ts",
  "src/screens/rosary/rosary-guide-screen.tsx",
  "src/screens/rosary/rosary-media-screen.tsx",
]
const hash = (path: string) => createHash("sha256").update(readFileSync(join(root, path))).digest("hex")

type State = { stepIndex: number; repetitionIndex: number; complete: boolean }
function totalActions(session: ReturnType<typeof buildRosarySession>): number {
  return session.steps.reduce((total, step) => total + step.repetitions, 0)
}
function observe(session: ReturnType<typeof buildRosarySession>, state: State) {
  const step = session.steps[state.stepIndex]
  const before = session.steps.slice(0, state.stepIndex).reduce((total, item) => total + item.repetitions, 0)
  const total = totalActions(session)
  const done = state.complete ? total : before + state.repetitionIndex
  return {
    stepIndex: state.stepIndex,
    repetitionIndex: state.repetitionIndex,
    complete: state.complete,
    stepID: step.id,
    stepTitle: step.title,
    repetitionLabel: `${state.repetitionIndex + 1} / ${step.repetitions}`,
    completedActions: done,
    totalActions: total,
    progressPercent: `${Math.round((done / total) * 100)}%`,
  }
}
function forward(session: ReturnType<typeof buildRosarySession>, state: State): State {
  const step = session.steps[state.stepIndex]
  if (state.repetitionIndex + 1 < step.repetitions) {
    return { ...state, repetitionIndex: state.repetitionIndex + 1 }
  }
  if (state.stepIndex + 1 >= session.steps.length) return { ...state, complete: true }
  return { stepIndex: state.stepIndex + 1, repetitionIndex: 0, complete: false }
}
function back(session: ReturnType<typeof buildRosarySession>, state: State): State {
  if (state.complete) return { ...state, complete: false }
  if (state.repetitionIndex > 0) return { ...state, repetitionIndex: state.repetitionIndex - 1 }
  if (state.stepIndex > 0) {
    const previous = session.steps[state.stepIndex - 1]
    return { stepIndex: state.stepIndex - 1, repetitionIndex: previous.repetitions - 1, complete: false }
  }
  return state
}

function buildProgressFixture(session: ReturnType<typeof buildRosarySession>) {
  const firstRepeatedStep = session.steps.findIndex((step) => step.repetitions > 1)
  let probe: State = { stepIndex: 0, repetitionIndex: 0, complete: false }
  const beforeRepeatedStep = [observe(session, probe)]
  while (probe.stepIndex < firstRepeatedStep) {
    probe = forward(session, probe)
    beforeRepeatedStep.push(observe(session, probe))
  }
  const repeatedActionStart = observe(session, probe)
  probe = forward(session, probe)
  const repeatedActionNext = observe(session, probe)
  probe = back(session, probe)
  const repeatedActionBack = observe(session, probe)

  let state: State = { stepIndex: 0, repetitionIndex: 0, complete: false }
  const fullRun = [observe(session, state)]
  let guard = totalActions(session) + 2
  while (!state.complete && guard-- > 0) {
    state = forward(session, state)
    fullRun.push(observe(session, state))
  }
  const completion = observe(session, state)
  const completedAfterSweep = state.complete
  state = back(session, state)
  const backFromComplete = observe(session, state)
  state = { stepIndex: 0, repetitionIndex: 0, complete: false }
  const prayAgainReset = observe(session, state)

  return {
    persistence: "Temporary React state only. The screen does not save Rosary guide step progress.",
    callbackSource: "The transition trace maps RosaryGuideScreen goForward, goBack, and Pray again callbacks. The screen does not export these transitions as functions.",
    beforeRepeatedStep,
    repeatedAction: { before: repeatedActionStart, afterForward: repeatedActionNext, afterBack: repeatedActionBack },
    fullRun,
    completion,
    completedAfterSweep,
    backFromComplete,
    prayAgainReset,
    fullRunCompleted: completedAfterSweep && prayAgainReset.stepIndex === 0,
  }
}

const devotionIDs = [...ROSARY_MYSTERY_SETS.map((set) => set.id), SEVEN_SORROWS.id]
const sessions = devotionIDs.map((id) => {
  const devotion = getRosaryDevotion(id)
  if (!devotion) throw new Error(`Missing source devotion: ${id}`)
  const session = buildRosarySession(devotion)
  return {
    session,
    progress: buildProgressFixture(session),
  }
})

const fallbackDate = new Date(2026, 8, 7, 12)
const fallbackSet = getSuggestedRosaryMysterySet(fallbackDate)
const missingGuideFallback = {
  localDateTime: "2026-09-07T12:00",
  requestedIDs: [null, "invalid-set"],
  resolvedDevotion: getRosaryDevotion(undefined)?.id ?? fallbackSet.id,
  suggestedSet: fallbackSet.id,
  rule: "RosaryGuideScreen uses getRosaryDevotion(id) ?? getSuggestedRosaryMysterySet(). The test date is Monday, so the source selector returns joyful.",
}

const firstEpisode = ROSARY_MEDIA_EPISODES[0]
const mediaFallbacks = [undefined, "invalid-episode"].map((requestedID) => {
  const episode = getRosaryMediaEpisode(requestedID) ?? ROSARY_MEDIA_EPISODES[0]
  return {
    requestedID: requestedID ?? null,
    resolvedID: episode.id,
    title: episode.title,
    subtitle: episode.subtitle,
    officialURL: episode.officialUrl,
    hasVideoURI: Boolean(episode.videoUri),
    hasAudioURI: Boolean(episode.audioUri),
    releasePlayerVisible: hasApprovedRosaryMedia(episode),
    developmentPlayerVisible: true,
    releaseGate: "__DEV__ || hasApprovedRosaryMedia(episode)",
    fallbackRule: "RosaryMediaScreen uses getRosaryMediaEpisode(id) ?? ROSARY_MEDIA_EPISODES[0].",
    mediaOpened: false,
  }
})

const result = {
  formatVersion: 1,
  generatedBy: "scripts/native/source-fixtures/content/rosary-session-fixtures.ts",
  sourceHashes: Object.fromEntries(sourcePaths.map((path) => [path, hash(path)])),
  provenance: {
    sequence: "buildRosarySession is called for the four source mystery sets and Seven Sorrows.",
    progress: "The temporary step, repetition, back, completion, and reset state is reconstructed from RosaryGuideScreen callbacks. It is not persisted.",
    media: "The catalog metadata and release approval gate are read. No media URI is fetched or opened.",
  },
  missingGuideFallback,
  sessions,
  media: {
    episodeCount: ROSARY_MEDIA_EPISODES.length,
    approvedEpisodeCount: ROSARY_MEDIA_EPISODES.filter((episode) => hasApprovedRosaryMedia(episode)).length,
    firstEpisodeID: firstEpisode.id,
    unknownAndMissingIDFallbacks: mediaFallbacks,
    catalog: ROSARY_MEDIA_EPISODES.map((episode) => ({
      id: episode.id,
      title: episode.title,
      subtitle: episode.subtitle,
      officialURL: episode.officialUrl,
      mysterySetID: episode.mysterySetId ?? null,
      hasVideoURI: Boolean(episode.videoUri),
      hasAudioURI: Boolean(episode.audioUri),
      hasApprovedMedia: hasApprovedRosaryMedia(episode),
    })),
  },
}

writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`)
console.log(`Wrote ${sessions.length} source Rosary sessions to ${output}`)
