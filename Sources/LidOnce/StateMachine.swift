enum LidState: String {
  case off
  case armed
  case closed
}

enum LidEvent {
  case arm
  case cancel
  case lidClosed
  case lidOpened
}

struct LidStateMachine {
  private(set) var state: LidState = .off

  @discardableResult
  mutating func handle(_ event: LidEvent) -> LidState {
    switch (state, event) {
    case (.off, .arm):
      state = .armed
    case (.armed, .lidClosed):
      state = .closed
    case (.closed, .lidOpened), (.armed, .cancel), (.closed, .cancel):
      state = .off
    default:
      break
    }
    return state
  }
}

