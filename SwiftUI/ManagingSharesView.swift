/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SwiftUI view that manages existing shares.
*/

import SwiftUI
import CoreData
import CloudKit

struct ManagingSharesView: View {
    @Binding var activeSheet: ActiveSheet?
    @Binding var nextSheet: ActiveSheet?

    @State private var toggleProgress: Bool = false
    @State private var selection: String?

    var body: some View {
        ZStack {
            SharePickerView(activeSheet: $activeSheet, selection: $selection) {
                if  let shareTitle = selection, let share = PersistenceController.shared.share(with: shareTitle) {
                    actionButtons(for: share)
                }
            }
            if toggleProgress {
                ProgressView()
            }
        }
    }
    
    @ViewBuilder
    private func actionButtons(for share: CKShare) -> some View {
        let persistentStore = share.persistentStore
        let isPrivateStore = (persistentStore == PersistenceController.shared.privatePersistentStore)
        
        Button(isPrivateStore ? "Manage Participants" : "View Participants") {
            if let share = PersistenceController.shared.share(with: selection!) {
                nextSheet = .participantView(share)
                activeSheet = nil
            }
        }
        .disabled(selection == nil)
        
        Button(isPrivateStore ? "Stop Sharing" : "Remove Me") {
            if let share = PersistenceController.shared.share(with: selection!) {
                purgeShare(share, in: persistentStore)
            }
        }
        .disabled(selection == nil)

        #if os(iOS)
        Button("Manage With UICloudSharingController") {
            if let share = PersistenceController.shared.share(with: selection!) {
                nextSheet = .cloudSharingSheet(share)
                activeSheet = nil
            }
        }
        .disabled(selection == nil)
        #endif
    }
    
    private func purgeShare(_ share: CKShare, in persistentStore: NSPersistentStore?) {
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PersistenceController.shared.purgeObjectsAndRecords(with: share, in: persistentStore)
            toggleProgress.toggle()
            activeSheet = nil
        }
    }
}
