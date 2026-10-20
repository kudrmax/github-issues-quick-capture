import AppKit
import IssueBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shortcut = GlobalHotKey.Shortcut.controlOptionI

    private var panelController: PanelController?
    private var statusItemController: StatusItemController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()

        let gh = ProcessGHExecutor()
        let imageCache = DiskImageCache()
        let tracker = GHIssueTracker(gh: gh)
        let model = IssueBarViewModel(
            tracker: tracker,
            submitter: IssueSubmitter(tracker: tracker, uploader: GHAttachmentUploader(gh: gh)),
            imageLoader: GitHubImageLoader(gh: gh, cache: imageCache),
            recents: UserDefaultsRecentRepositoriesStore(),
            cache: FileRepositoryCache(),
            detailStore: FileIssueDetailCache(),
            system: AppKitSystemActions()
        )
        let panelController = PanelController(model: model)
        let togglePanel = { panelController.toggle() }

        hotKey = GlobalHotKey(shortcut: Self.shortcut, action: togglePanel)
        statusItemController = StatusItemController(
            shortcut: Self.shortcut,
            actions: .init(
                togglePanel: togglePanel,
                refreshRepositories: { model.refreshRepositories() },
                clearImageCache: { imageCache.removeAll() }
            )
        )
        self.panelController = panelController

        model.start()
        if CommandLine.arguments.contains("--show") {
            panelController.show()
        }
    }
}
