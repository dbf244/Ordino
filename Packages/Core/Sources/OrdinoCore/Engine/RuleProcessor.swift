import Foundation

/// Why an action could not run. The file is left where it was.
public enum ActionFailure: Error, Sendable, Hashable {
    /// The destination folder's bookmark no longer gives access.
    case destinationUnavailable(String)
    case moveFailed(FileMoverError)
}

/// Runs the matching rules' actions on one file, in order.
///
/// After a move, later actions and rules apply to the file at its new place.
/// If an action fails, nothing after it runs and the failure is reported.
public struct RuleProcessor: Sendable {
    private let resolveFolder: @Sendable (UUID) async -> URL?

    /// - Parameter resolveFolder: the accessible URL of a granted folder, or
    ///   `nil` if it is not available.
    public init(resolveFolder: @escaping @Sendable (UUID) async -> URL?) {
        self.resolveFolder = resolveFolder
    }

    /// Returns what happened: one `.fileMoved` per move, or a final `.actionFailed`.
    public func process(_ url: URL, rules: [Rule]) async -> [FolderActivity] {
        guard let facts = FileFacts.read(url) else { return [] }
        var current = url
        var activity: [FolderActivity] = []
        for rule in Evaluator.matchingRules(for: facts, in: rules) {
            for action in rule.actions {
                switch await run(action, on: current) {
                case .success(let moved):
                    activity.append(.fileMoved(from: current, to: moved, rule: rule.name))
                    current = moved
                case .failure(let failure):
                    activity.append(.actionFailed(current, rule: rule.name, reason: failure))
                    return activity
                }
            }
        }
        return activity
    }

    private func run(_ action: RuleAction, on file: URL) async -> Result<URL, ActionFailure> {
        switch action {
        case .move(let destination):
            guard let folder = await resolveFolder(destination.folderID) else {
                return .failure(.destinationUnavailable(destination.displayPath))
            }
            do {
                return .success(try FileMover.move(file, into: folder))
            } catch let error as FileMoverError {
                return .failure(.moveFailed(error))
            } catch {
                return .failure(.moveFailed(.moveFailed(error.localizedDescription)))
            }
        }
    }
}
