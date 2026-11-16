import BitwardenKit
import BitwardenSdk
import Foundation

// MARK: - CipherBulkOutcome

/// The result of a delete or move over several ciphers: every id is tried on its own, so a failure
/// never leaves the rest untouched and the caller can report exactly what happened.
struct CipherBulkOutcome: Equatable {
    /// The ids that were processed.
    var succeededIds = [String]()

    /// The ids that failed (cipher not found or the repository threw).
    var failedIds = [String]()

    /// Whether every id was processed.
    var isComplete: Bool { failedIds.isEmpty }
}

// MARK: - CipherBulkActions

/// Delete and move for several ciphers, shared by the group list and the home search results.
enum CipherBulkActions {
    /// Deletes the ciphers: soft delete (to the trash) or permanent (inside the trash).
    ///
    /// A cipher that cannot be fetched counts as failed (never as deleted).
    static func delete(
        ids: [String],
        permanent: Bool,
        repository: VaultRepository,
        errorReporter: ErrorReporter,
    ) async -> CipherBulkOutcome {
        var outcome = CipherBulkOutcome()
        for id in ids {
            do {
                if permanent {
                    try await repository.deleteCipher(id)
                } else if let cipher = try await repository.fetchCipher(withId: id) {
                    try await repository.softDeleteCipher(cipher)
                } else {
                    outcome.failedIds.append(id)
                    continue
                }
                outcome.succeededIds.append(id)
            } catch {
                errorReporter.log(error: error)
                outcome.failedIds.append(id)
            }
        }
        return outcome
    }

    /// Moves the ciphers into a folder (`nil` = no folder).
    static func move(
        ids: [String],
        folderId: String?,
        repository: VaultRepository,
        errorReporter: ErrorReporter,
    ) async -> CipherBulkOutcome {
        var outcome = CipherBulkOutcome()
        for id in ids {
            do {
                guard let cipher = try await repository.fetchCipher(withId: id) else {
                    outcome.failedIds.append(id)
                    continue
                }
                try await repository.updateCipher(cipher.update(folderId: folderId))
                outcome.succeededIds.append(id)
            } catch {
                errorReporter.log(error: error)
                outcome.failedIds.append(id)
            }
        }
        return outcome
    }
}

extension VaultListItem {
    /// The cipher id of a cipher row (`nil` for group and TOTP rows).
    var cipherId: String? {
        if case let .cipher(cipherListView, _) = itemType { return cipherListView.id }
        return nil
    }
}
