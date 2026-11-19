import ComposableArchitecture
import DesignSystem
import Domain
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public struct CaptureFlowModifier: ViewModifier {
  private let store: StoreOf<CaptureFeature>?
  @State private var selectedItems: [PhotosPickerItem] = []

  public init(store: StoreOf<CaptureFeature>?) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    baseFlowContent(content)
      .photosPicker(
        isPresented: pickerBinding(for: .photoLibrary),
        selection: $selectedItems,
        maxSelectionCount: CaptureConstants.maxImportCount,
        matching: .images
      )
      .onChange(of: selectedItems) { _, items in
        guard !items.isEmpty else {
          return
        }
        store?.send(.photoSelectionStarted)
        let activeStore = store
        Task {
          let rawDataList = await CaptureImportHelpers.loadTransferableData(from: items)
          selectedItems = []
          if rawDataList.isEmpty {
            activeStore?.send(.ingestFailed(L10n.string("capture.import.failed")))
          } else {
            activeStore?.send(.importedPhotosSelected(rawDataList))
          }
        }
      }
      .fileImporter(
        isPresented: pickerBinding(for: .files),
        allowedContentTypes: [.image],
        allowsMultipleSelection: true,
        onCompletion: handleFileImportResult,
        onCancellation: { store?.send(.pickerCancelled) }
      )
      .overlay {
        if store?.isProcessing == true {
          CaptureProcessingHUDView()
            .transition(.opacity)
        }
      }
      .alert(
        L10n.string("capture.import.failed.title"),
        isPresented: errorBinding
      ) {
        Button(L10n.string("common.ok")) {
          store?.send(.dismissError)
        }
      } message: {
        Text(store?.errorMessage ?? "")
      }
  }

  @ViewBuilder
  private func baseFlowContent(_ content: Content) -> some View {
    let withLocationSheet = content.sheet(
      isPresented: locationPromptBinding,
      onDismiss: { store?.send(.locationPromptDidDismiss) },
      content: {
        LocationPermissionSheetView(
          onAllowTapped: { store?.send(.allowLocationTapped) },
          onSkipTapped: { store?.send(.skipLocationTapped) }
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
      }
    )

    #if os(iOS)
      withLocationSheet.fullScreenCover(
        isPresented: pickerBinding(for: .camera),
        onDismiss: { store?.send(.pickerDismissalSettled) },
        content: {
          cameraCoverContent
        }
      )
    #else
      withLocationSheet
    #endif
  }

  #if os(iOS)
    @ViewBuilder
    private var cameraCoverContent: some View {
      if CameraImagePickerView.isCameraAvailable {
        CameraImagePickerView(
          onCapture: { store?.send(.cameraPhotoCaptured($0)) },
          onCancel: { store?.send(.pickerCancelled) }
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
            store?.send(.pickerCancelled)
          }
        }
        .padding(Spacing.lg)
      }
    }
  #endif

  private var locationPromptBinding: Binding<Bool> {
    Binding(
      get: { store?.isLocationPromptPresented == true },
      set: { isPresented in
        if !isPresented {
          store?.send(.skipLocationTapped)
        }
      }
    )
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { store?.errorMessage != nil && store?.isPickerDismissalSettled == true },
      set: { isPresented in
        if !isPresented {
          store?.send(.dismissError)
        }
      }
    )
  }

  private func pickerBinding(for kind: CaptureSourceKind) -> Binding<Bool> {
    Binding(
      get: { store?.source == kind && store?.isPickerPresented == true },
      set: { isPresented in
        if !isPresented {
          store?.send(.pickerDismissed)
        }
      }
    )
  }

  private func handleFileImportResult(_ result: Result<[URL], any Error>) {
    switch result {
    case .failure:
      store?.send(.ingestFailed(L10n.string("capture.import.failed")))
    case .success(let urls):
      guard !urls.isEmpty else {
        store?.send(.pickerCancelled)
        return
      }
      let rawDataList = CaptureImportHelpers.readSecurityScopedData(from: urls)
      if rawDataList.isEmpty {
        store?.send(.ingestFailed(L10n.string("capture.import.failed")))
      } else {
        store?.send(.importedPhotosSelected(rawDataList))
      }
    }
  }
}

extension View {
  public func captureFlow(_ store: StoreOf<CaptureFeature>?) -> some View {
    modifier(CaptureFlowModifier(store: store))
  }
}
