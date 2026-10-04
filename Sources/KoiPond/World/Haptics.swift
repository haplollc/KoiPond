//
//  Haptics.swift
//  KoiPond
//
//  A small bump under the finger when it grabs something or taps the
//  water, on devices that can play one.
//

#if os(iOS)
import UIKit
#endif

@MainActor
enum Haptics {
    enum Weight {
        case light, soft, medium
    }

    static func impact(_ weight: Weight) {
        #if os(iOS)
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch weight {
        case .light: .light
        case .soft: .soft
        case .medium: .medium
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}
