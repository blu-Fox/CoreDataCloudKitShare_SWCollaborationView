/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Extensions that add convenience methods to Core Data.
*/
// Some useful helper functions. See comments above each one.

import CoreData
import CloudKit

// Func to check if a given persistence controller contains a store. Used below.
extension NSPersistentStore {
    func contains(manageObject: NSManagedObject) -> Bool {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: manageObject.entity.name!)
        fetchRequest.predicate = NSPredicate(format: "self == %@", manageObject)
        fetchRequest.affectedStores = [self]
        
        if let context = manageObject.managedObjectContext,
           let result = try? context.count(for: fetchRequest), result > 0 {
            return true
        }
        return false
    }
}

// Variable for stores that takes into account the possibility that the store is not in the persistent container.
extension NSManagedObject {
    var persistentStore: NSPersistentStore? {
        let persistenceController = PersistenceController.shared
        if persistenceController.sharedPersistentStore.contains(manageObject: self) {
            return persistenceController.sharedPersistentStore
        } else if persistenceController.privatePersistentStore.contains(manageObject: self) {
            return persistenceController.privatePersistentStore
        }
        return nil
    }
}

// Extra - not needed for adoption
extension NSManagedObjectContext {
    /**
     Contextual information for handling errors that occur when saving a managed object context.
     */
    enum ContextualInfoForSaving: String {
        case addPhoto, deletePhoto
        case toggleTagging, deleteTag, addTag
        case addRating, deleteRating
        case sheetOnDismiss
        case deduplicateAndWait
    }
    /**
     Save a context and handle the save error. This sample simply prints the error message. Real apps can
     implement comprehensive error handling based on the contextual information.
     */
    func save(with contextualInfo: ContextualInfoForSaving) {
        if hasChanges {
            do {
                try save()
            } catch {
                print("\(#function): Failed to save Core Data context for \(contextualInfo.rawValue): \(error)")
            }
        }
    }
}

/**
 A convenience method for creating background contexts that specify the app as their transaction author.
 */
// This creates a new context in which to carry out operations.
// We specify that changes made in this context are coming from this app. This will be used as an identifier in the Persistent History Transactions. Useful if we want to see the latest changes NOT coming from this app.
// We could have a different author for different functions, if we used this context throughout the app. (e.g. in one place author could be "addPhotoFunc", in another it could be "removeThumbnailFunc". We could then track the history of this context.
// If we continued to use this context elsewhere, we need to set reset the context’s transactionAuthor to nil to prevent misattribution of future transactions.
extension NSPersistentCloudKitContainer {
    func newTaskContext() -> NSManagedObjectContext {
        let context = newBackgroundContext()
        context.transactionAuthor = TransactionAuthor.app
        return context
    }
    
    /**
     Fetch and return shares in the persistent stores.
     */
    func fetchShares(in persistentStores: [NSPersistentStore]) throws -> [CKShare] {
        var results = [CKShare]()
        for persistentStore in persistentStores {
            do {
                let shares = try fetchShares(in: persistentStore)
                results += shares
            } catch let error {
                print("Failed to fetch shares in \(persistentStore).")
                throw error
            }
        }
        return results
    }
}

