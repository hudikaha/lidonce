import AppKit
import Foundation

let ipcDirectory = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Application Support/LidOnce")
let commandURL = ipcDirectory.appendingPathComponent("command")
let stateURL = ipcDirectory.appendingPathComponent("state")

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
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
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

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let power = PowerController()
  private var machine = LidStateMachine()
  private var statusItem: NSStatusItem!
  private var toggleItem: NSMenuItem!
  private var stateItem: NSMenuItem!
  private var timer: Timer?
  private var guardToken: URL?

  func applicationDidFinishLaunching(_ notification: Notification) {
    try? FileManager.default.createDirectory(at: ipcDirectory, withIntermediateDirectories: true)
    statusItem = NSStatusBar.system.statusItem(withLength: 48)
    statusItem.autosaveName = "LidOnce"
    statusItem.isVisible = true
    statusItem.button?.image = nil
    statusItem.button?.title = "L1"
    statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    let menu = NSMenu()
    stateItem = NSMenuItem(title: "Sleep allowed", action: nil, keyEquivalent: "")
    stateItem.isEnabled = false
    menu.addItem(stateItem)
    toggleItem = NSMenuItem(title: "Enable next lid cycle", action: #selector(toggle), keyEquivalent: "")
    toggleItem.target = self
    menu.addItem(toggleItem)
    menu.addItem(.separator())
    let quit = NSMenuItem(title: "Quit LidOnce", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.addItem(quit)
    statusItem.menu = menu
    timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkLid), userInfo: nil, repeats: true)
    render()
  }

  func applicationWillTerminate(_ notification: Notification) {
    if machine.state != .off {
      disarm()
    }
    try? FileManager.default.removeItem(at: stateURL)
  }

  @objc private func toggle() {
    machine.state == .off ? turnOn() : turnOff()
  }

  private func turnOn() {
    do {
      try power.setSleepDisabled(true)
      try startCrashGuard()
      machine.handle(.arm)
      render()
    } catch {
      showError(error)
    }
  }

  private func turnOff() {
    disarm()
    machine.handle(.cancel)
    render()
  }

  @objc private func checkLid() {
    processCLICommand()
    guard machine.state != .off else { return }
    do {
      let closed = try power.isLidClosed()
      if machine.state == .armed && closed {
        machine.handle(.lidClosed)
        render()
      } else if machine.state == .closed && !closed {
        disarm()
        machine.handle(.lidOpened)
        render()
      }
    } catch {
      // A transient sensor read must not change the power setting.
    }
  }

  private func render() {
    switch machine.state {
    case .off:
      statusItem.button?.title = "L1"
      statusItem.button?.toolTip = "LidOnce: sleep allowed"
      stateItem.title = "Sleep allowed"
      toggleItem.title = "Enable next lid cycle"
    case .armed:
      statusItem.button?.title = "L1•"
      statusItem.button?.toolTip = "LidOnce: enabled for next lid cycle"
      stateItem.title = "Armed — close the lid"
      toggleItem.title = "Cancel"
    case .closed:
      statusItem.button?.title = "L1!"
      statusItem.button?.toolTip = "LidOnce: keeping awake with lid closed"
      stateItem.title = "Active — opening the lid will reset"
      toggleItem.title = "Reset now"
    }
    try? (machine.state.rawValue + "\n").write(to: stateURL, atomically: true, encoding: .utf8)
  }

  private func processCLICommand() {
    guard let command = try? String(contentsOf: commandURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines) else { return }
    try? FileManager.default.removeItem(at: commandURL)
    if command == "on" && machine.state == .off {
      turnOn()
    } else if command == "off" && machine.state != .off {
      turnOff()
    }
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

  private func showError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "LidOnce could not change the sleep setting"
    alert.informativeText = "Install the restricted privilege rule first.\n\n\(error)"
    alert.alertStyle = .warning
    alert.runModal()
  }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
