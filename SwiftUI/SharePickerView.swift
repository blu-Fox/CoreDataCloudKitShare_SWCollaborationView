/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SwiftUI view that picks an existing share.
*/
// UI: UI listens to store change notifications and updates when needed. See comments in code. Maybe we already do this when we show the indicator that iCloud is updating?

import SwiftUI
import CoreData
import CloudKit

struct SharePickerView<ActionView: View>: View {
    @Binding private var activeSheet: ActiveSheet?
    @Binding private var selection: String?
    
    private let actionView: ActionView
    @State private var shareTitles = PersistenceController.shared.shareTitles()

    init(activeSheet: Binding<ActiveSheet?>, selection: Binding<String?>, @ViewBuilder actionView: () -> ActionView) {
        _activeSheet = activeSheet
        _selection = selection
        self.actionView = actionView()
    }

    var body: some View {
        NavigationView {
            VStack {
              // Different UI if there is no share to be shown (it may have been deleted remotely while we have this open.
               if shareTitles.isEmpty {
                   Text("No share exists. Please create a new share for a photo, then try again.").padding()
                   Spacer()
               } else {
                   Form {
                       Section(header: Text("Pick a share")) {
                           ShareListView(selection: $selection, shareTitles: $shareTitles)
                       }
                       Section {
                           actionView
                       }
                   }
               }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Dismiss") { activeSheet = nil }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Shares")
        }
        // Listen to notifications
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }
    
    /**
     Update the share list, if necessary. Ignore the notification in the following cases:
     - The notification isn't relevant to the private database.
     - The notification transaction isn't empty. When a share changes, Core Data triggers a store remote change notification with no transaction.
     */
    private func processStoreChangeNotification(_ notification: Notification) {
        // Return if the change relates to the shared database. We are only interested in the private database.
        guard let storeUUID = notification.userInfo?[UserInfoKey.storeUUID] as? String,
              storeUUID == PersistenceController.shared.privatePersistentStore.identifier else {
            return
        }
        // Return if the transaction is not empty. An empty translation means a change or deletion of the share.
        guard let transactions = notification.userInfo?[UserInfoKey.transactions] as? [NSPersistentHistoryTransaction],
              transactions.isEmpty else {
            return
        }
        // If we have a notification from the private database with an empty transaction, update the list of shares.
        shareTitles = PersistenceController.shared.shareTitles()
    }

}

private struct ShareListView: View {
    @Binding var selection: String?
    @Binding var shareTitles: [String]

    var body: some View {
        List(shareTitles, id: \.self) { shareTitle in
            HStack {
                Text(shareTitle)
                Spacer()
                if selection == shareTitle {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selection = (selection == shareTitle) ? nil : shareTitle
            }
        }
    }
}

