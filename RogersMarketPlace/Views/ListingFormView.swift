//
//  ListingFormView.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import PhotosUI
import SwiftUI

/// Create (listing == nil) or edit a listing. Works the same offline: the repository
/// saves it locally as pending and the view model syncs when we are online.
struct ListingFormView: View {
    let listing: Listing?
    @ObservedObject var viewModel: MarketplaceViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var category = AppConfig.categories[0]
    @State private var location = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showCamera = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title).accessibilityIdentifier("form-title")
                    TextField("Description", text: $description, axis: .vertical).accessibilityIdentifier("form-description")
                    TextField("Price (CAD)", text: $priceText).keyboardType(.decimalPad).accessibilityIdentifier("form-price")
                    Picker("Category", selection: $category) { ForEach(AppConfig.categories, id: \.self) { Text($0) } }
                    TextField("Location", text: $location).accessibilityIdentifier("form-location")
                }
                Section("Photo") {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                    }
                    PhotosPicker("Choose from library", selection: $selectedPhoto, matching: .images)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take a photo") { showCamera = true }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("form-error") }
                }
            }
            .navigationTitle(listing == nil ? "New Listing" : "Edit Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(listing == nil ? "Post" : "Save") { Task { await save() } }.accessibilityIdentifier("form-save")
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { photoData = try? await item?.loadTransferable(type: Data.self) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { photoData = $0 }.ignoresSafeArea()
            }
            .onAppear {
                guard let listing, title.isEmpty else { return }
                title = listing.title
                description = listing.description
                priceText = "\(listing.price)"
                category = AppConfig.categories.contains(listing.category) ? listing.category : AppConfig.categories.last!
                location = listing.location
            }
        }
    }

    private func save() async {
        errorMessage = nil
        guard let price = Decimal(string: priceText) else { return errorMessage = "Enter a valid price." }
        do {
            let imageName = photoData.flatMap(ImageStorage.saveImage)
            let draft = ListingDraft(title: title, description: description, price: price, category: category, location: location, localImageName: imageName)
            if let listing {
                try await viewModel.update(listing.id, with: draft)
            } else {
                try await viewModel.create(draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) { parent.onImage(data) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
