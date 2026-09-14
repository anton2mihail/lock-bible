import { FC, useEffect, useMemo, useState } from "react"
import { Linking, Pressable, TextStyle, View, ViewStyle } from "react-native"
import { setAudioModeAsync, useAudioPlayer, useAudioPlayerStatus } from "expo-audio"
import { useRouter } from "expo-router"
import { useVideoPlayer, VideoView } from "expo-video"

import { Button } from "@/components/Button"
import { Screen } from "@/components/Screen"
import { Text } from "@/components/Text"
import {
  getRosaryMediaEpisode,
  ROSARY_MEDIA_EPISODES,
  WORD_ON_FIRE_PERMISSION_URL,
  WORD_ON_FIRE_ROSARY_URL,
} from "@/services/rosary"
import { useAppTheme } from "@/theme/context"
import type { ThemedStyle } from "@/theme/types"

const TEST_VIDEO_URI =
  "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
const TEST_AUDIO_URI = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"

type RosaryMediaScreenProps = {
  episodeId?: string
}

function formatTime(seconds: number | undefined): string {
  if (!seconds || !Number.isFinite(seconds)) return "0:00"
  const minutes = Math.floor(seconds / 60)
  const remainder = Math.floor(seconds % 60)
  return `${minutes}:${String(remainder).padStart(2, "0")}`
}

