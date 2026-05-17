import SwiftUI

/// A bottom-sheet for entering a Kino server URL manually.
struct ManualURLEntryView: View {
  @Binding var isPresented: Bool
  let onSubmit: (String) async -> Void

  @State private var raw: String = ""
  @State private var isSubmitting = false

  private var isValidURL: Bool {
    guard let url = URL(string: raw), url.host != nil else { return false }
    return true
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("http://192.168.1.20:7000", text: $raw)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { submitIfValid() }
        } header: {
          Text("Server address")
        } footer: {
          Text("Enter the IP address or hostname of your Kino server.")
            .font(.caption)
        }

        Section {
          Button {
            submitIfValid()
          } label: {
            HStack {
              Spacer()
              if isSubmitting {
                ProgressView()
                  .controlSize(.small)
              } else {
                Text("Continue")
                  .font(.body.weight(.semibold))
              }
              Spacer()
            }
          }
          .disabled(!isValidURL || isSubmitting)
        }
      }
      .navigationTitle("Enter server URL")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { isPresented = false }
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func submitIfValid() {
    guard isValidURL, !isSubmitting else { return }
    isSubmitting = true
    Task {
      await onSubmit(raw)
      isPresented = false
    }
  }
}
