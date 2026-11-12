import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import ContextUI
import UndoUI

extension PeerInfoScreenNode {
    func openPeerId(value: String, node: ASDisplayNode, gesture: ContextGesture?, progress: Promise<Bool>?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }

        let sample = self.presentationData.strings.Common_Back
        let copyTitle = jokerLocalize(sample: sample, arValue: "نسخ", enValue: "Copy")
        let copiedText = jokerLocalize(sample: sample, arValue: "تم نسخ المعرّف", enValue: "ID copied")

        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = value
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: copiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }

        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: copyTitle, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss {
                    copyAction()
                }
            }))
        ]
        let actions = ContextController.Items(content: .list(items))
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
