#!/usr/bin/env python3
"""Generate the tracked John Xcode project and shared schemes."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / "native/John/John.xcodeproj"
PROJECT.mkdir(parents=True, exist_ok=True)


def oid(name: str) -> str:
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

objects: dict[str, str] = {}
def add(name: str, body: str) -> str:
    key = oid(name)
    if key in objects:
        raise ValueError(f"duplicate project object: {name}")
    objects[key] = body
    return key


def q(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

project_id = oid("JohnProject")
app_target_id = oid("target-app")
widget_target_id = oid("target-widget")
ui_target_id = oid("target-ui-tests")
adapter_target_id = oid("target-legacy-adapter")
shared_target_id = oid("target-shared-resources")
app_product_id = oid("product:John.app")
widget_product_id = oid("product:JohnWidget.appex")
ui_product_id = oid("product:JohnUITests.xctest")
adapter_product_id = oid("product:libJohnLegacyAdapter.a")
shared_product_id = oid("product:JohnSharedResources.framework")

source_files = {
    "App": ["JohnApp.swift", "Runtime.swift"],
    "DesignSystem": ["Theme.swift", "FeatherIcon.swift", "FlatTabBar.swift", "AppComponents.swift"],
    "Features/Today": ["TodayModel.swift", "TodayView.swift"],
    "Features/Secondary": ["SecondaryRootView.swift", "DestinationView.swift", "SearchView.swift", "SavedView.swift"],
    "Features/Reader": ["ReaderScreenModel.swift", "ReaderView.swift", "GoToView.swift", "ReaderSelectionToolbar.swift"],
    "Features/Companion": ["CompanionRoute.swift", "ContentPage.swift", "CompanionTodayView.swift", "TeachingView.swift"],
    "Features/Prayers": ["PrayerHomeView.swift", "PrayerLibraryView.swift", "PrayerDetailView.swift"],
    "Features/Calendar": ["CalendarReadingsView.swift", "CitationContextView.swift"],
    "Features/Guides": ["ConfessionView.swift", "LectioView.swift", "NovenaView.swift", "RosaryGuideView.swift", "RosaryHomeView.swift"],
    "Features/Sharing": ["ScriptureCardView.swift"],
    "Features/Works": ["WorksRoute.swift", "WorksSupport.swift", "WorksLibraryView.swift", "WorksCollectionView.swift", "WorkReaderView.swift", "WorksChapterCommentaryView.swift"],
    "Features/Media": ["RosaryMediaModel.swift", "RosaryMediaView.swift"],
    "Features/Settings": ["FullSettingsView.swift"],
    "Features/Notifications": ["CalendarNotificationsView.swift", "FeatureTimePicker.swift", "RosaryReminderView.swift"],
    "Platform/Navigation": ["AppRouter.swift", "ExternalRouteParser.swift"],
    "Platform/Notifications": ["NoticeCenter.swift", "LocalNoticeService.swift", "L22ServiceComparison.swift"],
    "Platform/Media": ["RosaryCatalogModels.swift"],
    "Platform/Text": ["ScriptureTextView.swift"],
    "Widget": ["JohnWidget.swift"],
    "SharedResources": ["JohnSharedResources.swift"],
    "SimulatorSupport": [
        "NativeSmokeUITests.swift",
        "ContentFlowUITests.swift",
        "WorksSettingsUITests.swift",
        "MediaNotificationUITests.swift",
        "SearchNoteUITests.swift",
        "ScriptureCardUITests.swift",
        "AllRouteCaptureUITests.swift",
        "ReaderSelectionActionsUITests.swift",
        "ReaderParityUITests.swift",
        "LectioTimerUITests.swift",
        "CalendarBoundaryUITests.swift",
        "ReleasePerformanceUITests.swift",
        "PositiveNoticeUITests.swift",
        "WidgetHomeScreenUITests.swift",
        "StoreScreenshotUITests.swift",
    ],
}

# These Apple-platform source files match the iOS MMKVCore target. Keep the
# vendored project as the source authority and exclude its watch target.
mmkv_core_sources = [
    "ThreadLock.cpp", "MemoryFile_OSX.cpp", "KeyValueHolder.cpp", "MMKV.cpp",
    "CodedInputDataCrypt_OSX.cpp", "MiniPBCoder_OSX.cpp", "AESCrypt.cpp",
    "openssl_cfb128.cpp", "CodedOutputData.cpp", "openssl_md5_dgst.cpp",
    "openssl_aes-armv4.S", "CodedInputDataCrypt.cpp", "MemoryFile.cpp",
    "CodedInputData.cpp", "MMKVLog.cpp", "PBUtility.cpp", "MiniPBCoder.cpp",
    "MMKV_IO.cpp", "openssl_md5_one.cpp", "openssl_aes_core.cpp", "MMBuffer.cpp",
    "CodedInputData_OSX.cpp", "openssl_aesv8-armx.S", "MMKV_OSX.cpp",
    "InterProcessLock.cpp",
]

file_refs: dict[str, str] = {}
group_files: dict[str, list[str]] = {}
for group, files in source_files.items():
    children = []
    for filename in files:
        path = f"{group}/{filename}"
        ref = add(f"file:{path}", f"{{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(filename)}; sourceTree = \"<group>\"; }}")
        file_refs[path] = ref
        children.append(ref)
    group_files[group] = children

adapter_file_refs: dict[str, str] = {}
adapter_children = []
adapter_source_paths = ["LegacyMMKVAdapter.mm", *mmkv_core_sources]
for path in adapter_source_paths:
    is_wrapper = path == "LegacyMMKVAdapter.mm"
    vendor_path = f"aes/openssl/{path}" if path.startswith("openssl_") else f"aes/{path}" if path == "AESCrypt.cpp" else path
    source_path = f"LegacyAdapter/{path}" if is_wrapper else f"LegacyAdapter/Vendor/MMKVCore/{vendor_path}"
    ref = add(f"file:LegacyAdapter/{path}", f"{{ isa = PBXFileReference; lastKnownFileType = {'sourcecode.cpp.objcpp' if is_wrapper or path.endswith('.cpp') else 'sourcecode.asm'}; name = {q(path)}; path = {q(source_path)}; sourceTree = SOURCE_ROOT; }}")
    adapter_file_refs[path] = ref
    adapter_children.append(ref)
adapter_group_files = [
    ("root", adapter_children),
    ("vendor", []),
]

plist_refs = {}
for name, filetype in [
    ("App/Info.plist", "text.plist.xml"),
    ("Widget/Info.plist", "text.plist.xml"),
    ("SharedResources/Info.plist", "text.plist.xml"),
    ("Config/John-App-Development.entitlements", "text.plist.entitlements"),
    ("Config/John-App-Update.entitlements", "text.plist.entitlements"),
    ("Config/John-Widget-Development.entitlements", "text.plist.entitlements"),
    ("Config/John-Widget-Update.entitlements", "text.plist.entitlements"),
    ("Resources/Feather.ttf", "file"),
    ("Resources/Feather-LICENSE.txt", "text"),
]:
    ref = add(f"file:{name}", f"{{ isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(Path(name).name)}; sourceTree = \"<group>\"; }}")
    plist_refs[name] = ref

# The staged tree holds the rotation corpus twice: App/Rotation and Widget/<edition>.*. The corpus ships once, in
# JohnSharedResources.framework. A folder reference copies whole, and EXCLUDED_SOURCE_FILE_NAMES does not filter it.
# So the app copies each staged App subfolder except Rotation into App/<name>. The widget copies only its daily
# readings files into Widget/. The result keeps every existing bundle path.
staged_root = "../../build/native-evidence/L03/staged/run-10"
app_staged_folders = ["Artwork", "Bible", "Calendar", "Catalogs", "Databases", "Fonts"]
app_staged_refs = {name: add(f"resource:App/{name}", f'{{ isa = PBXFileReference; lastKnownFileType = folder; path = "{staged_root}/App/{name}"; sourceTree = SOURCE_ROOT; }}') for name in app_staged_folders}
rotation_resources_id = add("resource:Rotation", f'{{ isa = PBXFileReference; lastKnownFileType = folder; path = "{staged_root}/App/Rotation"; sourceTree = SOURCE_ROOT; }}')
widget_daily_years = range(2025, 2033)
widget_staged_refs = {year: add(f"resource:Widget/daily-readings-{year}", f'{{ isa = PBXFileReference; lastKnownFileType = text.json; path = "{staged_root}/Widget/daily-readings-{year}.json"; sourceTree = SOURCE_ROOT; }}') for year in widget_daily_years}

# Keep L28 app resources separate from the L03 Bible and Works corpus folders.
l28_asset_catalog_ref = add("resource:L28-Assets", '{ isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }')
l28_launch_storyboard_ref = add("resource:L28-LaunchStoryboard", '{ isa = PBXFileReference; lastKnownFileType = file.storyboard; path = Launch/SplashScreen.storyboard; sourceTree = "<group>"; }')
l28_legal_folder_ref = add("resource:L28-Legal", '{ isa = PBXFileReference; lastKnownFileType = folder; path = Legal; sourceTree = "<group>"; }')
l28_app_privacy_ref = add("resource:L28-AppPrivacy", '{ isa = PBXFileReference; lastKnownFileType = text.xml; path = App/PrivacyInfo.xcprivacy; sourceTree = "<group>"; }')
l28_widget_privacy_ref = add("resource:L28-WidgetPrivacy", '{ isa = PBXFileReference; lastKnownFileType = text.xml; path = Widget/PrivacyInfo.xcprivacy; sourceTree = "<group>"; }')

app_source_builds = [add(f"build-source-app:{p}", f"{{ isa = PBXBuildFile; fileRef = {file_refs[p]}; }}") for group in ("App", "DesignSystem", "Features/Today", "Features/Secondary", "Features/Reader", "Features/Companion", "Features/Prayers", "Features/Calendar", "Features/Guides", "Features/Sharing", "Features/Works", "Features/Media", "Features/Settings", "Features/Notifications", "Platform/Navigation", "Platform/Notifications", "Platform/Media", "Platform/Text") for p in [f"{group}/{name}" for name in source_files[group]]]
legacy_reader_ref = add("file:LegacyAdapter/LegacyMMKVReader.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = LegacyMMKVReader.swift; path = LegacyAdapter/LegacyMMKVReader.swift; sourceTree = SOURCE_ROOT; }')
legacy_reader_build = add("build-source-app:LegacyMMKVReader.swift", f"{{ isa = PBXBuildFile; fileRef = {legacy_reader_ref}; }}")
scenario_runner_ref = add("file:source-fixtures/L04ScenarioRunner.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = L04ScenarioRunner.swift; path = "../../scripts/native/source-fixtures/l04/L04ScenarioRunner.swift"; sourceTree = SOURCE_ROOT; }')
scenario_runner_build = add("build-source-app:L04ScenarioRunner.swift", f"{{ isa = PBXBuildFile; fileRef = {scenario_runner_ref}; }}")
recovery_runner_ref = add("file:source-fixtures/L04RecoveryScenarios.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = L04RecoveryScenarios.swift; path = "../../scripts/native/source-fixtures/l04/L04RecoveryScenarios.swift"; sourceTree = SOURCE_ROOT; }')
recovery_runner_build = add("build-source-app:L04RecoveryScenarios.swift", f"{{ isa = PBXBuildFile; fileRef = {recovery_runner_ref}; }}")
repository_runner_ref = add("file:source-fixtures/L04RepositoryRunner.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = L04RepositoryRunner.swift; path = "../../scripts/native/source-fixtures/l04/L04RepositoryRunner.swift"; sourceTree = SOURCE_ROOT; }')
repository_runner_build = add("build-source-app:L04RepositoryRunner.swift", f"{{ isa = PBXBuildFile; fileRef = {repository_runner_ref}; }}")
search_comparison_ref = add("file:source-fixtures/L09FixtureComparison.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = L09FixtureComparison.swift; path = "../../scripts/native/source-fixtures/l09/L09FixtureComparison.swift"; sourceTree = SOURCE_ROOT; }')
search_comparison_build = add("build-source-app:L09FixtureComparison.swift", f"{{ isa = PBXBuildFile; fileRef = {search_comparison_ref}; }}")
library_comparison_ref = add("file:source-fixtures/L10L11FixtureComparison.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = L10L11FixtureComparison.swift; path = "../../scripts/native/source-fixtures/library/L10L11FixtureComparison.swift"; sourceTree = SOURCE_ROOT; }')
library_comparison_build = add("build-source-app:L10L11FixtureComparison.swift", f"{{ isa = PBXBuildFile; fileRef = {library_comparison_ref}; }}")
notice_snapshot_ref = add("file:source-fixtures/SystemNoticeSnapshot.swift", '{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = SystemNoticeSnapshot.swift; path = "../../scripts/native/source-fixtures/notifications/SystemNoticeSnapshot.swift"; sourceTree = SOURCE_ROOT; }')
notice_snapshot_build = add("build-source-app:SystemNoticeSnapshot.swift", f"{{ isa = PBXBuildFile; fileRef = {notice_snapshot_ref}; }}")
app_source_builds.extend([legacy_reader_build, scenario_runner_build, recovery_runner_build, repository_runner_build, search_comparison_build, library_comparison_build, notice_snapshot_build])
shared_source_builds = [add(f"build-source-shared:{p}", f"{{ isa = PBXBuildFile; fileRef = {file_refs[p]}; }}") for p in [f"SharedResources/{name}" for name in source_files["SharedResources"]]]
widget_source_builds = [add(f"build-source-widget:{p}", f"{{ isa = PBXBuildFile; fileRef = {file_refs[p]}; }}") for p in [f"Widget/{name}" for name in source_files["Widget"]]]
ui_source_builds = [add(f"build-source-uitest:{p}", f"{{ isa = PBXBuildFile; fileRef = {file_refs[p]}; }}") for p in [f"SimulatorSupport/{name}" for name in source_files["SimulatorSupport"]]]
mmkv_no_arc = {"CodedInputDataCrypt.cpp", "MMKV_IO.cpp", "CodedOutputData.cpp", "MMKV.cpp", "MiniPBCoder.cpp", "MMBuffer.cpp", "CodedInputData.cpp"}
adapter_source_builds = []
for path in adapter_source_paths:
    settings = ' settings = { COMPILER_FLAGS = "-fno-objc-arc"; };' if path in mmkv_no_arc else ""
    adapter_source_builds.append(add(f"build-source-adapter:{path}", f"{{ isa = PBXBuildFile; fileRef = {adapter_file_refs[path]};{settings} }}"))
feather_build = add("build-resource-feather", f"{{ isa = PBXBuildFile; fileRef = {plist_refs['Resources/Feather.ttf']}; }}")
feather_license_build = add("build-resource-feather-license", f"{{ isa = PBXBuildFile; fileRef = {plist_refs['Resources/Feather-LICENSE.txt']}; }}")
app_staged_builds = [add(f"build-copy-app-{name}", f"{{ isa = PBXBuildFile; fileRef = {ref}; }}") for name, ref in app_staged_refs.items()]
rotation_resource_build = add("build-resource-shared-rotation-folder", f"{{ isa = PBXBuildFile; fileRef = {rotation_resources_id}; }}")
widget_staged_builds = [add(f"build-copy-widget-daily-{year}", f"{{ isa = PBXBuildFile; fileRef = {ref}; }}") for year, ref in widget_staged_refs.items()]
l28_asset_build = add("build-resource-L28-assets", f"{{ isa = PBXBuildFile; fileRef = {l28_asset_catalog_ref}; }}")
l28_launch_build = add("build-resource-L28-launch", f"{{ isa = PBXBuildFile; fileRef = {l28_launch_storyboard_ref}; }}")
l28_legal_build = add("build-resource-L28-legal", f"{{ isa = PBXBuildFile; fileRef = {l28_legal_folder_ref}; }}")
l28_app_privacy_build = add("build-resource-L28-app-privacy", f"{{ isa = PBXBuildFile; fileRef = {l28_app_privacy_ref}; }}")
l28_widget_privacy_build = add("build-resource-L28-widget-privacy", f"{{ isa = PBXBuildFile; fileRef = {l28_widget_privacy_ref}; }}")
app_package_ref = oid("JohnCoreLocalPackage")
app_package_dep = oid("JohnCoreAppProduct")
widget_package_dep = oid("JohnCoreWidgetProduct")
app_package_build = add("build-package-app", f"{{ isa = PBXBuildFile; productRef = {app_package_dep}; }}")
widget_package_build = add("build-package-widget", f"{{ isa = PBXBuildFile; productRef = {widget_package_dep}; }}")
adapter_product_build = add("build-link-adapter-app", f"{{ isa = PBXBuildFile; fileRef = {adapter_product_id}; }}")
adapter_foundation_ref = add("framework:Foundation", '{ isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Foundation.framework; path = System/Library/Frameworks/Foundation.framework; sourceTree = SDKROOT; }')
adapter_zlib_ref = add("framework:libz", '{ isa = PBXFileReference; lastKnownFileType = "sourcecode.text-based-dylib-definition"; name = "libz.tbd"; path = usr/lib/libz.tbd; sourceTree = SDKROOT; }')
adapter_libcxx_ref = add("framework:libc++", '{ isa = PBXFileReference; lastKnownFileType = "sourcecode.text-based-dylib-definition"; name = "libc++.tbd"; path = "usr/lib/libc++.tbd"; sourceTree = SDKROOT; }')
adapter_foundation_build = add("build-framework-adapter-foundation", f"{{ isa = PBXBuildFile; fileRef = {adapter_foundation_ref}; }}")
adapter_zlib_build = add("build-framework-adapter-zlib", f"{{ isa = PBXBuildFile; fileRef = {adapter_zlib_ref}; }}")
app_zlib_build = add("build-framework-app-zlib", f"{{ isa = PBXBuildFile; fileRef = {adapter_zlib_ref}; }}")
app_libcxx_build = add("build-framework-app-libcxx", f"{{ isa = PBXBuildFile; fileRef = {adapter_libcxx_ref}; }}")
shared_link_app_build = add("build-link-shared-app", f"{{ isa = PBXBuildFile; fileRef = {shared_product_id}; }}")
shared_link_widget_build = add("build-link-shared-widget", f"{{ isa = PBXBuildFile; fileRef = {shared_product_id}; }}")
shared_embed_build = add("build-embed-shared", f"{{ isa = PBXBuildFile; fileRef = {shared_product_id}; settings = {{ ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }}")
widget_embed_build = add("build-embed-widget", f"{{ isa = PBXBuildFile; fileRef = {widget_product_id}; settings = {{ ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }}")


def phase(phase_name: str, phase_type: str, files: list[str], **extra: str) -> str:
    items = ", ".join(files)
    file_list = f"({items}, )" if items else "()"
    fields = " ".join(f"{k} = {v};" for k, v in extra.items())
    return add(phase_name, f"{{ isa = {phase_type}; buildActionMask = 2147483647; files = {file_list}; {fields} runOnlyForDeploymentPostprocessing = 0; }}")

app_sources_phase = phase("phase-app-sources", "PBXSourcesBuildPhase", app_source_builds)
widget_sources_phase = phase("phase-widget-sources", "PBXSourcesBuildPhase", widget_source_builds)
ui_sources_phase = phase("phase-ui-sources", "PBXSourcesBuildPhase", ui_source_builds)
adapter_sources_phase = phase("phase-adapter-sources", "PBXSourcesBuildPhase", adapter_source_builds)
shared_sources_phase = phase("phase-shared-sources", "PBXSourcesBuildPhase", shared_source_builds)
shared_frameworks_phase = phase("phase-shared-frameworks", "PBXFrameworksBuildPhase", [])
shared_resources_phase = phase("phase-shared-resources", "PBXResourcesBuildPhase", [rotation_resource_build])
adapter_frameworks_phase = phase("phase-adapter-frameworks", "PBXFrameworksBuildPhase", [adapter_foundation_build, adapter_zlib_build])
app_frameworks_phase = phase("phase-app-frameworks", "PBXFrameworksBuildPhase", [app_package_build, adapter_product_build, app_zlib_build, app_libcxx_build, shared_link_app_build])
widget_frameworks_phase = phase("phase-widget-frameworks", "PBXFrameworksBuildPhase", [widget_package_build, shared_link_widget_build])
ui_frameworks_phase = phase("phase-ui-frameworks", "PBXFrameworksBuildPhase", [])
app_resources_phase = phase("phase-app-resources", "PBXResourcesBuildPhase", [feather_build, feather_license_build, l28_asset_build, l28_launch_build, l28_legal_build, l28_app_privacy_build])
widget_resources_phase = phase("phase-widget-resources", "PBXResourcesBuildPhase", [l28_widget_privacy_build])
ui_resources_phase = phase("phase-ui-resources", "PBXResourcesBuildPhase", [])
app_staged_phase = phase("phase-app-staged-copy", "PBXCopyFilesBuildPhase", app_staged_builds, dstPath='"App"', dstSubfolderSpec="7", name='"Copy Staged App Resources"')
widget_staged_phase = phase("phase-widget-staged-copy", "PBXCopyFilesBuildPhase", widget_staged_builds, dstPath='"Widget"', dstSubfolderSpec="7", name='"Copy Staged Widget Resources"')
embed_phase = phase("phase-embed-widget", "PBXCopyFilesBuildPhase", [widget_embed_build], dstPath='""', dstSubfolderSpec="13", name='"Embed App Extensions"')
# The only embedded copy of JohnSharedResources.framework. The widget links it and loads it from the app's Frameworks folder.
embed_frameworks_phase = phase("phase-embed-frameworks", "PBXCopyFilesBuildPhase", [shared_embed_build], dstPath='""', dstSubfolderSpec="10", name='"Embed Frameworks"')

app_config_ids = []
widget_config_ids = []
ui_config_ids = []
adapter_config_ids = []
shared_config_ids = []
project_config_ids = []

def build_config(name: str, settings: dict[str, str], config_id: str | None = None) -> str:
    body = " ".join(f"{key} = {value};" for key, value in settings.items())
    return add(f"config:{name}:{config_id or ''}", f"{{ isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {q(name)}; }}")

project_common = {
    "CLANG_ENABLE_MODULES": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
    "SDKROOT": "iphoneos",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": "6.0",
    "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
}
project_config_ids.extend([
    build_config("Debug", {**project_common, "DEBUG_INFORMATION_FORMAT": '"dwarf"', "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"', "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"'}, "project"),
    build_config("Release", {**project_common, "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"', "SWIFT_COMPILATION_MODE": "wholemodule", "SWIFT_OPTIMIZATION_LEVEL": '"-O"'}, "project"),
])
app_common = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": '"AppIcon"',
    "CODE_SIGN_STYLE": "Automatic",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": '"App/Info.plist"',
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "PRODUCT_NAME": '"John"',
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "ENABLE_PREVIEWS": "YES",
    "SWIFT_OBJC_BRIDGING_HEADER": '"LegacyAdapter/LegacyMMKVAdapter.h"',
}
app_config_ids.extend([
    build_config("Debug", {**app_common, "APP_GROUP_IDENTIFIER": '"group.com.nrsv.verse.dev"', "CODE_SIGN_ENTITLEMENTS": '"Config/John-App-Development.entitlements"', "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse.dev"', "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"'}, "app"),
    build_config("Release", {**app_common, "APP_GROUP_IDENTIFIER": '"group.com.nrsv.verse"', "CODE_SIGN_ENTITLEMENTS": '"Config/John-App-Update.entitlements"', "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse"'}, "app"),
])
widget_common = {
    "APPLICATION_EXTENSION_API_ONLY": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": '"Widget/Info.plist"',
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"',
    "PRODUCT_NAME": '"JohnWidget"',
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
widget_config_ids.extend([
    build_config("Debug", {**widget_common, "APP_GROUP_IDENTIFIER": '"group.com.nrsv.verse.dev"', "CODE_SIGN_ENTITLEMENTS": '"Config/John-Widget-Development.entitlements"', "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse.dev.widget"', "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"'}, "widget"),
    build_config("Release", {**widget_common, "APP_GROUP_IDENTIFIER": '"group.com.nrsv.verse"', "CODE_SIGN_ENTITLEMENTS": '"Config/John-Widget-Update.entitlements"', "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse.widget"'}, "widget"),
])
shared_common = {
    "APPLICATION_EXTENSION_API_ONLY": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "DEFINES_MODULE": "YES",
    "DYLIB_INSTALL_NAME_BASE": '"@rpath"',
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": '"SharedResources/Info.plist"',
    "INSTALL_PATH": '"$(LOCAL_LIBRARY_DIR)/Frameworks"',
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks @loader_path/Frameworks"',
    "MACH_O_TYPE": "mh_dylib",
    "PRODUCT_NAME": '"JohnSharedResources"',
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
shared_config_ids.extend([
    build_config("Debug", {**shared_common, "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse.dev.sharedresources"', "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"'}, "shared"),
    build_config("Release", {**shared_common, "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse.sharedresources"'}, "shared"),
])
ui_common = {
    "GENERATE_INFOPLIST_FILE": "YES",
    "PRODUCT_BUNDLE_IDENTIFIER": '"com.nrsv.verse.dev.uitests"',
    "PRODUCT_NAME": '"JohnUITests"',
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "TEST_TARGET_NAME": '"John"',
}
ui_config_ids.extend([
    build_config("Debug", {**ui_common, "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"'}, "ui"),
    build_config("Release", ui_common, "ui"),
])
adapter_common = {
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_CXX_LIBRARY": '"libc++"',
    "GCC_PREPROCESSOR_DEFINITIONS": '"$(inherited) FORCE_POSIX=1"',
    "HEADER_SEARCH_PATHS": '"$(inherited) $(SRCROOT)/LegacyAdapter/Vendor/MMKVCore $(SRCROOT)/LegacyAdapter/Vendor/MMKVCore/aes $(SRCROOT)/LegacyAdapter/Vendor/MMKVCore/aes/openssl $(SRCROOT)/LegacyAdapter/Vendor/MMKVCore/crc32"',
    "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
    "MACH_O_TYPE": "staticlib",
    "PRODUCT_NAME": '"JohnLegacyAdapter"',
    "SKIP_INSTALL": "YES",
    "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator"',
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
adapter_config_ids.extend([
    build_config("Debug", {**adapter_common, "GCC_PREPROCESSOR_DEFINITIONS": '"$(inherited) FORCE_POSIX=1 DEBUG=1"', "GCC_OPTIMIZATION_LEVEL": "0"}, "adapter-debug"),
    build_config("Release", adapter_common, "adapter-release"),
])


def config_list(name: str, ids: list[str]) -> str:
    return add(name, f"{{ isa = XCConfigurationList; buildConfigurations = ({', '.join(ids)}, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}")

project_config_list = config_list("config-list-project", project_config_ids)
app_config_list = config_list("config-list-app", app_config_ids)
widget_config_list = config_list("config-list-widget", widget_config_ids)
ui_config_list = config_list("config-list-ui", ui_config_ids)
adapter_config_list = config_list("config-list-adapter", adapter_config_ids)
shared_config_list = config_list("config-list-shared", shared_config_ids)

products_group = add("group-products", f"{{ isa = PBXGroup; children = ({app_product_id}, {widget_product_id}, {ui_product_id}, {adapter_product_id}, {shared_product_id}, ); name = Products; sourceTree = \"<group>\"; }}")
app_product = add("product:John.app", '{ isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = John.app; sourceTree = BUILT_PRODUCTS_DIR; }')
widget_product = add("product:JohnWidget.appex", '{ isa = PBXFileReference; explicitFileType = wrapper.app-extension; includeInIndex = 0; path = JohnWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }')
ui_product = add("product:JohnUITests.xctest", '{ isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = JohnUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }')
shared_product = add("product:JohnSharedResources.framework", '{ isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = JohnSharedResources.framework; sourceTree = BUILT_PRODUCTS_DIR; }')
adapter_product = add("product:libJohnLegacyAdapter.a", '{ isa = PBXFileReference; explicitFileType = archive.ar; includeInIndex = 0; path = libJohnLegacyAdapter.a; sourceTree = BUILT_PRODUCTS_DIR; }')
# Keep stable IDs for product references used by targets.
if app_product != app_product_id or widget_product != widget_product_id or ui_product != ui_product_id or adapter_product != adapter_product_id or shared_product != shared_product_id:
    raise ValueError("product ID generation changed")

# Group paths are relative to SRCROOT, not the .xcodeproj directory.
group_ids = {}
group_files["SharedResources"] = group_files["SharedResources"] + [plist_refs["SharedResources/Info.plist"]]
for group, children in group_files.items():
    group_ids[group] = add(f"group:{group}", f"{{ isa = PBXGroup; children = ({', '.join(children)}, ); path = {q(group)}; sourceTree = \"<group>\"; }}")
config_group = add("group:Config", f"{{ isa = PBXGroup; children = ({', '.join(plist_refs[n] for n in plist_refs if n.startswith('Config/'))}, ); path = Config; sourceTree = \"<group>\"; }}")
app_info_ref = plist_refs["App/Info.plist"]
widget_info_ref = plist_refs["Widget/Info.plist"]
app_children = group_files["App"] + [app_info_ref]
app_group = add("group:AppPlist", f"{{ isa = PBXGroup; children = ({', '.join(app_children)}, ); path = App; sourceTree = \"<group>\"; }}")
widget_group = add("group:WidgetInfo", f"{{ isa = PBXGroup; children = ({widget_info_ref}, ); path = Widget; sourceTree = \"<group>\"; }}")
resources_group = add("group:Resources", f"{{ isa = PBXGroup; children = ({plist_refs['Resources/Feather.ttf']}, {plist_refs['Resources/Feather-LICENSE.txt']}, ); path = Resources; sourceTree = \"<group>\"; }}")
staged_children = ", ".join([*app_staged_refs.values(), rotation_resources_id, *widget_staged_refs.values()])
staged_group = add("group:Staged", f"{{ isa = PBXGroup; children = ({staged_children}, ); name = \"Staged Resources\"; sourceTree = \"<group>\"; }}")
release_resources_group = add("group:ReleaseResources", f"{{ isa = PBXGroup; children = ({l28_asset_catalog_ref}, {l28_launch_storyboard_ref}, {l28_legal_folder_ref}, {l28_app_privacy_ref}, {l28_widget_privacy_ref}, ); name = \"L28 Release Resources\"; path = \"Resources/Release/Resources\"; sourceTree = \"<group>\"; }}")
core_group = add("group:JohnCore", '{ isa = PBXGroup; children = (); name = JohnCore; path = Packages/JohnCore; sourceTree = SOURCE_ROOT; }')
adapter_group = add("group:LegacyAdapter", f"{{ isa = PBXGroup; children = ({legacy_reader_ref}, {', '.join(adapter_children)}, {adapter_foundation_ref}, {adapter_zlib_ref}, {adapter_libcxx_ref}, ); name = LegacyAdapter; path = LegacyAdapter; sourceTree = \"<group>\"; }}")
scenario_group = add("group:ScenarioRunner", f"{{ isa = PBXGroup; children = ({scenario_runner_ref}, {recovery_runner_ref}, {repository_runner_ref}, ); name = \"L04 simulator scenarios\"; sourceTree = \"<group>\"; }}")
main_children = [app_group, group_ids["DesignSystem"], group_ids["Features/Today"], group_ids["Features/Secondary"], group_ids["Features/Reader"], group_ids["Features/Companion"], group_ids["Features/Prayers"], group_ids["Features/Calendar"], group_ids["Features/Guides"], group_ids["Features/Sharing"], group_ids["Features/Works"], group_ids["Features/Media"], group_ids["Features/Settings"], group_ids["Features/Notifications"], group_ids["Platform/Navigation"], group_ids["Platform/Notifications"], group_ids["Platform/Media"], group_ids["Platform/Text"], widget_group, group_ids["Widget"], group_ids["SharedResources"], group_ids["SimulatorSupport"], config_group, resources_group, staged_group, release_resources_group, core_group, adapter_group, scenario_group, products_group]
main_group = add("group-main", f"{{ isa = PBXGroup; children = ({', '.join(main_children)}, ); sourceTree = \"<group>\"; }}")

container_proxy = add("proxy-app-embeds-widget", f"{{ isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {widget_target_id}; remoteInfo = JohnWidget; }}")
widget_dependency = add("dependency-app-widget", f"{{ isa = PBXTargetDependency; target = {widget_target_id}; targetProxy = {container_proxy}; }}")
adapter_proxy = add("proxy-app-adapter", f"{{ isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {adapter_target_id}; remoteInfo = JohnLegacyAdapter; }}")
adapter_dependency = add("dependency-app-adapter", f"{{ isa = PBXTargetDependency; target = {adapter_target_id}; targetProxy = {adapter_proxy}; }}")
shared_app_proxy = add("proxy-app-shared", f"{{ isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {shared_target_id}; remoteInfo = JohnSharedResources; }}")
shared_app_dependency = add("dependency-app-shared", f"{{ isa = PBXTargetDependency; target = {shared_target_id}; targetProxy = {shared_app_proxy}; }}")
shared_widget_proxy = add("proxy-widget-shared", f"{{ isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {shared_target_id}; remoteInfo = JohnSharedResources; }}")
shared_widget_dependency = add("dependency-widget-shared", f"{{ isa = PBXTargetDependency; target = {shared_target_id}; targetProxy = {shared_widget_proxy}; }}")

app_target = add("target-app", f"{{ isa = PBXNativeTarget; buildConfigurationList = {app_config_list}; buildPhases = ({app_sources_phase}, {app_frameworks_phase}, {app_resources_phase}, {app_staged_phase}, {embed_phase}, {embed_frameworks_phase}, ); buildRules = (); dependencies = ({widget_dependency}, {adapter_dependency}, {shared_app_dependency}, ); name = John; packageProductDependencies = ({app_package_dep}, ); productName = John; productReference = {app_product_id}; productType = \"com.apple.product-type.application\"; }}")
widget_target = add("target-widget", f"{{ isa = PBXNativeTarget; buildConfigurationList = {widget_config_list}; buildPhases = ({widget_sources_phase}, {widget_frameworks_phase}, {widget_resources_phase}, {widget_staged_phase}, ); buildRules = (); dependencies = ({shared_widget_dependency}, ); name = JohnWidget; packageProductDependencies = ({widget_package_dep}, ); productName = JohnWidget; productReference = {widget_product_id}; productType = \"com.apple.product-type.app-extension\"; }}")
ui_target = add("target-ui-tests", f"{{ isa = PBXNativeTarget; buildConfigurationList = {ui_config_list}; buildPhases = ({ui_sources_phase}, {ui_frameworks_phase}, {ui_resources_phase}, ); buildRules = (); dependencies = (); name = JohnUITests; packageProductDependencies = (); productName = JohnUITests; productReference = {ui_product_id}; productType = \"com.apple.product-type.bundle.ui-testing\"; }}")
adapter_target = add("target-legacy-adapter", f"{{ isa = PBXNativeTarget; buildConfigurationList = {adapter_config_list}; buildPhases = ({adapter_sources_phase}, {adapter_frameworks_phase}, ); buildRules = (); dependencies = (); name = JohnLegacyAdapter; packageProductDependencies = (); productName = JohnLegacyAdapter; productReference = {adapter_product_id}; productType = \"com.apple.product-type.library.static\"; }}")

shared_target = add("target-shared-resources", f"{{ isa = PBXNativeTarget; buildConfigurationList = {shared_config_list}; buildPhases = ({shared_sources_phase}, {shared_frameworks_phase}, {shared_resources_phase}, ); buildRules = (); dependencies = (); name = JohnSharedResources; packageProductDependencies = (); productName = JohnSharedResources; productReference = {shared_product_id}; productType = \"com.apple.product-type.framework\"; }}")

objects[app_product_id] = objects.pop(app_product)
objects[widget_product_id] = objects.pop(widget_product)
objects[ui_product_id] = objects.pop(ui_product)
objects[adapter_product_id] = objects.pop(adapter_product)
objects[shared_product_id] = objects.pop(shared_product)

objects[app_package_ref] = '{ isa = XCLocalSwiftPackageReference; relativePath = Packages/JohnCore; }'
objects[app_package_dep] = f'{{ isa = XCSwiftPackageProductDependency; package = {app_package_ref}; productName = JohnCore; }}'
objects[widget_package_dep] = f'{{ isa = XCSwiftPackageProductDependency; package = {app_package_ref}; productName = JohnCore; }}'

objects[project_id] = f'''{{ isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 2660; TargetAttributes = {{ {app_target} = {{ CreatedOnToolsVersion = 26.6; }}; {widget_target} = {{ CreatedOnToolsVersion = 26.6; }}; {ui_target} = {{ CreatedOnToolsVersion = 26.6; TestTargetID = {app_target}; }}; {adapter_target} = {{ CreatedOnToolsVersion = 26.6; }}; {shared_target} = {{ CreatedOnToolsVersion = 26.6; }}; }}; }}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 15.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, ); mainGroup = {main_group}; packageReferences = ({app_package_ref}, ); productRefGroup = {products_group}; projectDirPath = ""; projectRoot = ""; targets = ({app_target}, {widget_target}, {ui_target}, {adapter_target}, {shared_target}, ); }}'''

header = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 60;\n\tobjects = {\n"
body = "".join(f"\t\t{k} = {v};\n" for k, v in sorted(objects.items()))
footer = f"\t}};\n\trootObject = {project_id};\n}}\n"
(PROJECT / "project.pbxproj").write_text(header + body + footer)

scheme_dir = PROJECT / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
def scheme(name: str, config: str, include_tests: bool) -> str:
    test_action = f'''<TestAction buildConfiguration="{config}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="JohnUITests.xctest" BlueprintName="JohnUITests" ReferencedContainer="container:John.xcodeproj" /></TestableReference></Testables></TestAction>''' if include_tests else f'<TestAction buildConfiguration="{config}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" />'
    return f'''<?xml version="1.0" encoding="UTF-8"?>\n<Scheme LastUpgradeVersion="2660" version="1.7">\n  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="John.app" BlueprintName="John" ReferencedContainer="container:John.xcodeproj" /></BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{widget_target}" BuildableName="JohnWidget.appex" BlueprintName="JohnWidget" ReferencedContainer="container:John.xcodeproj" /></BuildActionEntry></BuildActionEntries></BuildAction>\n  {test_action}\n  <LaunchAction buildConfiguration="{config}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="John.app" BlueprintName="John" ReferencedContainer="container:John.xcodeproj" /></BuildableProductRunnable></LaunchAction>\n  <ProfileAction buildConfiguration="{config}" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="John.app" BlueprintName="John" ReferencedContainer="container:John.xcodeproj" /></BuildableProductRunnable></ProfileAction>\n  <AnalyzeAction buildConfiguration="{config}" />\n  <ArchiveAction buildConfiguration="{config}" revealInOrganizer="YES" />\n</Scheme>\n'''
(scheme_dir / "John Development.xcscheme").write_text(scheme("John Development", "Debug", True))
(scheme_dir / "John Update.xcscheme").write_text(scheme("John Update", "Release", False))
