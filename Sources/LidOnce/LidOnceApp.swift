import AppKit
import Foundation

private let ipcDirectory = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Application Support/LidOnce")
private let commandURL = ipcDirectory.appendingPathComponent("command")
private let stateURL = ipcDirectory.appendingPathComponent("state")

final class PowerController {
  enum PowerError: Error, CustomStringConvertible {
    case commandFailed(String)

    var description: String {
      switch self {
      case .commandFailed(let message): return message
      }
    }
  }

  private func run(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    let output = String(
      decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self
    ).trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0 else {
      throw PowerError.commandFailed(output.isEmpty ? "command failed" : output)
    }
    return output
  }

  func setSleepDisabled(_ disabled: Bool) throws {
    _ = try run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"])
  }

  func isLidClosed() throws -> Bool {
    let output = try run("/usr/sbin/ioreg", ["-r", "-k", "AppleClamshellState", "-d", "4"])
    if output.contains("\"AppleClamshellState\" = Yes") { return true }
    if output.contains("\"AppleClamshellState\" = No") { return false }
    throw PowerError.commandFailed("AppleClamshellState was not found")
  }
}

@MainActor
final class LidOnceModel {
  private(set) var state: LidState = .off
  private(set) var errorMessage: String?
  var onChange: (() -> Void)?

  private let power = PowerController()
  private var machine = LidStateMachine()
  private var timer: Timer?
  private var guardToken: URL?
  private var closedAt: Date?
  private var clickSelector = LidClickSelector()

  init() {
    try? FileManager.default.createDirectory(at: ipcDirectory, withIntermediateDirectories: true)
    writeState()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
  }

  var statusText: String {
    switch state {
    case .off: return "Sleep allowed"
    case .armed: return "\(machine.limit.displayText) — close the lid"
    case .closed:
      if let hours = machine.limit.hours {
        return "ON \(hours) — sleeping after \(hours) hour\(hours == 1 ? "" : "s")"
      }
      return "ON — opening the lid will reset"
    }
  }

  var limit: LidLimit { machine.limit }

  func toggle() {
    let action = clickSelector.click(
      at: Date().timeIntervalSinceReferenceDate,
      isActive: state != .off,
      currentLimit: machine.limit
    )
    switch action {
    case .activate(let limit): turnOn(limit: limit)
    case .setLimit(let limit): setLimit(limit)
    case .turnOff:
      turnOff()
    }
  }

  func shutdown() {
    if state != .off { disarm() }
    try? FileManager.default.removeItem(at: stateURL)
  }

  private func turnOn(limit: LidLimit) {
    do {
      try power.setSleepDisabled(true)
      try startCrashGuard()
      machine.handle(.arm(limit))
      clickSelector.remember(limit)
      updateState()
      errorMessage = nil
      onChange?()
    } catch {
      errorMessage = "Could not enable: \(error)"
      onChange?()
    }
  }

  private func turnOff() {
    disarm()
    machine.handle(.cancel)
    closedAt = nil
    updateState()
    errorMessage = nil
    onChange?()
  }

  private func tick() {
    processCLICommand()
    guard state != .off else { return }
    guard let closed = try? power.isLidClosed() else { return }
    if state == .armed && closed {
      machine.handle(.lidClosed)
      closedAt = Date()
      updateState()
    } else if state == .closed && !closed {
      disarm()
      machine.handle(.lidOpened)
      closedAt = nil
      updateState()
    } else if state == .closed, closed, hasExpired(at: Date()) {
      disarm()
      machine.handle(.timeout)
      closedAt = nil
      updateState()
    }
  }

  private func setLimit(_ limit: LidLimit) {
    machine.handle(.setLimit(limit))
    clickSelector.remember(limit)
    updateState()
  }

  private func hasExpired(at date: Date) -> Bool {
    guard let hours = machine.limit.hours, let closedAt else { return false }
    return date.timeIntervalSince(closedAt) >= Double(hours) * 3600
  }

