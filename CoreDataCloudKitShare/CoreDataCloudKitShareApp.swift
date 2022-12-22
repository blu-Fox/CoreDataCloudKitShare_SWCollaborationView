/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The SwiftUI app for iOS.
*/
#warning("This app demonstrates Core Data + CloudKit sharing in SwiftUI. Comments were added throughout the code to explain it better. The CK container is 'iCloud.apps.janstehlik.CoreDataCloudKitShareSample'. The very similar looking container 'iCloud.apps.janstehlik.CoreDataCloudKitShare' belonged to an earlier version of this sample app downloaded from the internet, before it was published by Apple. Watch out - there is currently some bug that prevents re-opening UICloudSharingController. Need to investigate.")

import SwiftUI
import CoreData

@main
struct CoreDataCloudKitShareApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    private let persistentContainer = PersistenceController.shared.persistentContainer

    var body: some Scene {

        #if InitializeCloudKitSchema
        WindowGroup {
            Text("Initializing CloudKit Schema...").font(.title)
            Text("Stop after Xcode says 'no more requests to execute', " +
                 "then check with CloudKit Console if the schema is created correctly.").padding()
        }
        #else
        WindowGroup {
            PhotoGridView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
        #endif
    }
}
