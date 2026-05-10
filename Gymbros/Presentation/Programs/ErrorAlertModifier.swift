import SwiftUI

extension View {
    func transientErrorAlert(error: Binding<AppError?>) -> some View {
        alert(isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    error.wrappedValue = nil
                }
            }
        )) {
            Alert(
                title: Text(LocalizedStringKey(error.wrappedValue?.titleKey ?? "error.unknown.title")),
                message: Text(LocalizedStringKey(error.wrappedValue?.messageKey ?? "error.unknown.message")),
                dismissButton: .default(Text("common.ok")) {
                    error.wrappedValue = nil
                }
            )
        }
    }
}
