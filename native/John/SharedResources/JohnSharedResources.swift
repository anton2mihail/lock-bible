import Foundation

/// Finds the data files that the app and the widget extension share.
///
/// This framework holds the only copy of the indexed rotation corpus (`Rotation/`). The app embeds it
/// in its `Frameworks` folder. The widget extension links it and loads it from the same folder through
/// `@rpath`. Both targets find the files through this framework's own bundle. Neither one reads the
/// other's bundle path. The framework uses Foundation only.
public enum SharedResources {
    private final class BundleToken {}

    /// The bundle of this framework.
    public static var bundle: Bundle { Bundle(for: BundleToken.self) }

    /// The directory that holds `<edition>.dat`, `.offsets`, `.ot`, `.nt`, and `.meta.json` for each edition.
    public static var rotationDirectory: URL? {
        bundle.resourceURL?.appendingPathComponent("Rotation", isDirectory: true)
    }
}
