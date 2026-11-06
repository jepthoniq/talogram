import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Mod Bubble Views
// عناصر الواجهة المضافة بواسطة تعديلات Talogram (الجوكر)

// زر العين لوضع الشبح: يوضع فوق الرسائل الواردة، وعند الضغط عليه
// تُرسل إشارة القراءة لتلك الرسالة فقط (أيقونة العين حالياً مخفية -
// سلوك الربط مع تخطيط الفقاعة يُفعّل لاحقاً)
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

    // تحديث दृزر العين حسب حالة الظهور (يُستدعى من تخطيط الفقاعة)
    public func setEyeVisible(_ visible: Bool, frame: CGRect) {
        self.alpha = visible ? 1.0 : 0.0
        self.frame = frame
        self.isUserInteractionEnabled = visible
    }
}

// علامة x الصغيرة التي تظهر بجانب الرسائل التي حذفها الطرف الآخر
// (عند تفعيل ميزة الاحتفاظ بالرسائل المحذوفة)
public class JokerDeletedMessageMark: ASDisplayNode {
    public override init() {
        super.init()
        self.isOpaque = false
        self.alpha = 0.0
    }

    // تحديث ظهور علامة الحذف (يُستدعى من تخطيط الفقاعة)
    public func setDeletedMarkVisible(_ visible: Bool, frame: CGRect) {
        self.alpha = visible ? 1.0 : 0.0
        self.frame = frame
    }
}
