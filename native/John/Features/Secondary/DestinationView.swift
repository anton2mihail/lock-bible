import SwiftUI
import UIKit
import JohnCore

struct DestinationView: View {
    let route: AppRoute
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch route {
        case .reader(let request, let sourceID):
            ReaderView(pushedRequest: request)
                .toolbar(.hidden, for: .navigationBar)
                .readerZoomDestination(sourceID: sourceID)
        case .search:
            SearchView()
        case .companion(let route):
            companionDestination(route)
        case .noteEditor(let passage):
            SavedNoteEditor(passage: passage, onSaved: {}, onClose: { router.pop() })
        case .goTo(let bookCode, let chapter):
            GoToView(initialBookCode: bookCode, initialChapter: chapter)
        case .works:
            WorksLibraryView(onOpenCollection: { router.push(.workCollection($0)) },
                             onOpenWork: { workID, section in router.push(.workReader(workID: workID, section: section)) })
        case .daily(let value):
            CalendarReadingsView(sunday: false, initialDateKey: value,
                                 timeZone: runtime.featureTimeZone, clock: { runtime.featureNow() },
                                 onNavigate: navigate)
        case .sunday:
            CalendarReadingsView(sunday: true, timeZone: runtime.featureTimeZone,
                                 clock: { runtime.featureNow() }, onNavigate: navigate)
        case .rosaryGuide(let id):
            RosaryGuideView(requestedSet: id, clock: { runtime.featureNow() },
                            timeZone: runtime.featureTimeZone, onClose: router.pop)
        case .prayer(let id):
            PrayerDetailView(id: id, onNavigate: navigate)
        case .novena(let id):
            NovenaView(id: id)
        case .verseMoment(let selection):
            VerseMomentDestination(selection: selection)
        case .calendarNotifications:
            CalendarNotificationsView(
                initialSettings: runtime.committedNativeState?.calendarNotifications ?? CalendarNotificationSettings(),
                onSave: { try await runtime.saveCalendarNotifications($0) },
                onOpenSystemSettings: openNotificationSettings
            )
        case .rosaryReminder:
            RosaryReminderView(
                initialSettings: runtime.committedNativeState?.rosaryReminder ?? RosaryReminderSettings(),
                onSave: { try await runtime.saveRosaryReminder($0) },
                readCommittedSettings: { runtime.committedNativeState?.rosaryReminder ?? RosaryReminderSettings() }
            )
        case .learn:
            TeachingView(id: nil, onNavigate: navigate)
        case .confession:
            ConfessionView(onClose: router.pop)
        case .rosaryMedia:
            RosaryMediaDestination(episodeID: mediaEpisodeID(route))
        case .workCollection(let id):
            WorksCollectionView(collectionID: id,
                                onOpenWork: { workID, section in router.push(.workReader(workID: workID, section: section)) })
        case .workReader(let workID, let section):
            WorkReaderView(workID: workID, requestedSection: section,
                           onOpenChapterCommentary: { code, chapter, name in
                               router.push(.worksChapterCommentary(bookCode: code, chapter: chapter, bookName: name))
                           })
        case .worksChapterCommentary(let bookCode, let chapter, let bookName):
            WorksChapterCommentaryView(bookCode: bookCode, chapter: chapter, bookName: bookName,
                                       onOpenWork: { workID, section in router.push(.workReader(workID: workID, section: section)) })
            }
        }
        // The system glass back button is the one way back. An empty inline title keeps the bar slim over the page.
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func companionDestination(_ route: CompanionRoute) -> some View {
        switch route {
        case .prayerHome:
            PrayerHomeView(timeZone: runtime.featureTimeZone, clock: { runtime.featureNow() },
                           onNavigate: navigate)
        case .saints:
            SaintsCalendarView()
        case .daily(let dateKey):
            CalendarReadingsView(sunday: false, initialDateKey: dateKey,
                                 timeZone: runtime.featureTimeZone, clock: { runtime.featureNow() },
                                 onNavigate: navigate)
        case .sunday:
            CalendarReadingsView(sunday: true, timeZone: runtime.featureTimeZone,
                                 clock: { runtime.featureNow() }, onNavigate: navigate)
        case .citationContext(let reference):
            CitationContextView(reference: reference,
                                onOpenSearch: { router.push(.search) },
                                onOpenLectio: { router.push(.companion(.lectio($0))) })
        case .prayers:
            PrayerLibraryView(onNavigate: navigate)
        case .prayer(let id):
            PrayerDetailView(id: id, onNavigate: navigate)
        case .learn:
            TeachingView(id: nil, onNavigate: navigate)
        case .teaching(let id):
            TeachingView(id: id, onNavigate: navigate)
        case .novena(let id):
            NovenaView(id: id)
        case .rosaryHome:
            RosaryHomeView(clock: { runtime.featureNow() }, timeZone: runtime.featureTimeZone,
                           onOpenGuide: { router.push(.companion(.rosaryGuide(set: $0))) },
                           onOpenReminder: { router.push(.rosaryReminder) },
                           onOpenMedia: { router.push(.rosaryMedia($0)) })
        case .rosaryGuide(let set):
            RosaryGuideView(requestedSet: set, clock: { runtime.featureNow() },
                            timeZone: runtime.featureTimeZone, onClose: router.pop)
        case .lectio(let passage):
            LectioView(initialPassage: passage, onClose: router.pop,
                       onOpenReader: { router.openReader(passage: $0) },
                       onOpenBible: openBibleRoot)
        case .confession:
            ConfessionView(onClose: router.pop)
        case .scriptureCard(let passage):
            ScriptureCardView(passage: passage)
        }
    }

    private func navigate(_ route: CompanionRoute) { router.push(.companion(route)) }

    private func openBibleRoot() {
        router.select(.read)
        router.setPath([], for: .read)
    }

    @MainActor private func openNotificationSettings() async throws {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              await UIApplication.shared.open(url) else {
            throw LocalNoticeError.permissionDenied("Open your device’s Settings app to manage notification permissions.")
        }
    }

    private func open(_ reference: String) {
        Task {
            if let passage = await runtime.passage(reference: reference, translation: preferences.translation) {
                router.openReader(passage: passage)
            }
        }
    }

    private func mediaEpisodeID(_ route: AppRoute) -> String? {
        guard case let .rosaryMedia(episodeID) = route else { return nil }
        return episodeID
    }
}

