/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 Extensions that wrap the related methods for sharing.
 */
// LOGIC: Important functions relating to the creation and deletion of shares and participants.

import Foundation
import CoreData
import UIKit
import CloudKit

#if os(iOS) // UICloudSharingController is only available in iOS.
// MARK: - Convenient methods for managing sharing.
//
import SharedWithYou

extension PersistenceController {

  func createNewShare(unsharedPhoto: Photo) async -> CKShare? {
    do {
      let (_, share, _) = try await self.persistentContainer.share([unsharedPhoto], to: nil)
      // unused: set, container
      configure(share: share)
      return share
    } catch {
      print("PersistenceController.createNewShare: Error creating share")
      return nil
    }
  }

  // Function to present the cloudsharing controller for a photo, which may or may not be already shared.
  func presentCloudSharingController(photo: Photo) {

    // Grab the share if the photo is already shared.
    var photoShare: CKShare?
    if let shareSet = try? persistentContainer.fetchShares(matching: [photo.objectID]),
       let (_, share) = shareSet.first {
      photoShare = share
    }

    // Initiate UICloudSharingController
    // Bugged out in iOS16 when showing an existing share
//    let sharingController: UICloudSharingController
//    if photoShare == nil {
//      print("NEW SHARE")
//      sharingController = newSharingController(unsharedPhoto: photo, persistenceController: self)
//    } else {
//      /// WARNING: A confirmed bug appears here. UICloudSharingController does not work for existing shares in iOS16.
//      /// A TSI has been opened.
//      /// Also look into replacing UICloudSharingController with UIActivityViewController+SWCollaborationView or ShareLink+SWCollaborationView
//      print("EXISTING SHARE NAMED: \(photoShare!.title)")
//      sharingController = UICloudSharingController(share: photoShare!, container: cloudKitContainer)
//    }
//    // Add delegate
//    sharingController.delegate = self
//    // Present UICloudSharingController as a sheet. Set the presentation style to .formSheet so there's no need to specify sourceView, sourceItem, or sourceRect.
//    if let viewController = rootViewController {
//      sharingController.modalPresentationStyle = .formSheet
//      viewController.present(sharingController, animated: true)
//    }

    // New implementation
    if let share = photoShare {
      print("EXISTING SHARE NAMED: \(share.title)")
      let itemProvider = NSItemProvider()
      itemProvider.registerCKShare(share, container: cloudKitContainer, allowedSharingOptions: .standard)
      let collaborationView = SWCollaborationView(itemProvider: itemProvider)
      collaborationView.activeParticipantCount = share.participants.count
      collaborationView.setShowManageButton(true)
      collaborationView.cloudSharingControllerDelegate = self
    } else {
      print("NEW SHARE")
      let sharingController: UICloudSharingController
      sharingController = newSharingController(unsharedPhoto: photo, persistenceController: self)
      sharingController.delegate = self
      if let viewController = rootViewController {
        sharingController.modalPresentationStyle = .formSheet
        viewController.present(sharingController, animated: true)
      }
    }
  }

  // Function to present the cloudsharing controller for an existing share, which may or may not contain something.
  func presentCloudSharingController(share: CKShare) {
    let sharingController = UICloudSharingController(share: share, container: cloudKitContainer)
    sharingController.delegate = self
    /**
     Setting the presentation style to .formSheet so there's no need to specify sourceView, sourceItem, or sourceRect.
     */
    if let viewController = rootViewController {
      sharingController.modalPresentationStyle = .formSheet
      viewController.present(sharingController, animated: true)
    }
  }

