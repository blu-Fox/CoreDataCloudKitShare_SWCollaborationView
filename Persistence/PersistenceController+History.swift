/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Extensions that wrap the related methods for persistence history processing.
*/
#warning("LOGIC: Important file for tracking and processing persistence history.")
import CoreData
import CloudKit

// MARK: - Notification handlers that trigger history processing.
//
extension PersistenceController {
    /**
     Handle .NSPersistentStoreRemoteChange notifications.
     Process persistent history to merge relevant changes to the context, and deduplicate the tags, if necessary.
     */
    // Persistent controller has a listener to remote store changes. Once we get a notification, run this function, which processes persistent history.
    @objc
    func storeRemoteChange(_ notification: Notification) {
        guard let storeUUID = notification.userInfo?[NSStoreUUIDKey] as? String,
              [privatePersistentStore.identifier, sharedPersistentStore.identifier].contains(storeUUID) else {
            print("\(#function): Ignore a store remote Change notification because of no valid storeUUID.")
            return
        }
        processHistoryAsynchronously(storeUUID: storeUUID)
    }

    /**
     Handle the container's event change notifications (NSPersistentCloudKitContainer.eventChangedNotification).
     */
  // Persistent controller has a listener to container event changes. Once we get a notification, run this function, that notifies us that some activity occured
    @objc
    func containerEventChanged(_ notification: Notification) {
         guard let value = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey],
              let event = value as? NSPersistentCloudKitContainer.Event else {
            print("\(#function): Failed to retrieve the container event from notification.userInfo.")
            return
        }
        if event.error != nil {
            print("\(#function): Received a persistent CloudKit container event changed notification.\n\(event)")
        }
    }
}

// MARK: - Process persistent historty asynchronously.
//
extension PersistenceController {
    /**
     Process persistent history, posting any relevant transactions to the current view.
     This method processes the new history since the last history token, and is simply a fetch if there's no new history.
     */
    // Create a new task and process history on a specified custom queue
    private func processHistoryAsynchronously(storeUUID: String) {
        historyQueue.addOperation {
            let taskContext = self.persistentContainer.newTaskContext()
            taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            taskContext.performAndWait {
                self.performHistoryProcessing(storeUUID: storeUUID, performingContext: taskContext)
            }
        }
    }
    
    private func performHistoryProcessing(storeUUID: String, performingContext: NSManagedObjectContext) {
        /**
         Fetch the history by the other author since the last timestamp.
        */
        // Get the token of the last instance when we performed history tracking (to be efficient)
        let lastHistoryToken = historyToken(with: storeUUID)
        // Define a request to fetch history of changes since the last time we checked
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)
        let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest!
        // Only include changes not made in this app (TransactionAuthor.app)
        historyFetchRequest.predicate = NSPredicate(format: "author != %@", TransactionAuthor.app)
        request.fetchRequest = historyFetchRequest
        // If the notification came from a private store, compare with history in the private store. Else, shared store.
        if privatePersistentStore.identifier == storeUUID {
            request.affectedStores = [privatePersistentStore]
        } else if sharedPersistentStore.identifier == storeUUID {
            request.affectedStores = [sharedPersistentStore]
        }
        // Execute request as defined above
        let result = (try? performingContext.execute(request)) as? NSPersistentHistoryResult
        // Return if there are no results
        guard let transactions = result?.result as? [NSPersistentHistoryTransaction] else {
            return
        }
        // print("\(#function): Processing transactions: \(transactions.count).")

        /**
         Post transactions so observers can update the UI, if necessary, even when transactions is empty
         because when a share changes, Core Data triggers a store remote change notification with no transaction.
         */
        // Post a notification the UI can listen to.
        // userInfo is a user info dictionary with optional information about the notification. In this case, it contains the list of changes in history, with UUID of the given store and information about the transaction (some changes may be with no transaction, if they concern change to the share).
        let userInfo: [String: Any] = [UserInfoKey.storeUUID: storeUUID, UserInfoKey.transactions: transactions]
        NotificationCenter.default.post(name: .cdcksStoreDidChange, object: self, userInfo: userInfo)
        /**
         Update the history token using the last transaction. The last transaction has the latest token.
         */
        // Update the timestamp so future history tracking can take off from the latest change.
        if let newToken = transactions.last?.token {
            updateHistoryToken(with: storeUUID, newToken: newToken)
        }
        
        /**
         Limit to the private store so only owners can deduplicate the tags. Owners have full access to the private database, and so don't need to worry about the permissions.
         */
        // Return if there are no transactions, or if we are tracking the shared store history. Only continue if we have transactions in the private store.
        guard !transactions.isEmpty, storeUUID == privatePersistentStore.identifier else {
            return
        }
        /**
         Deduplicate the new tags.
         This only deduplicates the tags that aren't shared or have the same share.
         */
        // We now have some transactions in the private store. Check if there are duplicate tags, and if so, remove the duplicates.
        var newTagObjectIDs = [NSManagedObjectID]()
        let tagEntityName = Tag.entity().name

        for transaction in transactions where transaction.changes != nil {
            for change in transaction.changes! {
                if change.changedObjectID.entity.name == tagEntityName && change.changeType == .insert {
                    newTagObjectIDs.append(change.changedObjectID)
                }
            }
        }
        if !newTagObjectIDs.isEmpty {
            deduplicateAndWait(tagObjectIDs: newTagObjectIDs)
        }
    }
    
    /**
     Track the last history tokens for the stores.
     The historyQueue reads the token when executing operations, and updates it after completing the processing.
     Access this user default from the history queue.
     */
    // Track the timestamp of when we last searched history. Save it in UserDefaults.
    private func historyToken(with storeUUID: String) -> NSPersistentHistoryToken? {
        let key = "HistoryToken" + storeUUID
        if let data = UserDefaults.standard.data(forKey: key) {
            return  try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
        }
        return nil
    }
    // Update the timestamp so future history tracking can take off from the latest change.
    private func updateHistoryToken(with storeUUID: String, newToken: NSPersistentHistoryToken) {
        let key = "HistoryToken" + storeUUID
        let data = try? NSKeyedArchiver.archivedData(withRootObject: newToken, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: key)
    }
}
