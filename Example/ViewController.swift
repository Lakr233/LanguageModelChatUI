//
//  ViewController.swift
//  Example
//
//  Created by qaq on 9/3/2026.
//

import ChatClientKit
import ConfigurableKit
import LanguageModelChatUI
import UIKit

class ViewController: ConfigurableViewController {
    let toolProvider: DemoAlertTool.Provider

    init() {
        let toolProvider = DemoAlertTool.Provider()
        self.toolProvider = toolProvider
        super.init(manifest: Self.buildManifest(toolProvider: toolProvider))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Models"

        // Fix navigation bar blur by extending scroll view under the bar
        scrollView.contentInsetAdjustmentBehavior = .automatic
        for constraint in view.constraints where constraint.firstAttribute == .top {
            if (constraint.firstItem as? UIView) === scrollView {
                constraint.isActive = false
                break
            }
        }
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "dice"),
            style: .plain,
            target: self,
            action: #selector(openRandomModel)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openAPIKeys)
        )
    }

    @objc func openRandomModel() {
        guard let def = modelDefinitions.randomElement() else { return }
        openModel(def)
    }

    @objc func openAPIKeys() {
        let vc = APIKeysViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func openModel(_ def: ModelDefinition) {
        guard !def.requiredAPIKey.currentValue.isEmpty else {
            presentAPIKeyMissingAlert(for: def)
            return
        }
        let chatVC = Self.makeChatViewController(for: def, toolProvider: toolProvider, navigated: true)
        navigationController?.pushViewController(chatVC, animated: true)
    }

    func presentAPIKeyMissingAlert(for def: ModelDefinition) {
        let key = def.requiredAPIKey
        let alert = UIAlertController(
            title: "API Key Required",
            message: "\(def.title) requires a \(key.displayName) API key. Please configure it first.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
            let vc = APIKeysViewController(autoEditKey: key)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        alert.addAction(settingsAction)
        alert.preferredAction = settingsAction
        present(alert, animated: true)
    }

    // MARK: - Manifest

    static func buildManifest(toolProvider: DemoAlertTool.Provider) -> ConfigurableManifest {
        let items: [ConfigurableObject] = modelDefinitions.map { def in
            ConfigurableObject(
                icon: def.icon,
                title: def.title,
                explain: def.subtitle,
                ephemeralAnnotation: .action { vc in
                    guard let root = vc as? ViewController ?? vc.navigationController?.viewControllers.first as? ViewController else { return }
                    root.openModel(def)
                }
            )
        }

        return ConfigurableManifest(
            title: "Models",
            list: items,
            footer: "Powered by FlowDown"
        )
    }

    // MARK: - Chat Factory

    static func makeChatViewController(
        for def: ModelDefinition,
        toolProvider: DemoAlertTool.Provider,
        navigated: Bool
    ) -> ChatViewController {
        let model = def.createModel()
        let chatVC = ChatViewController(
            models: .init(chat: model, titleGeneration: model),
            sessionConfiguration: .init(
                storage: DisposableStorageProvider.shared,
                tools: toolProvider,
                systemPrompt: def.systemPrompt,
                collapseReasoningWhenComplete: def.collapseReasoning
            )
        )
        chatVC.prefersNavigationBarManaged = navigated
        let wrapper = ModelChatMenuWrapper(chatViewController: chatVC, def: def)
        chatVC.menuDelegate = wrapper
        return chatVC
    }
}
