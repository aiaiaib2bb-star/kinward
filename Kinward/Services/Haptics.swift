import UIKit

@MainActor
enum Haptics {
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()

    static func prepare() { soft.prepare(); light.prepare(); rigid.prepare() }
    static func tap() { light.impactOccurred(intensity: 0.55) }
    static func detent() { rigid.impactOccurred(intensity: 0.42) }
    static func settle() { soft.impactOccurred(intensity: 0.8) }
    static func kept() { notice.notificationOccurred(.success) }
}