private struct RosaryMediaDestination: View {
    let episodeID: String?
    @Environment(JohnRuntime.self) private var runtime
    @Environment(\.openURL) private var openURL
    @State private var catalog: RosaryHomeCatalog?
    @State private var failed = false

    var body: some View {
        Group {
            if let catalog {
                RosaryMediaView(episodeID: episodeID, catalog: catalog) { url in
                    _ = openURL(url)
                }
            } else if failed {
                CompanionPage(title: "Rosary series", eyebrow: "Word on Fire", subtitle: "The series information could not be opened.") {}
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await loadCatalog() }
            }
        }
    }

    @MainActor private func loadCatalog() async {
        guard let repository = runtime.companionRepository else { failed = true; return }
        do {
            let source = try await repository.devotionalCatalog()
            catalog = try RosaryCatalogAdapter.decode(source.rosary)
        } catch {
            failed = true
        }
    }
}

private struct VerseMomentDestination: View {
    let selection: VerseMomentSelection
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var passage: PassageSelection?
    @State private var metadata: BibleTranslationMetadata?
    @State private var refreshedVerse: RotatingVerse?
    @State private var countdown = ""
    @State private var showWidgetSteps = false
    @State private var saveMessage: String?
    @State private var savingDismissal = false
    @State private var passageRequestID = UUID()

