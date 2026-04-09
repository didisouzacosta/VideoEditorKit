import Foundation

extension TimeInterval {

    // MARK: - Public Methods

    func formatterTimeString() -> String {
        guard isFinite, self >= 0 else {
            return "00:00"
        }

        let totalSeconds = Int(self.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours.twoDigitString):\(minutes.twoDigitString):\(seconds.twoDigitString)"
        }

        let totalMinutes = totalSeconds / 60
        return "\(totalMinutes.twoDigitString):\(seconds.twoDigitString)"
    }

}

extension BinaryInteger {

    // MARK: - Private Properties

    fileprivate var twoDigitString: String {
        let digits = String(self)
        return digits.count == 1 ? "0\(digits)" : digits
    }

}
