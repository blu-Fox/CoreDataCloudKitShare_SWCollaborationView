//
//  CollaborationView.swift
//  CoreDataCloudKitShare
//
//  Created by Jan Stehlík on 05.01.2023.
//


#if os(iOS)

import SwiftUI
import CloudKit
import SharedWithYou

struct CollaborationView: UIViewRepresentable {
  let existingShare: CKShare
  @StateObject var viewModel = CollaborationViewModel()

  func makeUIView(context: Context) -> SWCollaborationView {
    return viewModel.getCollaborationView(existingShare: existingShare)
  }
  func updateUIView(_ uiView: SWCollaborationView, context: Context) {
  }
}

class CollaborationViewModel: ObservableObject {
  // Open SWCollaborationView for an existing CKShare
  func getCollaborationView(existingShare: CKShare) -> SWCollaborationView {
    let itemProvider = NSItemProvider()
    itemProvider.registerCKShare(existingShare,
                                 container: PersistenceController.shared.cloudKitContainer,
                                 allowedSharingOptions: .standard)
    let collaborationView = SWCollaborationView(itemProvider: itemProvider)
    collaborationView.activeParticipantCount = existingShare.participants.count
    // collaborationView.setShowManageButton(true)
    // collaborationView.cloudSharingControllerDelegate = controller
    return collaborationView
  }
}

#endif

