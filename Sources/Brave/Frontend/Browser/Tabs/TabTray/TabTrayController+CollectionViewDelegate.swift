// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

// MARK: UICollectionViewDelegate

extension TabTrayController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let tab = dataSource.itemIdentifier(for: indexPath) else { return }
    tabManager.selectTab(tab)

    tabTraySearchController.isActive = false
    dismiss(animated: true)
  }
  
  func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
    return self.collectionView(collectionView, contextMenuConfigurationForItemsAt: [indexPath], point: point)
  }
  
  func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(actionProvider: { suggestedActions in
      if indexPaths.count == 0 {
        // Construct an empty-space menu.
        return UIMenu(children: [
          UIAction(title: "New Tab") { _ in /* Implement the action. */ },
          UIAction(title: "New Private Tab") { _ in /* Implement the action. */ }
        ])
      } else if indexPaths.count == 1 {
        // Construct a single-item menu.
        return UIMenu(children: [
          UIMenu(title: "Move to Tab Group", children: [UIAction(title: "Move to Tab Group") { _ in /* Implement the action. */ },
                            UIAction(title: "New Tab Group") { _ in /* Implement the action. */ }]),
          UIAction(title: "Close Tab", attributes: .destructive) { _ in /* Implement the action. */ },
          UIAction(title: "Close Other Tabs", attributes: .destructive) { _ in /* Implement the action. */ }
        ])
      } else {
        // Construct a multiple-item menu.
        return UIMenu(children: [
          UIAction(title: "Move to Tab Group") { _ in /* Implement the action. */ },
          UIAction(title: "Delete", attributes: .destructive) { _ in /* Implement the action. */ }
        ])
      }
    })
  }
}

// MARK: UICollectionViewDragDelegate

extension TabTrayController: UICollectionViewDragDelegate {
  func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard let tab = dataSource.itemIdentifier(for: indexPath) else { return [] }

    UIImpactFeedbackGenerator(style: .medium).bzzt()

    let dragItem = UIDragItem(itemProvider: NSItemProvider())
    dragItem.localObject = tab
    return [dragItem]
  }
}

// MARK: UICollectionViewDropDelegate

extension TabTrayController: UICollectionViewDropDelegate {
  func collectionView(
    _ collectionView: UICollectionView,
    performDropWith coordinator: UICollectionViewDropCoordinator
  ) {

    guard let dragItem = coordinator.items.first?.dragItem,
      let tab = dragItem.localObject as? Tab,
      let destinationIndexPath = coordinator.destinationIndexPath
    else { return }

    _ = coordinator.drop(dragItem, toItemAt: destinationIndexPath)
    tabManager.moveTab(tab, toIndex: destinationIndexPath.item)
    delegate?.tabOrderChanged()
    applySnapshot()
  }

  func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {

    guard let localDragSession = session.localDragSession,
      let item = localDragSession.items.first,
      let tab = item.localObject as? Tab
    else {
      return .init(operation: .forbidden)
    }

    if dataSource.indexPath(for: tab) == nil {
      return .init(operation: .cancel)
    }

    return .init(operation: .move, intent: .insertAtDestinationIndexPath)
  }
}
