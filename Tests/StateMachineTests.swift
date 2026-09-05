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
    expect(machine.handle(.arm(.unlimited)), .armed, "arm")
    guard machine.limit == .unlimited else { fatalError("initial limit") }
    machine.handle(.setLimit(.hours(1)))
    guard machine.limit == .hours(1) else { fatalError("set one-hour limit") }
    expect(machine.handle(.lidOpened), .armed, "initial open state must not reset")
    expect(machine.handle(.lidClosed), .closed, "close")
    expect(machine.handle(.lidOpened), .off, "open after close")
    expect(machine.handle(.arm(.hours(2))), .armed, "re-arm")
    expect(machine.handle(.lidClosed), .closed, "close with limit")
    expect(machine.handle(.timeout), .off, "timeout while closed")
    expect(machine.handle(.arm(.unlimited)), .armed, "re-arm unlimited")
    expect(machine.handle(.cancel), .off, "cancel while armed")

    var limit = LidLimit.unlimited
    for hour in 1...9 {
      limit = limit.next()
      guard limit == .hours(hour) else { fatalError("limit cycle at \(hour)") }
    }
    guard limit.next() == .unlimited else { fatalError("ON 9 must cycle to unlimited") }

    var clicks = LidClickSelector()
    guard clicks.click(at: 1.0, isActive: false, currentLimit: .unlimited) == .activate(.unlimited)
    else { fatalError("first click activates unlimited") }
    guard clicks.click(at: 1.5, isActive: true, currentLimit: .unlimited) == .setLimit(.hours(1))
    else { fatalError("0.5-second boundary increments") }
    guard clicks.click(at: 2.01, isActive: true, currentLimit: .hours(1)) == .turnOff
    else { fatalError("click after 0.5 seconds turns off") }
    guard clicks.click(at: 2.2, isActive: false, currentLimit: .unlimited) == .activate(.hours(1))
    else { fatalError("off click restores last limit") }
    clicks.remember(.hours(9))
    guard clicks.click(at: 2.6, isActive: true, currentLimit: .hours(9)) == .setLimit(.unlimited)
    else { fatalError("quick click cycles ON 9 to unlimited") }
    print("StateMachineTests: OK")
  }
}
