import { useEffect, useState } from "react"
import { AppState } from "react-native"
import { router, Stack, SplashScreen } from "expo-router"
import { useFonts } from "@expo-google-fonts/space-grotesk"
import { KeyboardProvider } from "react-native-keyboard-controller"
import { initialWindowMetrics, SafeAreaProvider } from "react-native-safe-area-context"

import { initI18n } from "@/i18n"
import { refreshCalendarNotifications } from "@/services/companion/calendarNotifications"
import { AppDatabaseProvider } from "@/services/database"
import { syncWidget } from "@/services/widget/widgetBridge"
import { ThemeProvider } from "@/theme/context"
import { customFontsToLoad } from "@/theme/typography"
import { loadDateFnsLocale } from "@/utils/formatDate"

SplashScreen.preventAutoHideAsync()

if (__DEV__) {
  // Load Reactotron configuration in development. We don't want to
  // include this in our production bundle, so we are using `if (__DEV__)`
  // to only execute this in development.
  require("@/devtools/ReactotronConfig")
}

export default function Root() {
  const [fontsLoaded, fontError] = useFonts(customFontsToLoad)
  const [isI18nInitialized, setIsI18nInitialized] = useState(false)

  useEffect(() => {
    initI18n()
      .then(() => setIsI18nInitialized(true))
      .then(() => loadDateFnsLocale())
  }, [])

  // Migrate shared widget preferences once per app launch. Explicit settings
  // changes trigger their own reloads; normal tab navigation does not spend the
  // system's widget refresh budget.
  useEffect(() => {
    syncWidget()
  }, [])

  useEffect(() => {
    if (process.env.EXPO_OS === "web") return
    const refresh = () => {
      void refreshCalendarNotifications().catch(() => {})
    }
    refresh()
    const subscription = AppState.addEventListener("change", (state) => {
      if (state === "active") refresh()
    })
    const timer = setInterval(
      () => {
        if (AppState.currentState === "active") refresh()
      },
      60 * 60 * 1000,
    )
    return () => {
      subscription.remove()
      clearInterval(timer)
    }
  }, [])

  const loaded = fontsLoaded && isI18nInitialized

  useEffect(() => {
    if (!loaded || process.env.EXPO_OS === "web") return

    let responseSubscription: { remove: () => void } | undefined
    let disposed = false

    void import("expo-notifications").then(async (Notifications) => {
      if (disposed) return

      Notifications.setNotificationHandler({
        handleNotification: async () => ({
          shouldShowBanner: true,
          shouldShowList: true,
          shouldPlaySound: true,
          shouldSetBadge: false,
        }),
      })

      const openNotification = (url: unknown) => {
        if (url === "/pray/rosary") router.push("/pray/rosary")
        if (typeof url === "string" && /^\/daily\?date=\d{4}-\d{2}-\d{2}$/.test(url)) {
          router.push({ pathname: "/daily", params: { date: url.slice(-10) } })
        }
      }

      const lastResponse = await Notifications.getLastNotificationResponseAsync()
      if (!disposed && lastResponse) {
        openNotification(lastResponse.notification.request.content.data?.url)
        await Notifications.clearLastNotificationResponseAsync()
      }

      if (!disposed) {
        responseSubscription = Notifications.addNotificationResponseReceivedListener((response) => {
          openNotification(response.notification.request.content.data?.url)
        })
      }
    })

    return () => {
      disposed = true
      responseSubscription?.remove()
    }
  }, [loaded])

  useEffect(() => {
    if (fontError) throw fontError
  }, [fontError])

  useEffect(() => {
    if (loaded) {
      SplashScreen.hideAsync()
    }
  }, [loaded])

  if (!loaded) {
    return null
  }

  return (
    <SafeAreaProvider initialMetrics={initialWindowMetrics}>
      <ThemeProvider>
        <AppDatabaseProvider>
          <KeyboardProvider>
            <Stack screenOptions={{ headerShown: false }} />
          </KeyboardProvider>
        </AppDatabaseProvider>
      </ThemeProvider>
    </SafeAreaProvider>
  )
}
