import { ConfigPlugin, withEntitlementsPlist } from "@expo/config-plugins"

/** Local calendar and Rosary reminders do not register with APNs.
 * expo-notifications adds aps-environment by default; keep our signed app's
 * capabilities limited to the local notifications we actually use.
 * Remove this plugin when implementing remote push notifications.
 */
const withLocalNotificationsOnly: ConfigPlugin = (config) =>
  withEntitlementsPlist(config, (config) => {
    delete config.modResults["aps-environment"]
    return config
  })

export default withLocalNotificationsOnly
