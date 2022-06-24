/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The SwiftUI app for watchOS.
*/

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
