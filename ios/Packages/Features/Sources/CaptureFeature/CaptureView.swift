import ComposableArchitecture
import DesignSystem
import Domain
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public struct CaptureView: View {
  @Bindable private var store: StoreOf<CaptureFeature>
  @State private var selectedPhotoItems: [PhotosPickerItem] = []

  public init(store: StoreOf<CaptureFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack {
      if store.isLocationPromptPresented {
        LocationPermissionSheetView(
          onAllowTapped: { store.send(.allowLocationTapped) },
          onSkipTapped: { store.send(.skipLocationTapped) }
        )
      } else if store.isProcessing {
        processingView
      } else if let errorMessage = store.errorMessage {
        errorView(errorMessage)
      } else if store.source == .camera && store.isPickerPresented {
        cameraContentView
      } else {
        Color.clear
      }
    }
    .task {
      await store.send(.task).finish()
    }
    .photosPicker(
      isPresented: Binding(
        get: { store.source == .photoLibrary && store.isPickerPresented },
        set: { isPresented in
          if !isPresented && selectedPhotoItems.isEmpty && !store.isProcessing {
            store.send(.pickerCancelled)
          }
        }
      ),
      selection: $selectedPhotoItems,
      matching: .images
    )
    .onChange(of: selectedPhotoItems) { _, items in
      guard !items.isEmpty else {
        return
      }
      Task {
        await loadSelectedPhotos(items)
      }
    }
    .fileImporter(
      isPresented: Binding(
        get: { store.source == .files && store.isPickerPresented },
        set: { _ in }
      ),
      allowedContentTypes: [.image],
      allowsMultipleSelection: true,
      onCompletion: { result in
        handleFileImportResult(result)
      },
      onCancellation: {
        store.send(.pickerCancelled)
      }
    )
  }

  @ViewBuilder
  private var cameraContentView: some View {
    if CameraImagePickerView.isCameraAvailable {
      CameraImagePickerView(
        onCapture: { data in store.send(.cameraPhotoCaptured(data)) },
        onCancel: { store.send(.pickerCancelled) }
      )
      .ignoresSafeArea()
    } else {
      VStack(spacing: Spacing.md) {
        ContentUnavailableView(
          L10n.string("capture.camera.unavailable"),
          systemImage: "camera.fill"
        )
        GlassActionButton(
          title: L10n.string("apartments.create.cancel.cta"),
          variant: .secondary,
          expandsHorizontally: false
        ) {
          store.send(.cancelTapped)
        }
      }
      .padding(Spacing.lg)
    }
  }

  private var processingView: some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.lg) {
      VStack(spacing: Spacing.md) {
        ProgressView()
        Text(L10n.string("capture.processing.label"))
          .font(Typography.callout)
      }
    }
  }

  private func errorView(_ message: String) -> some View {
    GlassCard(cornerRadius: CornerRadius.lg, padding: Spacing.lg) {
      VStack(spacing: Spacing.md) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.largeTitle)
          .foregroundStyle(.yellow)
        Text(message)
          .font(Typography.body)
          .multilineTextAlignment(.center)
        GlassActionButton(
          title: L10n.string("apartments.create.cancel.cta"),
          variant: .secondary
        ) {
          store.send(.cancelTapped)
        }
      }
    }
    .padding(Spacing.lg)
  }

  private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
    var rawDataList: [Data] = []
    rawDataList.reserveCapacity(items.count)
    for item in items {
      if let data = try? await item.loadTransferable(type: Data.self) {
        rawDataList.append(data)
      }
    }
    selectedPhotoItems = []
    if rawDataList.isEmpty {
      store.send(.ingestFailed(L10n.string("capture.import.failed")))
    } else {
      store.send(.importedPhotosSelected(rawDataList))
    }
  }

  private func handleFileImportResult(_ result: Result<[URL], any Error>) {
    switch result {
    case .failure:
      store.send(.ingestFailed(L10n.string("capture.import.failed")))
    case .success(let urls):
      guard !urls.isEmpty else {
        store.send(.pickerCancelled)
        return
      }
      var rawDataList: [Data] = []
      rawDataList.reserveCapacity(urls.count)
      for url in urls {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
          if didAccess {
            url.stopAccessingSecurityScopedResource()
          }
        }
        if let data = try? Data(contentsOf: url) {
          rawDataList.append(data)
        }
      }
      if rawDataList.isEmpty {
        store.send(.ingestFailed(L10n.string("capture.import.failed")))
      } else {
        store.send(.importedPhotosSelected(rawDataList))
      }
    }
  }
}
