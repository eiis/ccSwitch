import AppKit
import Foundation

@MainActor
final class AlertSoundPlayer {
    enum Event: Hashable {
        case manualSwitched
        case autoSwitched
        case noUsableAccount
    }

    private var lastPlayedAtByEvent: [Event: Date] = [:]
    private let minimumInterval: TimeInterval = 10

    func play(_ event: Event) {
        if event == .manualSwitched {
            playSound(named: soundName(for: event))
            return
        }

        let now = Date()
        if let lastPlayedAt = lastPlayedAtByEvent[event],
           now.timeIntervalSince(lastPlayedAt) < minimumInterval {
            return
        }

        lastPlayedAtByEvent[event] = now
        playSound(named: soundName(for: event))
    }

    private func playSound(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            return
        }
        sound.play()
    }

    private func soundName(for event: Event) -> String {
        switch event {
        case .manualSwitched:
            return "Tink"
        case .autoSwitched:
            return "Hero"
        case .noUsableAccount:
            return "Basso"
        }
    }
}
