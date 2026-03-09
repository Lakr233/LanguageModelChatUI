//
//  APIKeysViewController.swift
//  Example
//
//  Created by qaq on 9/3/2026.
//

import ConfigurableKit
import UIKit

class APIKeysViewController: ConfigurableViewController {
    var autoEditKey: APIKeyID?

    init(autoEditKey: APIKeyID? = nil) {
        self.autoEditKey = autoEditKey
        super.init(manifest: Self.buildManifest())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let key = autoEditKey {
            autoEditKey = nil
            Self.presentAPIKeyEditor(for: key, on: self)
        }
    }

    static func buildManifest() -> ConfigurableManifest {
        let items: [ConfigurableObject] = APIKeyID.allCases.map { key in
            ConfigurableObject(
                icon: key.icon,
                title: key.displayName,
                ephemeralAnnotation: .action { vc in
                    Self.presentAPIKeyEditor(for: key, on: vc)
                }
            )
        }

        return ConfigurableManifest(
            title: "API Keys",
            list: items
        )
    }

    static func presentAPIKeyEditor(for key: APIKeyID, on vc: UIViewController) {
        let alert = UIAlertController(
            title: key.displayName,
            message: "Enter your \(key.displayName) API key",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.text = key.currentValue
            field.placeholder = "API Key"
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.spellCheckingType = .no
            field.clearButtonMode = .whileEditing
            field.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            key.currentValue = value
        }
        alert.addAction(saveAction)
        alert.preferredAction = saveAction
        vc.present(alert, animated: true)
    }
}
