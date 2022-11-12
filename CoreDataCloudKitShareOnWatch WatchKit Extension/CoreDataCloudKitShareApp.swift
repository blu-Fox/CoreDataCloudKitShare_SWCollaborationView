/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The SwiftUI app for watchOS.
*/
// LOGIC: Implement a delegate so shares can be accepted on the watch. With Xcode 14, change into WKApplicationDelegateAdaptor.

import SwiftUI

@main
struct CoreDataCloudKitShareApp: App {
    @WKExtensionDelegateAdaptor var delegateOfExtension: ExtensionDelegate

    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            PhotoGridView()
                .environment(\.managedObjectContext, persistenceController.persistentContainer.viewContext)
        }
    }
}
