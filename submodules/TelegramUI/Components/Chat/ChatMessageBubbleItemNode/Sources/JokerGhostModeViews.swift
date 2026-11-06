import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Mod Bubble Views
// ط¹ظ†ط§طµط± ط§ظ„ظˆط§ط¬ظ‡ط© ط§ظ„ظ…ط¶ط§ظپط© ط¨ظˆط§ط³ط·ط© طھط¹ط¯ظٹظ„ط§طھ Talogram (ط§ظ„ط¬ظˆظƒط±)

// ط²ط± ط§ظ„ط¹ظٹظ† ظ„ظˆط¶ط¹ ط§ظ„ط´ط¨ط­: ظٹظˆط¶ط¹ ظپظˆظ‚ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظˆط§ط±ط¯ط©طŒ ظˆط¹ظ†ط¯ ط§ظ„ط¶ط؛ط· ط¹ظ„ظٹظ‡
// طھظڈط±ط³ظ„ ط¥ط´ط§ط±ط© ط§ظ„ظ‚ط±ط§ط،ط© ظ„طھظ„ظƒ ط§ظ„ط±ط³ط§ظ„ط© ظپظ‚ط· (ط£ظٹظ‚ظˆظ†ط© ط§ظ„ط¹ظٹظ† ط­ط§ظ„ظٹط§ظ‹ ظ…ط®ظپظٹط© -
// ط³ظ„ظˆظƒ ط§ظ„ط±ط¨ط· ظ…ط¹ طھط®ط·ظٹط· ط§ظ„ظپظ‚ط§ط¹ط© ظٹظڈظپط¹ظ‘ظ„ ظ„ط§ط­ظ‚ط§ظ‹)
public class JokerGhostModeEyeButton: ASDisplayNode {
    private var messageId: EngineMessage.Id
    private let onEyeTapped: (EngineMessage.Id) -> Void

    public init(messageId: EngineMessage.Id, onEyeTapped: @escaping (EngineMessage.Id) -> Void) {
        self.messageId = messageId
        self.onEyeTapped = onEyeTapped

        super.init()
        self.isOpaque = false
        self.alpha = 0.0
    }

    public func set(messageId: EngineMessage.Id) {
        self.messageId = messageId
    }

    override public func didLoad() {
        super.didLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.view.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        self.onEyeTapped(self.messageId)
    }

    // طھط­ط¯ظٹط« à¤¦à¥ƒط²ط± ط§ظ„ط¹ظٹظ† ط­ط³ط¨ ط­ط§ظ„ط© ط§ظ„ط¸ظ‡ظˆط± (ظٹظڈط³طھط¯ط¹ظ‰ ظ…ظ† طھط®ط·ظٹط· ط§ظ„ظپظ‚ط§ط¹ط©)
    public func setEyeVisible(_ visible: Bool, frame: CGRect) {
        self.alpha = visible ? 1.0 : 0.0
        self.frame = frame
        self.isUserInteractionEnabled = visible
    }
}

// ط¹ظ„ط§ظ…ط© x ط§ظ„طµط؛ظٹط±ط© ط§ظ„طھظٹ طھط¸ظ‡ط± ط¨ط¬ط§ظ†ط¨ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„طھظٹ ط­ط°ظپظ‡ط§ ط§ظ„ط·ط±ظپ ط§ظ„ط¢ط®ط±
// (ط¹ظ†ط¯ طھظپط¹ظٹظ„ ظ…ظٹط²ط© ط§ظ„ط§ط­طھظپط§ط¸ ط¨ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ط°ظˆظپط©)
public class JokerDeletedMessageMark: ASDisplayNode {
    public override init() {
        super.init()
        self.isOpaque = false
        self.alpha = 0.0
    }

    // طھط­ط¯ظٹط« ط¸ظ‡ظˆط± ط¹ظ„ط§ظ…ط© ط§ظ„ط­ط°ظپ (ظٹظڈط³طھط¯ط¹ظ‰ ظ…ظ† طھط®ط·ظٹط· ط§ظ„ظپظ‚ط§ط¹ط©)
    public func setDeletedMarkVisible(_ visible: Bool, frame: CGRect) {
        self.alpha = visible ? 1.0 : 0.0
        self.frame = frame
    }
}
