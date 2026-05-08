import Foundation

enum Goal: String, Codable, CaseIterable {
    case strength, muscle, fatLoss = "fat_loss", general
}
