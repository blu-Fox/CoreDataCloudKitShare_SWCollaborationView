/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A SwiftUI view that shows a scrollable full-size image.
 */

import SwiftUI

struct FullImageView: View {
  @Binding var activeCover: ActiveCover?
  var photo: Photo
  @State var showPopover = false

  private var photoImage: UIImage? {
    let photoData = photo.photoData?.data
    return photoData != nil ? UIImage(data: photoData!) : nil
  }

  var body: some View {
    NavigationView {
      VStack {
        if let image = photoImage {
          ScrollView([.horizontal, .vertical]) {
            Image(uiImage: image)
          }
        } else {
          Text("The full size image is probably not downloaded from CloudKit.").padding()
          Spacer()
        }
      }
      .toolbar {
        #if os(iOS)
        if let existingShare = PersistenceController.shared.existingShare(photo: photo) {
          ToolbarItem(placement: .automatic) {
            Button(action: {
              showPopover.toggle()
            }){
              CollaborationView(existingShare: existingShare)
            }
            .popover(isPresented: $showPopover) {
              CollaborationView(existingShare: existingShare)
            }
            .padding(.horizontal)
          }
        }
        #endif
        ToolbarItem(placement: .automatic) {
          Button("Dismiss") { activeCover = nil }
        }
      }
      .listStyle(.plain)
      .navigationTitle("Full Size Photo")
    }
  }
}

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
