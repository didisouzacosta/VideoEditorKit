//
//  TimeInterval+Ext.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation

extension TimeInterval {
    var minutesSecondsMilliseconds: String {
        guard isFinite, self >= 0 else {
            return "00:00:00"
        }

        let totalSeconds = Int(self.rounded(.down))
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((self * 100).rounded(.down)) % 100

        return "\(minutes.twoDigitString):\(seconds.twoDigitString):\(centiseconds.twoDigitString)"
    }

    var minuteSeconds: String {
        guard isFinite, self > 0 else {
            return "unknown"
        }

        let totalSeconds = Int(self.rounded(.down))
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60

        return "\(minutes.twoDigitString):\(seconds.twoDigitString)"
    }

    func formatterTimeString() -> String {
        guard isFinite, self >= 0 else {
            return "0:00.0"
        }

        let totalSeconds = Int(self.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = Int((self.truncatingRemainder(dividingBy: 1) * 10).rounded(.down))

        return "\(minutes):\(seconds.twoDigitString).\(tenths)"
    }
}

extension Int {
    func secondsToTime() -> String {
        let totalSeconds = Swift.max(0, self)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return "\(minutes.twoDigitString):\(seconds.twoDigitString)"
    }
}

private extension BinaryInteger {
    var twoDigitString: String {
        let digits = String(self)
        return digits.count == 1 ? "0\(digits)" : digits
    }
}
