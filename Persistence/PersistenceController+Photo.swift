/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An extension that wraps the related methods for managing photos.
*/
#warning("LOGIC: This file contains the function to get a list of transactions relating to photos. Useful for merging them together, so main view (with multiple photos is not confused when it gets multiple notifications.")
import Foundation
import CoreData

// MARK: - Convenient methods for managing photos.
//
extension PersistenceController {

    // Standard function for adding data into Core Data
    func addPhoto(photoData: Data, thumbnailData: Data, tagNames: [String] = [], context: NSManagedObjectContext) {
        context.perform {
            let photo = Photo(context: context)
            photo.uniqueName = UUID().uuidString
            
            let thumbnail = Thumbnail(context: context)
            thumbnail.data = thumbnailData
            thumbnail.photo = photo
            
            let photoDataObject = PhotoData(context: context)
            photoDataObject.data = photoData
            photoDataObject.photo = photo
            
            for tagName in tagNames {
                let existingTag = Tag.tagIfExists(with: tagName, context: context)
                let tag = existingTag ?? Tag(context: context)
                tag.name = tagName
                tag.addToPhotos(photo)
            }

            context.save(with: .addPhoto)
        }
    }
    
    func delete(photo: Photo) {
        if let context = photo.managedObjectContext {
            context.perform {
                context.delete(photo)
                context.save(with: .deletePhoto)
            }
        }
    }

    // Function to get a list of transactions relating to photos. This is used to merge incoming transactions in the main view, since we might be getting transactions for multiple photos at once.
    func photoTransactions(from notification: Notification) -> [NSPersistentHistoryTransaction] {
        var results = [NSPersistentHistoryTransaction]()
        if let transactions = notification.userInfo?[UserInfoKey.transactions] as? [NSPersistentHistoryTransaction] {
            let photoEntityName = Photo.entity().name
            for transaction in transactions where transaction.changes != nil {
                for change in transaction.changes! where change.changedObjectID.entity.name == photoEntityName {
                    results.append(transaction)
                    break // Jump to the next transaction.
                }
            }
        }
        return results
    }
    
    func mergeTransactions(_ transactions: [NSPersistentHistoryTransaction], to context: NSManagedObjectContext) {
        context.perform {
            for transaction in transactions {
                context.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
            }
        }
    }
}
