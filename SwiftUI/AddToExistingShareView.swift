/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SwiftUI view that adds a photo to an existing share.
*/
#warning("UI: The communication between UI and the container (adding/removing) is the same everywhere. 1) update UI, 2) async function to shareObject or purge, 3) update UI, 4) close sheet")

import SwiftUI
import CoreData
import CloudKit

struct AddToExistingShareView: View {
    @Binding var activeSheet: ActiveSheet?
    var photo: Photo
    
    @State private var toggleProgress: Bool = false
    @State private var selection: String?

    var body: some View {
        ZStack {
            SharePickerView(activeSheet: $activeSheet, selection: $selection) {
                Button("Add") { sharePhoto(photo, shareTitle: selection) }
                .disabled(selection == nil)
            }
            if toggleProgress {
                ProgressView()
            }
        }
    }

    // The communication with the container (adding/removing) is the same everywhere. 1) update UI, 2) async function to shareObject or purge, 3) update UI, 4) close sheet. 0.1 second delay is to allow UI to update, before we execute our logic.
    private func sharePhoto(_ unsharedPhoto: Photo, shareTitle: String?) {
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let persistenceController = PersistenceController.shared
            if let shareTitle = shareTitle, let share = persistenceController.share(with: shareTitle) {
                persistenceController.shareObject(unsharedPhoto, to: share)
            }
            toggleProgress.toggle()
            activeSheet = nil
        }
    }
}
