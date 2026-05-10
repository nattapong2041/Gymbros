import Foundation

enum ViewState<Value> {
    case idle
    case loading
    case success(Value)
    case empty
    case error(AppError)

    var value: Value? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}
