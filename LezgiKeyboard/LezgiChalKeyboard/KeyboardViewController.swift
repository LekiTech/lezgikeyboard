//
//  KeyboardViewController.swift
//  LezgiChalKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var model = KeyboardModel()
    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        hostingController?.rootView = makeKeyboardView()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Update return key label when context changes
        hostingController?.rootView = makeKeyboardView()
    }

    private func setupKeyboard() {
        let hc = UIHostingController(rootView: makeKeyboardView())
        hostingController = hc

        addChild(hc)
        view.addSubview(hc.view)
        hc.didMove(toParent: self)

        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        hc.view.clipsToBounds = false   // allow key preview bubble to appear above keyboard
        hc.view.insetsLayoutMarginsFromSafeArea = false
        view.clipsToBounds = false

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let h = view.heightAnchor.constraint(equalToConstant: 242)
        h.priority = UILayoutPriority(999)
        h.isActive = true
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        additionalSafeAreaInsets = UIEdgeInsets(
            top: -view.safeAreaInsets.top,
            left: -view.safeAreaInsets.left,
            bottom: -view.safeAreaInsets.bottom,
            right: -view.safeAreaInsets.right
        )
    }

    private func makeKeyboardView() -> KeyboardView {
        KeyboardView(
            model: model,
            needsGlobe: needsInputModeSwitchKey,
            returnKeyType: textDocumentProxy.returnKeyType ?? .default
        ) { [weak self] cap in
            guard let self else { return }
            if cap == .globe {
                self.advanceToNextInputMode()
                return
            }
            self.model.handleKey(cap, proxy: self.textDocumentProxy)
        }
    }
}
