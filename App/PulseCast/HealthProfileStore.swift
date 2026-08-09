import Foundation
import HealthKit
import OSLog

final class HealthProfileStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.hongwei.wrist-pulse-cast", category: "Health")
    private static let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!

    @Published private(set) var age: Int?
    @Published private(set) var statusText = "等待健康授权"

    private let healthStore = HKHealthStore()

    func requestAgeAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "健康不可用"
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: [Self.dateOfBirthType]) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error {
                    Self.logger.error("Health authorization failed: \(error.localizedDescription, privacy: .public)")
                    self?.statusText = "年龄授权失败"
                    return
                }

                guard success else {
                    self?.statusText = "年龄未授权"
                    return
                }

                self?.refreshAge()
            }
        }
    }

    func refreshAge() {
        do {
            let components = try healthStore.dateOfBirthComponents()
            guard let age = Self.age(from: components) else {
                statusText = "生日资料不完整"
                return
            }

            self.age = age
            statusText = "\(age) 岁"
        } catch {
            Self.logger.error("Reading date of birth failed: \(error.localizedDescription, privacy: .public)")
            age = nil
            statusText = "未读取到年龄"
        }
    }

    private static func age(
        from birthComponents: DateComponents,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        var normalizedBirthComponents = birthComponents
        normalizedBirthComponents.calendar = birthComponents.calendar ?? calendar

        guard let birthDate = normalizedBirthComponents.date,
              birthDate <= now else {
            return nil
        }

        return calendar.dateComponents([.year], from: birthDate, to: now).year
    }
}
