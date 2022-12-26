/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SwiftUI view that manages the actions on a photo.
*/
// UI: Refresh UI when we detect a store change. Maybe we already do this with the iCloud sync indicator?

import SwiftUI
import CoreData
import CloudKit

struct PhotoContextMenu: View {
    @Binding var activeSheet: ActiveSheet?
    @Binding var nextSheet: ActiveSheet?
    private let photo: Photo

    @State private var isPhotoShared: Bool
    @State private var hasAnyShare: Bool
    @State private var toggleProgress: Bool = false
    
    init(activeSheet: Binding<ActiveSheet?>, nextSheet: Binding<ActiveSheet?>, photo: Photo) {
        _activeSheet = activeSheet
        _nextSheet = nextSheet
        self.photo = photo
        isPhotoShared = (PersistenceController.shared.existingShare(photo: photo) != nil)
        hasAnyShare = PersistenceController.shared.shareTitles().isEmpty ? false : true
    }

    var body: some View {
        /**
         CloudKit has a limit on how many zones a database can have. To avoid reaching the limit,
         apps use the existing share, if possible.
         */
        ZStack {
            ScrollView {
                menuButtons()
            }
            if toggleProgress {
                ProgressView()
            }
        }
        // listen to notification
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }

// UI: Important part of UI for managing participation. If the finding is in the private database, allow creating a new share, or adding to an existing share (so we reuse existing zones). If the finding is in the shared database already, allow for managing the share.
    @ViewBuilder
  private func menuButtons() -> some View {

    if PersistenceController.shared.existingShare(photo: photo) != nil {
      Button("Manage Participation") { manageParticipation(photo: photo) }
    } else {
      Button("Create New Share") { createNewShare(photo: photo) }
      .disabled(isPhotoShared)

      Button("Add to Existing Share") { activeSheet = .sharePicker(photo) }
      .disabled(isPhotoShared || !hasAnyShare)
    }


        /**
        Tagging and rating.
         */
        Divider()
        Button("Tag") { activeSheet = .taggingView(photo) }
        Button("Rate") { activeSheet = .ratingView(photo) }
        /**
         Show the Delete button if the user is editing photos and has the permission to delete.
         */
        if PersistenceController.shared.persistentContainer.canDeleteRecord(forManagedObjectWith: photo.objectID) {
            Divider()
            Button("Delete", role: .destructive) {
                PersistenceController.shared.delete(photo: photo)
                activeSheet = nil
            }
        }
    }

    /**
     Use UICloudSharingController to manage the share in iOS.
     In watchOS, UICloudSharingController is unavailable, so create the share using Core Data API.
     */
// UI: Custom sheets for watchOS, since UICloudSharingController is only available on iOS

    #if os(iOS)
    private func createNewShare(photo: Photo) {
         PersistenceController.shared.presentCloudSharingController(photo: photo)
    }
    
    private func manageParticipation(photo: Photo) {
      /// Apple impelmentation (bugged in iOS16):
      ///   PersistenceController.shared.presentCloudSharingController(photo: photo)
    }
    
    #elseif os(watchOS)
    /**
     Sharing a photo can take a while, so dispatch to a global queue so SwiftUI has a chance to show the progress view.
     @State variables are thread-safe, so there's no need to dispatch back the main queue.
     */
    // The communication with the container (adding/removing) is the same everywhere. 1) update UI, 2) async function to shareObject or purge, 3) update UI, 4) close sheet. 0.1 second delay is to allow UI to update, before we execute our logic.
    private func createNewShare(photo: Photo) {
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PersistenceController.shared.shareObject(photo, to: nil) { share, error in
                toggleProgress.toggle()
                if let share = share {
                    nextSheet = .participantView(share)
                    activeSheet = nil
                }
            }
        }
    }
    
    private func manageParticipation(photo: Photo) {
        nextSheet = .managingSharesView
        activeSheet = nil
    }
    #endif
    
    /**
     Ignore the notification in the following cases:
     - It isn't relevant to the private database.
     - It doesn't have a transaction. When a share changes, Core Data triggers a store remote change notification with no transaction.
     */
    private func processStoreChangeNotification(_ notification: Notification) {
        // Return if change happened in shared database. We are only interested in changes in the private database.
        guard let storeUUID = notification.userInfo?[UserInfoKey.storeUUID] as? String,
              storeUUID == PersistenceController.shared.privatePersistentStore.identifier else {
            return
        }
        // Return if the transaction is not empty. An empty transaction means the share was changed or deleted.
        guard let transactions = notification.userInfo?[UserInfoKey.transactions] as? [NSPersistentHistoryTransaction],
              transactions.isEmpty else {
            return
        }
        // We now have a share in the private store that was changed or deleted.
        // Update UI so we know if the photo is still shared
        isPhotoShared = (PersistenceController.shared.existingShare(photo: photo) != nil)
        // Update UI to see if there are any shares at all. If not, the "Add to existing share" button is redundant.
        hasAnyShare = PersistenceController.shared.shareTitles().isEmpty ? false : true
    }
}



// For new share
//print("NEW SHARE")
//let itemProvider = NSItemProvider()
//itemProvider.registerCKShare(container: controller.cloudKitContainer) {
//  guard let share = await controller.createNewShare(unsharedPhoto: photo) else {
//    fatalError("Error registering share")
//  }
//  return share
//}
//let collaborationView = SWCollaborationView(itemProvider: itemProvider)
//collaborationView.setShowManageButton(true)
//collaborationView.cloudSharingControllerDelegate = controller
//return collaborationView

