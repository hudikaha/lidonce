import AppKit
import Foundation

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

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "LidOnce")
    let menu = NSMenu()
    stateItem = NSMenuItem(title: "Sleep allowed", action: nil, keyEquivalent: "")
    stateItem.isEnabled = false
    menu.addItem(stateItem)
    toggleItem = NSMenuItem(title: "Arm next lid cycle", action: #selector(toggle), keyEquivalent: "")
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
      try? power.setSleepDisabled(false)
    }
  }

  @objc private func toggle() {
    do {
      if machine.state == .off {
        try power.setSleepDisabled(true)
        machine.handle(.arm)
      } else {
        try power.setSleepDisabled(false)
        machine.handle(.cancel)
      }
      render()
    } catch {
      showError(error)
    }
  }

  @objc private func checkLid() {
    guard machine.state != .off else { return }
    do {
      let closed = try power.isLidClosed()
      if machine.state == .armed && closed {
        machine.handle(.lidClosed)
        render()
      } else if machine.state == .closed && !closed {
        try power.setSleepDisabled(false)
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
      statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "LidOnce off")
      stateItem.title = "Sleep allowed"
      toggleItem.title = "Arm next lid cycle"
    case .armed:
      statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer.and.arrow.down", accessibilityDescription: "LidOnce armed")
      stateItem.title = "Armed — close the lid"
      toggleItem.title = "Cancel"
    case .closed:
      statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer.trianglebadge.exclamationmark", accessibilityDescription: "LidOnce active")
      stateItem.title = "Active — opening the lid will reset"
      toggleItem.title = "Reset now"
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

