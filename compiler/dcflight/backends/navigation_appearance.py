"""Ordinary app-owned UIKit tab controller; no global appearance mutation."""
IOS_TABS = r'''import SwiftUI
import UIKit

struct AuthoredTabItem {
    let id: String
    let title: String
    let symbol: String
    let content: AnyView
}

struct AuthoredNativeTabs: UIViewControllerRepresentable {
    let items: [AuthoredTabItem]
    @Binding var selection: String
    var selectedForeground: UIColor?
    var unselectedForeground: UIColor?
    var surface: UIColor?

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }
    func makeUIViewController(context: Context) -> UITabBarController {
        let controller = UITabBarController()
        controller.delegate = context.coordinator
        update(controller, context: context)
        return controller
    }
    func updateUIViewController(_ controller: UITabBarController, context: Context) {
        update(controller, context: context)
    }
    private func update(_ controller: UITabBarController, context: Context) {
        let coordinator = context.coordinator
        coordinator.selection = $selection
        let ids = items.map(\.id)
        precondition(Set(ids).count == ids.count && ids.contains(selection))
        var ordered: [UIViewController] = []
        for item in items {
            let content = AnyView(item.content.environment(\.self, context.environment).id(item.id))
            let host: UIHostingController<AnyView>
            if let retained = coordinator.hosts[item.id] {
                host = retained
                host.rootView = content
            } else {
                host = UIHostingController(rootView: content)
                coordinator.hosts[item.id] = host
            }
            host.tabBarItem.title = item.title
            host.tabBarItem.image = UIImage(systemName: item.symbol)
            host.tabBarItem.accessibilityIdentifier = "tab." + item.id
            ordered.append(host)
        }
        if coordinator.ids != ids {
            controller.setViewControllers(ordered, animated: false)
            coordinator.ids = ids
            coordinator.hosts = coordinator.hosts.filter { ids.contains($0.key) }
        }
        if let index = ids.firstIndex(of: selection), controller.selectedIndex != index {
            controller.selectedIndex = index
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        if let surface { appearance.configureWithOpaqueBackground(); appearance.backgroundColor = surface }
        for itemAppearance in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            if let selectedForeground {
                itemAppearance.selected.iconColor = selectedForeground
                itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedForeground]
            }
            if let unselectedForeground {
                itemAppearance.normal.iconColor = unselectedForeground
                itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedForeground]
            }
        }
        controller.tabBar.standardAppearance = appearance
        controller.tabBar.scrollEdgeAppearance = appearance
        controller.tabBar.tintColor = selectedForeground
        controller.tabBar.unselectedItemTintColor = unselectedForeground
    }
    @MainActor final class Coordinator: NSObject, UITabBarControllerDelegate {
        var selection: Binding<String>
        var ids: [String] = []
        var hosts: [String: UIHostingController<AnyView>] = [:]
        init(selection: Binding<String>) { self.selection = selection }
        func tabBarController(_ controller: UITabBarController, didSelect viewController: UIViewController) {
            guard let index = controller.viewControllers?.firstIndex(where: { $0 === viewController }), ids.indices.contains(index) else { return }
            selection.wrappedValue = ids[index]
        }
    }
}
'''
