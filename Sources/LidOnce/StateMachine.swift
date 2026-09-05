enum LidState: String {
  case off
  case armed
  case closed
}

enum LidLimit: Equatable {
  case unlimited
  case hours(Int)

  var hours: Int? {
    if case .hours(let value) = self { return value }
    return nil
  }

  var displayText: String {
    hours.map { "ON \($0)" } ?? "ON"
  }

  func next() -> LidLimit {
    guard let value = hours else { return .hours(1) }
    return value < 9 ? .hours(value + 1) : .unlimited
  }
}

enum LidClickAction: Equatable {
  case activate(LidLimit)
  case setLimit(LidLimit)
  case turnOff
}

struct LidClickSelector {
  private var previousClick: Double?
  private(set) var lastLimit: LidLimit = .unlimited

  mutating func click(
    at time: Double,
    isActive: Bool,
    currentLimit: LidLimit
  ) -> LidClickAction {
    defer { previousClick = time }
    guard isActive else { return .activate(lastLimit) }
    if let previousClick, time - previousClick <= 0.5 {
      let next = currentLimit.next()
      lastLimit = next
      return .setLimit(next)
    }
    return .turnOff
  }

  mutating func remember(_ limit: LidLimit) {
    lastLimit = limit
  }
}

enum LidEvent {
  case arm(LidLimit)
  case setLimit(LidLimit)
  case cancel
  case lidClosed
  case lidOpened
  case timeout
}

struct LidStateMachine {
  private(set) var state: LidState = .off
  private(set) var limit: LidLimit = .unlimited

  @discardableResult
  mutating func handle(_ event: LidEvent) -> LidState {
    switch (state, event) {
    case (.off, .arm(let newLimit)):
      limit = newLimit
      state = .armed
    case (.armed, .setLimit(let newLimit)), (.closed, .setLimit(let newLimit)):
      limit = newLimit
    case (.armed, .lidClosed):
      state = .closed
    case (.closed, .lidOpened), (.armed, .cancel), (.closed, .cancel), (.closed, .timeout):
      state = .off
      limit = .unlimited
    default:
      break
    }
    return state
  }
}