export const RosaryMediaScreen: FC<RosaryMediaScreenProps> = function RosaryMediaScreen({
  episodeId,
}) {
  const { themed } = useAppTheme()
  const router = useRouter()
  const episode = getRosaryMediaEpisode(episodeId) ?? ROSARY_MEDIA_EPISODES[0]
  const [mode, setMode] = useState<"video" | "audio">("video")
  const usingTestVideo = !episode.videoUri && __DEV__
  const usingTestAudio = !episode.audioUri && __DEV__
  const videoUri = episode.videoUri ?? (usingTestVideo ? TEST_VIDEO_URI : undefined)
  const audioUri = episode.audioUri ?? (usingTestAudio ? TEST_AUDIO_URI : undefined)
  const videoPlayer = useVideoPlayer(videoUri ?? null)
  const audioPlayer = useAudioPlayer(audioUri ?? null, { updateInterval: 500 })
  const audioStatus = useAudioPlayerStatus(audioPlayer)
  const audioProgress = useMemo<`${number}%`>(() => {
    if (!audioStatus.duration) return "0%"
    return `${Math.min(100, (audioStatus.currentTime / audioStatus.duration) * 100)}%`
  }, [audioStatus.currentTime, audioStatus.duration])

  useEffect(() => {
    setAudioModeAsync({
      playsInSilentMode: true,
      shouldPlayInBackground: true,
      interruptionMode: "doNotMix",
    }).catch(() => {})
  }, [])

  useEffect(() => {
    audioPlayer.pause()
    videoPlayer.pause()
  }, [audioPlayer, episode.id, videoPlayer])

  useEffect(
    () => () => {
      audioPlayer.setActiveForLockScreen(false)
    },
    [audioPlayer],
  )

  const playAudio = () => {
    videoPlayer.pause()
    audioPlayer.setActiveForLockScreen(true, {
      title: usingTestAudio ? "Development player test" : episode.title,
      artist: usingTestAudio ? "Open test audio" : "Bishop Robert Barron",
      albumTitle: usingTestAudio ? "Not Rosary content" : "The Rosary",
    })
    audioPlayer.play()
  }

  const selectMode = (nextMode: "video" | "audio") => {
    if (nextMode === "video") audioPlayer.pause()
    else videoPlayer.pause()
    setMode(nextMode)
  }

  return (
    <Screen preset="scroll" safeAreaEdges={["top"]} contentContainerStyle={themed($container)}>
      <Pressable
        onPress={() => router.back()}
        accessibilityRole="button"
        accessibilityLabel="Back to Rosary"
        hitSlop={8}
        style={({ pressed }) => themed([$back, pressed && $pressed])}
      >
        <Text text="‹" size="xl" style={themed($backMark)} />
        <Text text="Rosary" size="sm" weight="semiBold" style={themed($tintText)} />
      </Pressable>

      <View style={themed($heading)}>
        <Text text="WORD ON FIRE SERIES" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text text={episode.title} preset="heading" accessibilityRole="header" selectable />
        <Text text={episode.subtitle} size="sm" style={themed($subtitle)} selectable />
      </View>

      <View style={themed($modePicker)} accessibilityRole="radiogroup">
        {(["video", "audio"] as const).map((item) => {
          const selected = item === mode
          return (
            <Pressable
              key={item}
              onPress={() => selectMode(item)}
              accessibilityRole="radio"
              accessibilityState={{ checked: selected }}
              style={({ pressed }) =>
                themed([$modeButton, selected && $modeButtonSelected, pressed && $pressed])
              }
            >
              <Text
                text={item === "video" ? "Video" : "Audio"}
                size="xs"
                weight="semiBold"
                style={selected && themed($modeTextSelected)}
              />
            </Pressable>
          )
        })}
      </View>

      {mode === "video" ? (
        videoUri ? (
          <View style={themed($playerCard)}>
            <VideoView
              player={videoPlayer}
              nativeControls
              allowsPictureInPicture
              contentFit="contain"
              style={$video}
            />
            {usingTestVideo && (
              <Text
                text="Development test clip · This is open sample footage, not Bishop Barron’s video."
                size="xxs"
                style={themed($testNotice)}
                selectable
              />
            )}
          </View>
        ) : (
          <PendingMediaCard kind="video" themed={themed} />
        )
      ) : audioUri ? (
        <View style={themed($audioCard)}>
          <View style={themed($audioArtwork)} accessibilityElementsHidden>
            <Text text="✢" size="xxl" style={themed($tintText)} />
          </View>
          <View style={themed($audioCopy)}>
            <Text text={episode.title} preset="subheading" selectable />
            <Text
              text={
                usingTestAudio
                  ? "Development test audio · not Rosary content"
                  : "Bishop Robert Barron"
              }
              size="xs"
              style={themed($subtitle)}
              selectable
            />
          </View>
          <View style={themed($audioTrack)}>
            <View style={themed([$audioFill, { width: audioProgress }])} />
          </View>
          <View style={themed($timeRow)}>
            <Text text={formatTime(audioStatus.currentTime)} size="xxs" style={$tabularNumbers} />
            <Text text={formatTime(audioStatus.duration)} size="xxs" style={$tabularNumbers} />
          </View>
          <Button
            text={audioStatus.playing ? "Pause audio" : "Play audio"}
            preset="reversed"
            onPress={() => (audioStatus.playing ? audioPlayer.pause() : playAudio())}
          />
        </View>
      ) : (
        <PendingMediaCard kind="audio" themed={themed} />
      )}

      <View style={themed($rightsCard)}>
        <Text text="PERMISSION PENDING" size="xxs" weight="semiBold" style={themed($eyebrow)} />
        <Text
          text="The player is prepared for approved direct media URLs. Word on Fire’s standard permission page says archived on-demand audio and video require permission, so its files are not bundled here yet."
          size="xs"
          style={themed($subtitle)}
          selectable
        />
        <View style={themed($rightsLinks)}>
          <Text
            text="Official Rosary page"
            size="xs"
            weight="semiBold"
            style={themed($link)}
            accessibilityRole="link"
            onPress={() => Linking.openURL(WORD_ON_FIRE_ROSARY_URL).catch(() => {})}
          />
          <Text
            text="Content permission form"
            size="xs"
            weight="semiBold"
            style={themed($link)}
            accessibilityRole="link"
            onPress={() => Linking.openURL(WORD_ON_FIRE_PERMISSION_URL).catch(() => {})}
          />
        </View>
      </View>

      <View style={themed($section)}>
        <Text text="All episodes" preset="subheading" />
        <View style={themed($episodeList)}>
          {ROSARY_MEDIA_EPISODES.map((item) => {
            const selected = item.id === episode.id
            return (
              <Pressable
                key={item.id}
                onPress={() => router.setParams({ episode: item.id })}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                style={({ pressed }) =>
                  themed([$episodeRow, selected && $episodeRowSelected, pressed && $pressed])
                }
              >
                <View style={themed([$episodeNumber, selected && $episodeNumberSelected])}>
                  <Text
                    text={String(ROSARY_MEDIA_EPISODES.indexOf(item) + 1).padStart(2, "0")}
                    size="xxs"
                    weight="semiBold"
                    style={selected && themed($modeTextSelected)}
                  />
                </View>
                <View style={$flex}>
                  <Text text={item.title} size="xs" weight="semiBold" selectable />
                  <Text
                    text={item.subtitle}
                    size="xxs"
                    style={themed($subtitle)}
                    numberOfLines={2}
                  />
                </View>
                <Text text="›" size="lg" style={themed($tintText)} />
              </Pressable>
            )
          })}
        </View>
      </View>

      <Button
        text="Watch on the official site"
        onPress={() => Linking.openURL(episode.officialUrl).catch(() => {})}
      />
    </Screen>
  )
}

