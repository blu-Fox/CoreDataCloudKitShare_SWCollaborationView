# CoreDataCloudKitShare with UICloudSharingController and SWCollaborationView
This is a clone of Apple's sample app accessible [here](https://developer.apple.com/documentation/coredata/sharing_core_data_objects_between_icloud_users).

It differs from the original in several ways, mainly:
1) comments have been added throughout the app to better understand the code.
2) changes were made to make `UICloudSharingController` work in iOS16 (so far, without success)
3) `SWCollaborationView` was added as a an alternative to `UICloudSharingController`. Unfortunately, `SWCollaborationView` does not appear to work in SwiftUI (or at least, I'm not sure how to make it work).

To see how `SWCollaborationView` is implemented at the moment, see files `CollaborationView` and `FullImageView`.

The comments and code are quite messy at the moment - this clone only serves learning purposes, and the repo is public so others may see the issues with implementing `UICloudSharingController` and `SWCollaborationView`. Once these issues are resolved, the repo will be removed.

Before running the project, change the bundle identifier and other settings as required by the original sample app.