  private func processCLICommand() {
    guard let command = try? String(contentsOf: commandURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines) else { return }
    try? FileManager.default.removeItem(at: commandURL)
    if let limit = parseLimit(command) {
      if state == .off {
        turnOn(limit: limit)
      } else {
        setLimit(limit)
      }
    } else if command == "off" && state != .off {
      turnOff()
    }
  }

  private func parseLimit(_ command: String) -> LidLimit? {
    let normalized = command.lowercased()
    if normalized == "on" { return .unlimited }
    guard normalized.count == 3,
          normalized.hasPrefix("on"),
          let value = Int(normalized.suffix(1)),
          (1...9).contains(value)
    else { return nil }
    return .hours(value)
  }

  private func updateState() {
    state = machine.state
    writeState()
    onChange?()
  }

  private func writeState() {
    let suffix = machine.limit.hours.map { " \($0)" } ?? ""
    try? (state.rawValue + suffix + "\n").write(to: stateURL, atomically: true, encoding: .utf8)
  }

  private func startCrashGuard() throws {
    let token = URL(fileURLWithPath: "/var/tmp/lidonce-\(getuid())-\(getpid())-\(UUID().uuidString)")
    try Data().write(to: token, options: .atomic)
    guard let guardPath = Bundle.main.path(forResource: "lidonce-guard", ofType: nil) else {
      try? FileManager.default.removeItem(at: token)
      try? power.setSleepDisabled(false)
      throw PowerController.PowerError.commandFailed("crash guard was not found")
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: guardPath)
    process.arguments = [String(getpid()), token.path]
    do {
      try process.run()
      guardToken = token
    } catch {
      try? FileManager.default.removeItem(at: token)
      try? power.setSleepDisabled(false)
      throw error
    }
  }

  private func disarm() {
    try? power.setSleepDisabled(false)
    if let token = guardToken {
      try? FileManager.default.removeItem(at: token)
      guardToken = nil
    }
  }
}

private enum LidOnceIcon {
  static func make(state: LidState, limit: LidLimit) -> NSImage {
    let image = NSImage(size: NSSize(width: 26, height: 22), flipped: false) { _ in
      if let path = Bundle.main.path(forResource: "lidonce-notebook@2x", ofType: "png"),
         let notebook = NSImage(contentsOfFile: path) {
        let height: CGFloat = 15
        let width = height * notebook.size.width / notebook.size.height
        notebook.draw(
          in: NSRect(x: (26 - width) / 2, y: 0, width: width, height: height),
          from: .zero,
          operation: .sourceOver,
          fraction: 1
        )
      }

      let text = state == .off ? "Zzz" : limit.displayText
      let font = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
      ]
      let size = text.size(withAttributes: attributes)
      text.draw(
        at: NSPoint(x: 13 - size.width / 2, y: 13),
        withAttributes: attributes
      )
      return true
    }
    image.isTemplate = true
    return image
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = LidOnceModel()
  private var statusItem: NSStatusItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let item = NSStatusBar.system.statusItem(withLength: 28)
    item.autosaveName = "LidOnce"
    item.isVisible = true
    item.button?.target = self
    item.button?.action = #selector(toggle)
    item.button?.sendAction(on: [.leftMouseUp])
    item.button?.imagePosition = .imageOnly
    statusItem = item
    model.onChange = { [weak self] in self?.render() }
    render()
  }

  func applicationWillTerminate(_ notification: Notification) {
    model.shutdown()
  }

  @objc private func toggle() {
    model.toggle()
  }

  private func render() {
    let enabled = model.state != .off
    statusItem?.button?.image = LidOnceIcon.make(state: model.state, limit: model.limit)
    statusItem?.button?.toolTip = "LidOnce: \(model.statusText) — click to toggle"
    statusItem?.button?.setAccessibilityTitle(
      enabled ? "LidOnce on; click to turn off" : "LidOnce sleeping; click to turn on"
    )
    if let message = model.errorMessage {
      let alert = NSAlert()
      alert.messageText = "LidOnce could not change the sleep setting"
      alert.informativeText = message
      alert.alertStyle = .warning
      alert.runModal()
    }
  }
}

@main
enum LidOnceApplication {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
  }
}
