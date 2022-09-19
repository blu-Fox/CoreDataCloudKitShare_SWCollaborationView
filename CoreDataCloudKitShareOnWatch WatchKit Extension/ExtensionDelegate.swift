/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The WatchKit extension delegate class.
*/
#warning("LOGIC: Delegate that allows accepting a share on the Watch. With Xcode 14, it should be renamed from WKExtensionDelegate to WKApplicationDelegate")
import WatchKit
import CloudKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    /**
     To be able to accept a share, add a CKSharingSupported entry in the Info.plist file of the WatchKit app and set it to true.
     */
    func userDidAcceptCloudKitShare(with cloudKitShareMetadata: CKShare.Metadata) {
        let persistenceController = PersistenceController.shared
        let sharedStore = persistenceController.sharedPersistentStore
        let container = persistenceController.persistentContainer
        container.acceptShareInvitations(from: [cloudKitShareMetadata], into: sharedStore) { (_, error) in
            if let error = error {
                print("\(#function): Failed to accept share invitations: \(error)")
            }
        }
    }
}