    private var verse: RotatingVerse { refreshedVerse ?? selection.verse }
    private var guideDismissed: Bool { runtime.committedNativeState?.widgetGuideDismissed ?? false }
    var body: some View {
        ContentPage(title: "Verse of the moment", eyebrow: "\(countdown)",
                    subtitle: "") {
            if guideDismissed == false {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Put Scripture on your lock screen")
                            .font(JohnTypography.sans(18, weight: .semibold))
                        Text("Your Bible and rotating verses work completely offline. Add the widget to keep Scripture visible throughout the day.")
                            .font(JohnTypography.sans(13))
                            .foregroundStyle(preferences.colors(for: colorScheme).textDim)
                        if showWidgetSteps {
                            Text("1. Touch and hold your lock screen, then tap Customize.\n2. Tap the box under the clock and choose John 1:1.\n3. Add Daily Verse for rotating Scripture, Daily Reading for today’s Gospel, or both.\n4. Use the rectangular size when you want the full verse text.")
                                .font(JohnTypography.sans(13))
                        }
                        HStack {
                            ContentButton(title: showWidgetSteps ? "Hide steps" : "How to add it") {
                                showWidgetSteps.toggle()
                            }
                            Button {
                                dismissGuide()
                            } label: {
                                Text(savingDismissal ? "Saving…" : "Got it")
                                    .font(JohnTypography.sans(14, weight: .semibold))
                                    .foregroundStyle(preferences.colors(for: colorScheme).tint)
                            }
                            .disabled(savingDismissal)
                            .accessibilityIdentifier("verse-widget-guide-dismiss")
                        }
                    }
                }
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("“\(verse.text)”")
                        .font(JohnTypography.serif(24))
                        .foregroundStyle(preferences.colors(for: colorScheme).text)
                        .textSelection(.enabled)
                    Text(verse.reference)
                        .font(JohnTypography.sans(15, weight: .semibold))
                        .foregroundStyle(preferences.colors(for: colorScheme).tint)
                    Text(metadata?.abbreviation ?? selection.translation.rawValue.uppercased())
                        .font(JohnTypography.sans(12, weight: .medium))
                        .foregroundStyle(preferences.colors(for: colorScheme).textDim)
                    if let attribution = metadata?.attribution {
                        Text(attribution)
                            .font(JohnTypography.sans(11))
                            .foregroundStyle(preferences.colors(for: colorScheme).textDim)
                    }
                }
            }
            HStack(spacing: 12) {
                ScriptureShareLink(text: verse.text, reference: verse.reference,
                                   translationLabel: metadata?.abbreviation ?? selection.translation.rawValue.uppercased()) {
                    Text("Share")
                        .font(JohnTypography.sans(14, weight: .semibold))
                        .foregroundStyle(preferences.colors(for: colorScheme).card)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(preferences.colors(for: colorScheme).tint, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("verse-moment-share")
                if let passage {
                    ContentButton(title: "Read in context") { router.openReader(passage: passage) }
                        .accessibilityIdentifier("verse-moment-read-context")
                }
            }
            if let passage {
                ContentButton(title: "Create a Scripture card") {
                    router.push(.companion(.scriptureCard(passage)))
                }
                .accessibilityIdentifier("verse-moment-scripture-card")
            }
            if let saveMessage { ContentMutedText(text: saveMessage) }
        }
        .task(id: "\(selection.translation.rawValue)|\(verse.reference)") {
            await loadPassageAndMetadata()
        }
        .task(id: "\(selection.translation.rawValue)|\(preferences.scope.rawValue)|\(preferences.intervalMinutes)") {
            await updateCountdownUntilCancelled()
        }
    }

    @MainActor private func loadPassageAndMetadata() async {
        let requestID = UUID()
        passageRequestID = requestID
        let requestedVerse = verse
        let requestedTranslation = selection.translation
        passage = nil
        metadata = nil
        async let loadedPassage = runtime.passage(translation: requestedTranslation, bookCode: requestedVerse.bookCode,
                                                  chapter: requestedVerse.chapter, startVerse: requestedVerse.verseLabel,
                                                  endVerse: requestedVerse.verseLabel)
        async let loadedMetadata = runtime.translationMetadata(requestedTranslation)
        let (resolvedPassage, resolvedMetadata) = await (loadedPassage, loadedMetadata)
        guard !Task.isCancelled, passageRequestID == requestID,
              verse == requestedVerse, selection.translation == requestedTranslation else { return }
        passage = resolvedPassage
        metadata = resolvedMetadata
    }

    @MainActor private func updateCountdownUntilCancelled() async {
        while !Task.isCancelled {
            let now = runtime.featureNow()
            let zone = runtime.featureTimeZone
            if let nextVerse = await runtime.rotatingVerse(
                at: now,
                timeZone: zone,
                translation: selection.translation,
                scope: preferences.scope,
                intervalMinutes: preferences.intervalMinutes
            ), nextVerse.reference != verse.reference {
                passage = nil
                metadata = nil
                refreshedVerse = nextVerse
            }
            do {
                let next = try RotationMath.nextBoundary(after: now, utcOffsetSeconds: zone.secondsFromGMT(for: now),
                                                         intervalMinutes: preferences.intervalMinutes)
                let minutes = max(0, Int((next.timeIntervalSince(now) / 60).rounded()))
                let hours = minutes / 60
                let remainder = minutes % 60
                if hours == 0 { countdown = "New verse in \(remainder) min" }
                else if remainder == 0 { countdown = "New verse in \(hours)h" }
                else { countdown = "New verse in \(hours)h \(remainder)m" }
            } catch {
                countdown = ""
            }
            do { try await Task.sleep(for: .seconds(30)) }
            catch { return }
        }
    }

    @MainActor private func dismissGuide() {
        guard !savingDismissal else { return }
        savingDismissal = true
        Task { @MainActor in
            let success = await runtime.applyWithResult(.setWidgetGuideDismissed(true))
            if !success { saveMessage = "The guide could not be saved. Try again." }
            savingDismissal = false
        }
    }
}