  // private function to construct a controller for a photo which is hitherto unshared.
  private func newSharingController(unsharedPhoto: Photo, persistenceController: PersistenceController) -> UICloudSharingController {
    return UICloudSharingController { (_, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
      /**
       The app doesn't specify a share intentionally, so Core Data creates a new share (zone).
       CloudKit has a limit on how many zones a database can have, so this app provides an option for users to use an existing share.

       If the share's publicPermission is CKShareParticipantPermissionNone, only private participants can accept the share.
       Private participants mean the participants an app adds to a share by calling CKShare.addParticipant.
       If the share is more permissive, and is, therefore, a public share, anyone with the shareURL can accept it,
       or self-add themselves to it.
       The default value of publicPermission is CKShare.ParticipantPermission.none.
       */
      self.persistentContainer.share([unsharedPhoto], to: nil) { objectIDs, share, container, error in
        if let share = share {
          self.configure(share: share)
        }
        completion(share, container, error)
      }
    }
  }

  // helper func to get the window's root view controller and change the UI of the UICloudSharingController
  private var rootViewController: UIViewController? {
    for scene in UIApplication.shared.connectedScenes {
      if scene.activationState == .foregroundActive,
        let sceneDeleate = (scene as? UIWindowScene)?.delegate as? UIWindowSceneDelegate,
        let window = sceneDeleate.window {
          return window?.rootViewController
        }
    }
    print("\(#function): Failed to retrieve the window's root view controller.")
    return nil
  }
}

extension PersistenceController: UICloudSharingControllerDelegate {
  /**
   CloudKit triggers the delegate method in two cases:
   - An owner stops sharing a share.
   - A participant removes themselves from a share by tapping the Remove Me button in UICloudSharingController.

   After stopping the sharing,  purge the zone or just wait for an import to update the local store.
   This sample chooses to purge the zone to avoid stale UI. That triggers a "zone not found" error because UICloudSharingController deletes the zone, but the error doesn't really matter in this context.

   Purging the zone has a caveat:
   - When sharing an object from the owner side, Core Data moves the object to the shared zone.
   - When calling purgeObjectsAndRecordsInZone, Core Data removes all the objects and records in the zone.
   To keep the objects, deep copy the object graph you want to keep and make sure no object in the new graph is associated with any share.

   The purge API posts an NSPersistentStoreRemoteChange notification after finishing its job, so observe the notification to update the UI, if necessary.
   */
  // This is important, and possibly needs some revision so that deleting a shared Finding does not also delete it on the owner side. Not yet sure, but maybe we will need to copy the Finding into private database before deleting it from the shared database?
  func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
    if let share = csc.share {
      purgeObjectsAndRecords(with: share)
    }
  }

  // From the sample description: NSPersistentCloudKitContainer doesn't automatically handle the changes UICloudSharingController (or other CloudKit APIs) makes on a share. Apps must call persistUpdatedShare(_:in:completion:) to save the changes to the Core Data store. The sample app does that by implementing the following UICloudSharingControllerDelegate method:
  func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
    if let share = csc.share, let persistentStore = share.persistentStore {
      persistentContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
        if let error = error {
          print("\(#function): Failed to persist updated share: \(error)")
        }
      }
    }
  }

  func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
    print("\(#function): Failed to save a share: \(error)")
  }

  func itemTitle(for csc: UICloudSharingController) -> String? {
    return csc.share?.title ?? "A cool photo 1"
  }
}
#endif

#if os(watchOS)
extension PersistenceController {
  func presentCloudSharingController(share: CKShare) {
    print("\(#function): Cloud sharing controller is unavailable on watchOS.")
  }
}
#endif

extension PersistenceController {

  func shareObject(_ unsharedObject: NSManagedObject, to existingShare: CKShare?,
                   completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
  {
    persistentContainer.share([unsharedObject], to: existingShare) { (objectIDs, share, container, error) in
      guard error == nil, let share = share else {
        print("\(#function): Failed to share an object: \(error!))")
        completionHandler?(share, error)
        return
      }
      /**
       Deduplicate tags, if necessary, because adding a photo to an existing share moves the whole object graph to the associated record zone, which can lead to duplicated tags.
       */
      if existingShare != nil {
        // possibly irrelevant for Rostou
        if let tagObjectIDs = objectIDs?.filter({ $0.entity.name == "Tag" }), !tagObjectIDs.isEmpty {
          self.deduplicateAndWait(tagObjectIDs: Array(tagObjectIDs))
        }
      } else {
        // No existing share was found, so a new one is configured
        self.configure(share: share)
      }
      /**
       Synchronize the changes on the share to the private persistent store.
       */
      // From the sample description: NSPersistentCloudKitContainer doesn't automatically handle the changes UICloudSharingController (or other CloudKit APIs) makes on a share. Apps must call persistUpdatedShare(_:in:completion:) to save the changes to the Core Data store.
      self.persistentContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
        if let error = error {
          print("\(#function): Failed to persist updated share: \(error)")
        }
        completionHandler?(share, error)
      }
    }
  }