function PendingMediaCard({
  kind,
  themed,
}: {
  kind: "video" | "audio"
  themed: ReturnType<typeof useAppTheme>["themed"]
}) {
  return (
    <View style={themed($pendingCard)}>
      <Text text="Pray with the official recording" preset="subheading" />
      <Text
        text={`This ${kind} recording is available on the publisher’s website. Open the official site below to pray along.`}
        size="sm"
        style={themed($subtitle)}
        selectable
      />
    </View>
  )
}

const $container: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  paddingHorizontal: spacing.lg,
  paddingTop: spacing.md,
  paddingBottom: spacing.xxl,
  gap: spacing.lg,
})
const $back: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  minHeight: 40,
  alignSelf: "flex-start",
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.xxs,
})
const $backMark: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint, marginTop: -2 })
const $tintText: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.tint })
const $heading: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xs })
const $eyebrow: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  letterSpacing: 1.5,
})
const $subtitle: ThemedStyle<TextStyle> = ({ colors }) => ({ color: colors.textDim })
const $modePicker: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  flexDirection: "row",
  gap: spacing.xs,
  borderRadius: 14,
  backgroundColor: colors.palette.neutral100,
  padding: spacing.xxs,
})
const $modeButton: ThemedStyle<ViewStyle> = () => ({
  flex: 1,
  minHeight: 44,
  borderRadius: 11,
  alignItems: "center",
  justifyContent: "center",
})
const $modeButtonSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
})
const $modeTextSelected: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.palette.neutral100,
})
const $playerCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  overflow: "hidden",
  backgroundColor: colors.palette.neutral800,
  borderRadius: 20,
  borderCurve: "continuous",
  gap: spacing.sm,
  paddingBottom: spacing.sm,
})
const $video: ViewStyle = { width: "100%", aspectRatio: 16 / 9, backgroundColor: "#000000" }
const $testNotice: ThemedStyle<TextStyle> = ({ colors, spacing }) => ({
  color: colors.palette.neutral300,
  paddingHorizontal: spacing.md,
})
const $audioCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  backgroundColor: colors.palette.neutral100,
  borderRadius: 24,
  borderCurve: "continuous",
  padding: spacing.lg,
  gap: spacing.md,
})
const $audioArtwork: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: "100%",
  aspectRatio: 1.8,
  borderRadius: 18,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.background,
})
const $audioCopy: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.xxs })
const $audioTrack: ThemedStyle<ViewStyle> = ({ colors }) => ({
  height: 4,
  borderRadius: 2,
  overflow: "hidden",
  backgroundColor: colors.separator,
})
const $audioFill: ThemedStyle<ViewStyle> = ({ colors }) => ({
  height: "100%",
  backgroundColor: colors.tint,
})
const $timeRow: ThemedStyle<ViewStyle> = () => ({
  flexDirection: "row",
  justifyContent: "space-between",
})
const $pendingCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 220,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.palette.neutral100,
  borderRadius: 20,
  borderCurve: "continuous",
  padding: spacing.xl,
  gap: spacing.sm,
})
const $rightsCard: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  borderLeftWidth: 3,
  borderLeftColor: colors.tint,
  paddingLeft: spacing.md,
  gap: spacing.sm,
})
const $rightsLinks: ThemedStyle<ViewStyle> = ({ spacing }) => ({
  flexDirection: "row",
  flexWrap: "wrap",
  gap: spacing.md,
})
const $link: ThemedStyle<TextStyle> = ({ colors }) => ({
  color: colors.tint,
  textDecorationLine: "underline",
})
const $section: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.md })
const $episodeList: ThemedStyle<ViewStyle> = ({ spacing }) => ({ gap: spacing.sm })
const $episodeRow: ThemedStyle<ViewStyle> = ({ colors, spacing }) => ({
  minHeight: 76,
  flexDirection: "row",
  alignItems: "center",
  gap: spacing.sm,
  backgroundColor: colors.palette.neutral100,
  borderWidth: 1,
  borderColor: colors.transparent,
  borderRadius: 16,
  borderCurve: "continuous",
  padding: spacing.sm,
})
const $episodeRowSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({ borderColor: colors.tint })
const $episodeNumber: ThemedStyle<ViewStyle> = ({ colors }) => ({
  width: 38,
  height: 38,
  borderRadius: 19,
  alignItems: "center",
  justifyContent: "center",
  backgroundColor: colors.background,
})
const $episodeNumberSelected: ThemedStyle<ViewStyle> = ({ colors }) => ({
  backgroundColor: colors.tint,
})
const $pressed: ThemedStyle<ViewStyle> = () => ({ opacity: 0.72 })
const $flex: ViewStyle = { flex: 1 }
const $tabularNumbers: TextStyle = { fontVariant: ["tabular-nums"] }
