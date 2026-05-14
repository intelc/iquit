import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    private let updaterController: SPUStandardUpdaterController?

    @Published private(set) var canCheckForUpdates = false

    init() {
        guard Self.hasUpdateConfiguration else {
            updaterController = nil
            return
        }

        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = updaterController

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController?.updater.checkForUpdates()
    }

    private static var hasUpdateConfiguration: Bool {
        let bundle = Bundle.main
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        return feedURL?.isEmpty == false && publicKey?.isEmpty == false
    }
}
