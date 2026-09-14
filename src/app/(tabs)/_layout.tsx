import { Tabs } from "expo-router"
import { Feather } from "@expo/vector-icons"

import { useAppTheme } from "@/theme/context"

export default function TabsLayout() {
  const { theme } = useAppTheme()

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: theme.colors.tint,
        tabBarInactiveTintColor: theme.colors.tintInactive,
        tabBarStyle: {
          backgroundColor: theme.colors.background,
          borderTopColor: theme.colors.border,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "Today",
          tabBarButtonTestID: "tab-today",
          tabBarIcon: ({ color, size }) => <Feather name="sun" color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="read"
        options={{
          title: "Read",
          tabBarButtonTestID: "tab-read",
          tabBarIcon: ({ color, size }) => <Feather name="book-open" color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="saved"
        options={{
          title: "Saved",
          tabBarButtonTestID: "tab-saved",
          tabBarIcon: ({ color, size }) => <Feather name="bookmark" color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="pray"
        options={{
          title: "Pray",
          tabBarButtonTestID: "tab-pray",
          tabBarIcon: ({ color, size }) => <Feather name="heart" color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: "Settings",
          tabBarButtonTestID: "tab-settings",
          tabBarIcon: ({ color, size }) => <Feather name="settings" color={color} size={size} />,
        }}
      />
      <Tabs.Screen name="search" options={{ href: null }} />
    </Tabs>
  )
}
