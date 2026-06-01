import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTap() -> some View {
        background(KeyboardDismissGestureInstaller())
    }
}

private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        KeyboardDismissInstallerView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        KeyboardDismissTapHandler.shared.install(from: uiView)
    }
}

private final class KeyboardDismissInstallerView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        KeyboardDismissTapHandler.shared.install(from: self)
    }
}

private final class KeyboardDismissTapHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTapHandler()
    private static var recognizerKey: UInt8 = 0

    func install(from view: UIView) {
        guard let window = view.window,
              objc_getAssociatedObject(window, &Self.recognizerKey) == nil else {
            return
        }

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        objc_setAssociatedObject(window, &Self.recognizerKey, recognizer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        isTextInput(touch.view) == false
    }

    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func isTextInput(_ view: UIView?) -> Bool {
        var current = view
        while let candidate = current {
            if candidate is UITextField || candidate is UITextView {
                return true
            }
            current = candidate.superview
        }
        return false
    }
}
