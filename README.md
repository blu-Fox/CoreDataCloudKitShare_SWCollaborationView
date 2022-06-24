# Sharing Core Data objects between iCloud users
Use Core Data CloudKit to implement a data-sharing flow between iCloud users.

## Overview
More and more people own multiple devices and use them to share digital assets or to collaborate for work. They expect seamless data synchronization across their devices, and an easy way to share data with robust privacy and security features. Apps can support such use cases by moving user data to CloudKit and implementing a data-sharing flow that includes features like share management and access control. 

This sample code project demonstrates how to use Core Data CloudKit to share photos between iCloud users. Users who share photos, called _owners_, can create a share, send out an invitation, manage the permissions, and stop the sharing. Users who accept the share, called _participants_, can view and edit the photos, or stop participating in the share.

## Configure the sample code project
Before building the sample app, perform the following steps in Xcode:
1. In the General pane of the `CoreDataCloudKitShare` target, update the Bundle Identifier field with a new identifier.
2. Click Signing & Capabilities, and select the applicable team from the Team drop-down menu to let Xcode automatically manage the provisioning profile. See [Assign a project to a team](https://help.apple.com/xcode/mac/current/#/dev23aab79b4) for details.
3. Make sure the iCloud capability is present and the CloudKit option is in a selected state, and then select the iCloud container with your bundle identifier from the Containers list. If the container doesn’t exist, click the Add button (+), enter the container name (`iCloud.<*bundle identifier*>`), and click OK to let Xcode create the container and associate it with the app.
4. Specify your iCloud container for the `gCloudKitContainerIdentifier` variable in `PersistenceController.swift`. An iCloud container identifier is case-sensitive and must begin with "`iCloud.`".
5. Similar to steps 1 and 2, change the bundle identifiers and the developer team for the WatchKit app and the WatchKit Extension targets. The bundle identifiers must be `<The iOS app bundle ID>.watchkitapp` and `<The iOS app bundle ID>.watchkitapp.watchkitextension`, respectively.
6. Similar to step 3, specify the iCloud container for the WatchKit Extension target. To synchronize data across iCloud, the iOS app and the WatchKit extension must share the same iCloud container.
7. Open the `Info.plist` file of the WatchKit app target and change the value of the `WKCompanionAppBundleIdentifier` key to `<The iOS app bundle ID>`.
8. Open the `Info.plist` file of the WatchKit Extension target and change the value of the `NSExtension` > `NSExtensionAttributes` > `WKAppBundleIdentifier` key to `<The iOS app bundle ID>.watchkitapp`.

To run the sample app on a device, configure the device as follows:
1. Log in with an Apple ID. For the CloudKit private database to synchronize, the Apple ID must be the same on the devices. For an Apple Watch, log in from the Watch app on the paired iPhone, and make sure the Apple ID shows up in the Settings app on the watch.
2. For an iOS device, choose Settings > Apple ID > iCloud, and turn on iCloud Drive, if necessary.
3. After running the sample app on the device, choose Settings > Notifications and turn on Allow Notifications for the app, if necessary. For an Apple Watch, use the Watch app on the paired iPhone to make sure that notifications are on for the app.

To create and configure a new project that uses Core Data CloudKit, see [Setting Up Core Data with CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/setting_up_core_data_with_cloudkit?changes=__3).

## Create the CloudKit schema
CloudKit apps must have a schema to declare the data types they use. When apps create a record in the CloudKit development environment, CloudKit automatically creates the record type if it doesn't exist. In the production environment, CloudKit doesn't have that capability, nor does it allow removing an existing record type or field, so after finalizing the schema, developers need to deploy it to the production environment. Without this step, apps that work in the production environment, like the ones users download from the App Store or TestFlight, can't communicate with the CloudKit server. For more information, see [Deploying an iCloud Container’s Schema](https://developer.apple.com/documentation/cloudkit/managing_icloud_containers_with_the_cloudkit_database_app/deploying_an_icloud_container_s_schema).

Core Data CloudKit apps can use [`initializeCloudKitSchema(options:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3343548-initializecloudkitschema) to create the CloudKit schema that matches their Core Data model, or keep it up-to-date every time their model changes. The method works by creating fake data for the record types and then deleting it, which can take some time and blocks the other CloudKit operations. Apps must not call it in the production environment, or in the normal development process that doesn't include model changes.

To create the CloudKit schema for this sample app, select the `InitializeCloudKitSchema` target from Xcode's target menu, and run it. Having a target dedicated on CloudKit schema creation separates the `initializeCloudKitSchema(options:)` call from the normal flow. After running the target, use [CloudKit Console](http://icloud.developer.apple.com/dashboard/) to ensure each Core Data entity and attribute has a CloudKit counterpart. See [Reading CloudKit Records for Core Data](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/reading_cloudkit_records_for_core_data) for the detailed mapping rules.

For apps that use the CloudKit public database, use CloudKit Console to manually add the `Queryable` index for the `recordName` field, and the `Queryable` and `Sortable` indexes for the `modifiedAt` field, for all record types, including the `CDMR` type that Core Data generates to manage many-to-many relationships.

For more information, see [Creating a Core Data Model for CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/creating_a_core_data_model_for_cloudkit).

## Try out the sharing flow
To create and share a photo using the sample app, follow these steps:
1. Prepare two iOS devices, A and B, and log in to each device with a different Apple ID.
2. Use Xcode to build and run the sample app on the devices.
3. On device A, tap the Add button (+) to show the photo picker, and then select a photo and add it to the Core Data store.
4. Touch and hold the photo to display the context menu and then tap Create New Share to present the CloudKit sharing UI.
5. Follow the UI to send a link to the Apple ID on device B. Use iMessage if you can because it's easier to set up.
6. After receiving the link on device B, tap it to accept and open the share, which launches the sample app and shows the photo.

To discover more features of the sample app:
- On device A, add another photo, touch and hold it, tap Add to Existing Share, then pick a share and tap Add. The photo soon appears on device B.
- On device B, touch and hold the photo, tap Manage Participation to present the CloudKit sharing UI, then select the Apple ID with the "(Me)" suffix and tap Remove Me to remove the participation. The photo disappears.
- Tap Manage Shares, select the share, and manage its participants using [`UICloudSharingController`](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller) or the app UI.

It may take some time for one user to see changes from the other users. Core Data CloudKit isn't for real-time synchronization. When users change the store on their device, the system determines when to synchronize the change. There is no API for apps to configure the timing for the synchronization.

## Set up the Core Data stack
Every CloudKit container has a [private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/1399205-privateclouddatabase) and a [shared database](https://developer.apple.com/documentation/cloudkit/ckcontainer/1640408-sharedclouddatabase). To mirror these databases, the sample app sets up a Core Data stack with two stores, and sets the store's [database scope](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontaineroptions/3580372-databasescope?changes=__3) to `.private` and `.shared`, respectively. 

When setting up the store description, the sample app enables [persistent history](https://developer.apple.com/documentation/coredata/persistent_history) tracking and turns on remote change notifications by setting the `NSPersistentHistoryTrackingKey` and `NSPersistentStoreRemoteChangeNotificationPostOptionKey` options to `true`. Core Data relies on the persistent history to track the store changes, and the sample app needs to update its UI when remote changes occur.

``` swift
privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

To synchronize data through CloudKit, apps must use the same CloudKit container. This sample app explicitly specifies the same container for its iOS and watchOS apps when setting up the CloudKit container options.

``` swift
let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: gCloudKitContainerIdentifier)
```

## Share a Core Data object
Sharing a Core Data object between iCloud users includes creating a share from the owner side, accepting the share from the participant side, and managing the share from both sides. Owners can stop sharing an object or change the share permission, and participants can stop their participation.

[`NSPersistentCloudKitContainer`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer?changes=__3) provides methods for creating a share ([`CKShare`](https://developer.apple.com/documentation/cloudkit/ckshare)) for Core Data objects and managing the interaction between the share and the associated objects. `UICloudSharingController` implements the share invitation and management. Apps can implement a sharing flow using these two APIs.

To create a share for Core Data objects, the sample app calls [`share(_:to:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746834-share?changes=__3). Apps can create a new share, or add the objects to an existing share. Core Data uses CloudKit zone sharing so each share has its own record zone on the CloudKit server. CloudKit has a limit on how many record zones a database can have. To avoid reaching the limit over time, the sample app provides an option for users to share an object by adding it to an existing zone. The following code example shows the implementation details:

``` swift
func shareObject(_ unsharedObject: NSManagedObject, to existingShare: CKShare?,
                 completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
```

`NSPersistentCloudKitContainer` doesn't automatically handle the changes `UICloudSharingController` (or other CloudKit APIs) makes on a share. Apps must call [`persistUpdatedShare(_:in:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746832-persistupdatedshare?changes=__3) to save the changes to the Core Data store. The sample app does that by implementing the following [`UICloudSharingControllerDelegate`](https://developer.apple.com/documentation/uikit/uicloudsharingcontrollerdelegate) method:

``` swift
func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
    if let share = csc.share, let persistentStore = share.persistentStore {
        persistentContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
            if let error = error {
                print("\(#function): Failed to persist updated share: \(error)")
            }
        }
    }
}
```

Similarly, when owners tap Stop Sharing or participants tap Remove Me in the UI of `UICloudSharingController`, `NSPersistentCloudKitContainer` doesn't immediately receive a notification about the change. To avoid a stale UI in this situation, the sample app implements the following delegate method to purge the Core Data objects and CloudKit records associated with the share using [`purgeObjectsAndRecordsInZone(with:in:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746833-purgeobjectsandrecordsinzone?changes=__3):

``` swift
func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
    if let share = csc.share {
        purgeObjectsAndRecords(with: share)
    }
}
```

Core Data doesn't support cross-share relationships. That is, it doesn't allow relating objects associated with different shares. When sharing an object, Core Data moves the entire object graph, which includes the object and all its relationships, to the share's record zone. When users stop a share, Core Data deletes the object graph. As a result, the object graph gets _lost_ from the store. To avoid adding more compexity, the sample app doesn't reserve the object graph in that case. Apps that need to keep the object graph can make a deep copy on the owner side, ensure that no object in the new graph is associated with any share, and save it. 

- Note: For details about Core Data and CloudKit sharing, see [WWDC21 session 10015: Build apps that share data through CloudKit and Core Data](https://developer.apple.com/videos/play/wwdc2021/10015/) and [WWDC21 session 10086: What's new in CloudKit](https://developer.apple.com/videos/play/wwdc2021/10086).

## Detect relevant changes by consuming store persistent history
When importing data from CloudKit, `NSPersistentCloudKitContainer` records the changes on Core Data objects in the store's persistent history, and triggers remote change notifications (`.NSPersistentStoreRemoteChange`) so apps can keep their state up-to-date, if necessary. The sample app observes the notification and performs the following actions in the notification handler:

- Gathers the relevant history transactions ([`NSPersistentHistoryTransaction`](https://developer.apple.com/documentation/coredata/nspersistenthistorytransaction)), and notifies the views when remote changes happen. The changes on shares don't generate any transactions.
- Merges the transactions to the `viewContext` of the persistent container, which triggers a SwiftUI update for the views that present photos. Views relevant to shares fetch the shares from the stores, and update with them.
- Detects the new tags from CloudKit, and removes duplicate tags, if necessary.

To process the persistent history more effectively, the sample app:
- Maintains the token of the last transaction it consumes for each store, and uses it as the starting point of the next run.
- Maintains a transaction author, and uses it to filter the transactions irrelevant to Core Data CloudKit.
- Only fetches and consumes the history of the relevant persistent store.

The following code sets up the history fetch request (`NSPersistentHistoryChangeRequest`):
``` swift
let lastHistoryToken = historyToken(with: storeUUID)
let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)
let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest!
historyFetchRequest.predicate = NSPredicate(format: "author != %@", TransactionAuthor.app)
request.fetchRequest = historyFetchRequest

if privatePersistentStore.identifier == storeUUID {
    request.affectedStores = [privatePersistentStore]
} else if sharedPersistentStore.identifier == storeUUID {
    request.affectedStores = [sharedPersistentStore]
}
```

For more information about persistent history processing, see [Consuming Relevant Store Changes](https://developer.apple.com/documentation/coredata/consuming_relevant_store_changes).

## Remove duplicate data
In the CloudKit environment, duplicate data is sometimes inevitable due to the following:
- Different peers can create the same data. In the sample app, owners can share a photo with a permission that allows participants to tag it. When owners and participants simultaneously create the same tag, a duplicate occurs.
- Apps rely on some initial data and there's no way to allow only one peer to preload it. Duplicates occur when multiple peers preload the data at the same time.

To remove duplicate data (or _deduplicate_), apps need to implement a way that allows all peers to eventually reserve the same _winner_ and remove others. The sample app removes duplicate tags in the following way:

1. Gives every tag a universally unique identifier (UUID). Tags that have the same name (but different UUIDs) and are associated with the same share (and are, therefore, in the same CloudKit record zone) are duplicates, so only one of them can exist.
2. Detects new tags from CloudKit by looking into the persistent history each time a remote change notification occurs.
3. For each new tag, fetches the duplicates from the same persistent store, and sorts them with their UUID so the tag with the lowest UUID goes first.
4. Picks the first tag as the _winner_ and removes the others. Because each UUID is globally unique and every peer picks the first tag, all peers eventually have the same winner, which is the tag that has the globally lowest UUID.
 
The sample app only detects and removes duplicate tags from the owner side because participants may not have write permission. So deduplication only applies to the private persistent store.
 
The following method shows how to deduplicate tags:

``` swift
func deduplicateAndWait(tagObjectIDs: [NSManagedObjectID])
```

## Implement a custom sharing flow
Apps can implement a custom sharing flow when `UICloudSharingController` is unavailable or doesn't fit their UI. (`UICloudSharingController` is unavailabe in watchOS. In macOS, the counterpart is [`NSSharingService`](https://developer.apple.com/documentation/appkit/nssharingservice) with the [`.cloudSharing`](https://developer.apple.com/documentation/appkit/nssharingservice/name/1644670-cloudsharing) service.) The sample app performs the following tasks so users can share photos from watchOS:

1. Creates a share using `share(_:to:completion:)` when an owner shares a photo. 

2. Configures the share with appropriate permissions, and adds participants for a share. A share is private if its [`publicPermission`](https://developer.apple.com/documentation/cloudkit/ckshare/1640494-publicpermission) is [`.none`](https://developer.apple.com/documentation/cloudkit/ckshare/participantpermission/none). For shares that have a public permission more permissive than `.none` (called _public shares_), users can participate by tapping the share link, so there's no need to add participants beforehand. The sample app looks up participants using [`fetchParticipants(matching:into:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746829-fetchparticipants), configures the participant permission using [`CKShare.Participant.permission`](https://developer.apple.com/documentation/cloudkit/ckshare/participant/1640433-permission), and adds it to the share using [`addParticipant(_:)`](https://developer.apple.com/documentation/cloudkit/ckshare/1640443-addparticipant).

3. Delivers the share link ([`CKShare.url`](https://developer.apple.com/documentation/cloudkit/ckshare/1640465-url)) to the participants. The sample app doesn't do anything for this step because the way to decorate and deliver a share link may vary due to concrete use cases. Real-world apps implement this step based on their needs.

4. Accepts the share. When participants tap the share link to accept the share and launch the app, watchOS calls the [`userDidAcceptCloudKitShare(with:)`](https://developer.apple.com/documentation/watchkit/wkextensiondelegate/3612144-userdidacceptcloudkitshare) method of the WatchKit extension delegate (iOS calls [`windowScene(_:userDidAcceptCloudKitShareWith:)`](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/3238089-windowscene) instead). In the method, the sample app accepts the share by calling [`acceptShareInvitations(from:into:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746828-acceptshareinvitations). After the acceptance synchronizes, the photo (and its relationships) are available in the participants' store that mirrors the CloudKit shared database.

5. Manages the participants of the share from the owner side using `addParticipant(_:)` and `removeParticipant(_:)`, or stops the sharing by calling `purgeObjectsAndRecordsInZone(with:in:completion:)`.

6. Stops the participation from the participant side by calling `purgeObjectsAndRecordsInZone(with:in:completion:)`.

- Note: To be able to accept a share when users tap a share link, an app's `Info.plist` file must contain the `CKSharingSupported` key and its value must be `true`.

During this process, whenever changing the share using CloudKit APIs, the sample app calls `persistUpdatedShare(_:in:completion:)`, so Core Data persists the change to the store and synchronizes it with CloudKit. For example, it uses the following code to add a participant:

``` swift
participant.permission = permission
participant.role = .privateUser
share.addParticipant(participant)

self.persistentContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
    if let error = error {
        print("\(#function): Failed to persist updated share: \(error)")
    }
    completionHandler?(share, error)
}
```