  /**
   Delete the Core Data objects and the records in the CloudKit record zone associated with the share.
   */
  func purgeObjectsAndRecords(with share: CKShare, in persistentStore: NSPersistentStore? = nil) {
    guard let store = (persistentStore ?? share.persistentStore) else {
      print("\(#function): Failed to find the persistent store for share. \(share))")
      return
    }
    persistentContainer.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { (zoneID, error) in
      if let error = error {
        print("\(#function): Failed to purge objects and records: \(error)")
      }
    }
  }

  // Helper func to find a possible share that contains this photo
  func existingShare(photo: Photo) -> CKShare? {
    if let shareSet = try? persistentContainer.fetchShares(matching: [photo.objectID]),
       let (_, share) = shareSet.first {
      return share
    }
    return nil
  }

  // Helper func to find a possible share by its title
  func share(with title: String) -> CKShare? {
    let stores = [privatePersistentStore, sharedPersistentStore]
    let shares = try? persistentContainer.fetchShares(in: stores)
    let share = shares?.first(where: { $0.title == title })
    return share
  }

  // Helper func to fetch the titles of all shares
  func shareTitles() -> [String] {
    let stores = [privatePersistentStore, sharedPersistentStore]
    let shares = try? persistentContainer.fetchShares(in: stores)
    return shares?.map { $0.title } ?? []
  }

  // Default share configuration
  private func configure(share: CKShare, with photo: Photo? = nil) {
    share[CKShare.SystemFieldKey.title] = "A cool photo 2"
  }
}

extension PersistenceController {
  func addParticipant(emailAddress: String, permission: CKShare.ParticipantPermission = .readWrite, share: CKShare,
                      completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)?) {
    /**
     Use the email address to look up the participant from the private store. Return if the participant doesn't exist.
     Use privatePersistentStore directly because only the owner may add participants to a share.
     */
    let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: emailAddress)
    let persistentStore = privatePersistentStore //share.persistentStore! - not needed bc we know only the owner can do this

    persistentContainer.fetchParticipants(matching: [lookupInfo], into: persistentStore) { (results, error) in
      guard let participants = results, let participant = participants.first, error == nil else {
        completionHandler?(share, error)
        return
      }

      participant.permission = permission
      participant.role = .privateUser
      share.addParticipant(participant)

      self.persistentContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
        if let error = error {
          print("\(#function): Failed to persist updated share: \(error)")
        }
        completionHandler?(share, error)
      }
    }
  }

  // Logic function to delete a specified participant. Only run when we already know that we have permission to delete participants (i.e. we are OWNER)
  func deleteParticipant(_ participants: [CKShare.Participant], share: CKShare,
                         completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)?) {

    // delete specified participant(s)
    for participant in participants {
      share.removeParticipant(participant)
    }
    /**
     Use privatePersistentStore directly because only the owner may delete participants to a share.
     */
    // Persist changes.
    persistentContainer.persistUpdatedShare(share, in: privatePersistentStore) { (share, error) in
      if let error = error {
        print("\(#function): Failed to persist updated share: \(error)")
      }
      completionHandler?(share, error)
    }
  }
}

// Variable informing about the status of a participant's participation
extension CKShare.ParticipantAcceptanceStatus {
  var stringValue: String {
    return ["Unknown", "Pending", "Accepted", "Removed"][rawValue]
  }
}

extension CKShare {

  // Variable storing the share's name
  var title: String {
    // If we have no date, create a unique UUID title.
    guard let date = creationDate else {
      return "Share-\(UUID().uuidString)"
    }
    // Otherwise, create a name from the date and time of the share creation.
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return "Share-" + formatter.string(from: date)
  }

  // Variable informing about which store the share is in.
  var persistentStore: NSPersistentStore? {
    let persistentContainer = PersistenceController.shared.persistentContainer
    let privatePersistentStore = PersistenceController.shared.privatePersistentStore
    if let shares = try? persistentContainer.fetchShares(in: privatePersistentStore) {
      let zoneIDs = shares.map { $0.recordID.zoneID }
      if zoneIDs.contains(recordID.zoneID) {
        // Share is in the user's private store - user is OWNER
        return privatePersistentStore
      }
    }
    let sharedPersistentStore = PersistenceController.shared.sharedPersistentStore
    if let shares = try? persistentContainer.fetchShares(in: sharedPersistentStore) {
      let zoneIDs = shares.map { $0.recordID.zoneID }
      if zoneIDs.contains(recordID.zoneID) {
        // Share is in the user's shared store - user is PARTICIPANT
        return sharedPersistentStore
      }
    }
    // Share is in neither store, or we failed to find it (or the store)
    return nil
  }
}
