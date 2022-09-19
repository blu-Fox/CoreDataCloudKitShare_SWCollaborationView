/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SwiftUI view that manages the participants of a share.
*/
#warning("UI: An important view for showing participants to a shared object. Comments were added for faster adoption. On iOS, we can open the Controller. On watchOS, the Controller is unavailable, so we can use this custom view.")

import SwiftUI
import CoreData
import CloudKit

/**
 Managing a participant only makes sense when the share exists.
 A private share is a share with the .none public permission.
 A public share is a share with a more-permissive public permission. Any person who has the share link can
 self-add themselves to a public share.
 */
// Public is only mentioned in this comment.
struct ParticipantView: View {
    @Binding var activeSheet: ActiveSheet?
    private let share: CKShare

    @State private var toggleProgress: Bool = false
    @State private var participants: [Participant]
    @State private var wasShareDeleted = false
    
    private let canUpdateParticipants: Bool
    
    init(activeSheet: Binding<ActiveSheet?>, share: CKShare) {
        _activeSheet = activeSheet
        self.share = share
        // How to get all participants who are not the owner
        participants = share.participants.filter { $0.role != .owner }.map { Participant($0) }
        // If the share is in a private store, it means the user is OWNER, so they can update particpants
        let privateStore = PersistenceController.shared.privatePersistentStore
        canUpdateParticipants = (share.persistentStore == privateStore)
    }

    var body: some View {
        NavigationView {
            VStack {
              // Same as tagging or rating view. Update should listen to changes and in case of remote delete, show this
                if wasShareDeleted {
                    Text("The share was deleted remotely.").padding()
                    Spacer()
                } else {
                    participantListView()
                }
            }
            .toolbar { toolbarItems() }
            .listStyle(.plain)
            .navigationTitle("Participants")
        }
        // Listen to changes
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }
    
    /**
     List -> Section header + section content triggers a strange animation when deleting an item.
     Moving the header out (like below) fixes the animation issue, but the toolbar item doesn't work in watchOS.
     ParticipantListHeader(participants: $participants, share: share)
         .padding(EdgeInsets(top: 5, leading: 10, bottom: 0, trailing: 0))
     List {
         SectionContent()
     }
     */
    @ViewBuilder
    private func participantListView() -> some View {
        ZStack {
            List {
                Section(header: sectionHeader()) {
                    sectionContent()
                }
            }
            if toggleProgress {
                ProgressView()
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader() -> some View {
        if canUpdateParticipants {
            ParticipantListHeader(toggleProgress: $toggleProgress,
                                  participants: $participants, share: share)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func sectionContent() -> some View {
        ForEach(participants, id: \.self) { participant in
            HStack {
                // Participant details
                Text(participant.ckShareParticipant.userIdentity.lookupInfo?.emailAddress ?? "")
                Spacer()
                Text(participant.ckShareParticipant.acceptanceStatus.stringValue)
            }
        }
        .onDelete(perform: canUpdateParticipants ? deleteParticipant : nil)
    }
    
    @ToolbarContentBuilder
    private func toolbarItems() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button("Dismiss") { activeSheet = nil }
        }
        /**
         "Copy Link" is only available for iOS because watchOS doesn't support UIPasteboard.
         */
        #if os(iOS)
        ToolbarItem(placement: .bottomBar) {
            Button("Copy Link") { UIPasteboard.general.url = share.url }
        }
        #endif
    }

  // Function to delete a participant.
    private func deleteParticipant(offsets: IndexSet) {
        withAnimation {
            // take the index of the row to look up the corresponding participant in the array of participants.
            let ckShareParticipants = offsets.map { participants[$0].ckShareParticipant }
            // delete participant
            PersistenceController.shared.deleteParticipant(ckShareParticipants, share: share) { share, error in
                if error == nil, let updatedShare = share {
                    // update the array of participants (this should also refresh UI)
                    participants = updatedShare.participants.filter { $0.role != .owner }.map { Participant($0) }
                }
            }
        }
    }
    
    /**
     Ignore the notification in the following cases:
     - The notification isn't relevant to the private database.
     - The notification transaction isn't empty. When a share changes, Core Data triggers a store remote change notification with no transaction. In that case, grab the share with the same title, and use it to update the UI.
     */
    private func processStoreChangeNotification(_ notification: Notification) {
        // Ignore a change that happened outside of user's private database. This is because editing participants can only be done by OWNER in their private database. Everything else is irrelevant for this view, so no need to update UI.
        guard let storeUUID = notification.userInfo?[UserInfoKey.storeUUID] as? String,
              storeUUID == PersistenceController.shared.privatePersistentStore.identifier else {
            return
        }
        // Ignore a change where the transaction IS NOT empty. An empty transaction signifies share change
        guard let transactions = notification.userInfo?[UserInfoKey.transactions] as? [NSPersistentHistoryTransaction],
              transactions.isEmpty else {
            return
        }
        // If we still have some kind of share (i.e. it was changed, not deleted), update the list of participants
        if let updatedShare = PersistenceController.shared.share(with: share.title) {
            participants = updatedShare.participants.filter { $0.role != .owner }.map { Participant($0) }
        // If we got an update and no share, it means it was deleted. Update the UI accordinly.
        } else {
            wasShareDeleted = true
        }
    }
}

private struct ParticipantListHeader: View {
    @Binding var toggleProgress: Bool
    @Binding var participants: [Participant]
    var share: CKShare
    @State private var emailAddress: String = ""

    var body: some View {
        HStack {
            TextField( "Email", text: $emailAddress)
            Button(action: addParticipant) {
                Image(systemName: "plus.circle")
                    .imageScale(.large)
                    .font(.system(size: 18))
            }
            .frame(width: 20)
            .buttonStyle(.plain)
        }
        .frame(height: 30)
        .padding(5)
        .background(Color.listHeaderBackground)
    }
    
    /**
     If the participant already exists, there's no need to do anything.
     */
    // Add a  new participant, if they do not already exist. 0.1 second delay is to allow UI to update, before we execute our logic.
    private func addParticipant() {
        let isExistingParticipant = share.participants.contains {
            $0.userIdentity.lookupInfo?.emailAddress == emailAddress
        }
        if isExistingParticipant {
            return
        }
        
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PersistenceController.shared.addParticipant(emailAddress: emailAddress, share: share) { share, error in
                if error == nil, let updatedShare = share {
                    DispatchQueue.main.async {
                        participants = updatedShare.participants.filter { $0.role != .owner }.map { Participant($0) }
                        emailAddress = ""
                        toggleProgress.toggle()
                    }
                }
            }
        }
    }
}

/**
 A structure that wraps CKShare.Participant and implements Equatable to trigger SwiftUI updates when any of the following state changes:
 - userIdentity
 - acceptanceStatus
 - permission
 - role
 */
// Self-explanatory, as above
private struct Participant: Hashable, Equatable {
    let ckShareParticipant: CKShare.Participant

    init(_ ckShareParticipant: CKShare.Participant) {
        self.ckShareParticipant = ckShareParticipant
    }

    static func == (lhs: Participant, rhs: Participant) -> Bool {
        let lhsElement = lhs.ckShareParticipant
        let rhsElement = rhs.ckShareParticipant
        
        if lhsElement.userIdentity != rhsElement.userIdentity ||
            lhsElement.acceptanceStatus != rhsElement.acceptanceStatus ||
            lhsElement.permission != rhsElement.permission ||
            lhsElement.role != rhsElement.role {
            return false
        }
        return true
    }
}
