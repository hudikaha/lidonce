import AppKit
import Foundation
import SwiftUI

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
final class LidOnceModel: ObservableObject {
  @Published private(set) var state: LidState = .off
  @Published private(set) var errorMessage: String?

  private let power = PowerController()
  private var machine = LidStateMachine()
  private var timer: Timer?
  private var guardToken: URL?

  init() {
    try? FileManager.default.createDirectory(at: ipcDirectory, withIntermediateDirectories: true)
    writeState()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
  }

  var label: String {
    switch state {
    case .off: return "L1"
    case .armed: return "L1•"
    case .closed: return "L1!"
    }
  }

  var statusText: String {
    switch state {
    case .off: return "Sleep allowed"
    case .armed: return "Enabled — close the lid"
    case .closed: return "Active — opening the lid will reset"
    }
  }

  func toggle() {
    state == .off ? turnOn() : turnOff()
  }

  func shutdown() {
    if state != .off { disarm() }
    try? FileManager.default.removeItem(at: stateURL)
  }

  private func turnOn() {
    do {
      try power.setSleepDisabled(true)
      try startCrashGuard()
      machine.handle(.arm)
      updateState()
      errorMessage = nil
    } catch {
      errorMessage = "Could not enable: \(error)"
    }
  }

  private func turnOff() {
    disarm()
    machine.handle(.cancel)
    updateState()
    errorMessage = nil
  }

  private func tick() {
    processCLICommand()
    guard state != .off else { return }
    guard let closed = try? power.isLidClosed() else { return }
    if state == .armed && closed {
      machine.handle(.lidClosed)
      updateState()
    } else if state == .closed && !closed {
      disarm()
      machine.handle(.lidOpened)
      updateState()
    }
  }

  private func processCLICommand() {
    guard let command = try? String(contentsOf: commandURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines) else { return }
    try? FileManager.default.removeItem(at: commandURL)
    if command == "on" && state == .off {
      turnOn()
    } else if command == "off" && state != .off {
      turnOff()
    }
  }

  private func updateState() {
    state = machine.state
    writeState()
  }

  private func writeState() {
    try? (state.rawValue + "\n").write(to: stateURL, atomically: true, encoding: .utf8)
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

@main
struct LidOnceApp: App {
  @StateObject private var model = LidOnceModel()

  var body: some Scene {
    MenuBarExtra {
      Text(model.statusText)
      Button(model.state == .off ? "Enable next lid cycle" : "Turn off") {
        model.toggle()
      }
      if let error = model.errorMessage {
        Divider()
        Text(error)
      }
      Divider()
      Button("Quit LidOnce") {
        model.shutdown()
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    } label: {
      Text(model.label)
        .font(.system(.body, design: .monospaced).weight(.semibold))
    }
  }
}
