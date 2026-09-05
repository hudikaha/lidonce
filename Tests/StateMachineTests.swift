@main
enum StateMachineTests {
  static func expect(_ actual: LidState, _ expected: LidState, _ message: String) {
    guard actual == expected else {
      fatalError("\(message): expected \(expected.rawValue), got \(actual.rawValue)")
    }
  }

  static func main() {
    var machine = LidStateMachine()
    expect(machine.state, .off, "initial state")
    expect(machine.handle(.lidOpened), .off, "opening while off")
    expect(machine.handle(.arm), .armed, "arm")
    expect(machine.handle(.lidOpened), .armed, "initial open state must not reset")
    expect(machine.handle(.lidClosed), .closed, "close")
    expect(machine.handle(.lidOpened), .off, "open after close")
    expect(machine.handle(.arm), .armed, "re-arm")
    expect(machine.handle(.cancel), .off, "cancel while armed")
    print("StateMachineTests: OK")
  }
}

