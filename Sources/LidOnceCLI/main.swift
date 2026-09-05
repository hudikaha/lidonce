import Foundation

let ipcDirectory = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Application Support/LidOnce")
let commandURL = ipcDirectory.appendingPathComponent("command")
let stateURL = ipcDirectory.appendingPathComponent("state")
let appURL = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Applications/LidOnce.app")

func currentState() -> String {
  let state = try? String(contentsOf: stateURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
  return state?.isEmpty == false ? state! : "off"
}

func send(_ command: String) {
  try? FileManager.default.createDirectory(at: ipcDirectory, withIntermediateDirectories: true)
  do {
    try (command + "\n").write(to: commandURL, atomically: true, encoding: .utf8)
  } catch {
    FileHandle.standardError.write(Data("could not send command: \(error)\n".utf8))
    exit(1)
  }
}

func waitForState(_ accepted: Set<String>) -> Bool {
  for _ in 0..<25 {
    let phase = currentState().split(separator: " ").first.map(String.init) ?? "off"
    if accepted.contains(phase) { return true }
    Thread.sleep(forTimeInterval: 0.1)
  }
  return false
}

func waitForLimit(_ hours: Int?) -> Bool {
  for _ in 0..<25 {
    let fields = currentState().split(separator: " ")
    let phase = fields.first.map(String.init) ?? "off"
    let currentHours = fields.count > 1 ? Int(fields[1]) : nil
    if ["armed", "closed"].contains(phase), currentHours == hours { return true }
    Thread.sleep(forTimeInterval: 0.1)
  }
  return false
}

func usage() -> Never {
  FileHandle.standardError.write(Data("usage: lidonce [on|on1|...|on9|off|status|open]\n".utf8))
  exit(2)
}

func openApp() {
  guard FileManager.default.fileExists(atPath: appURL.path) else {
    FileHandle.standardError.write(Data("LidOnce.app is not installed at \(appURL.path)\n".utf8))
    exit(1)
  }
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
  process.arguments = [appURL.path]
  do {
    try process.run()
    process.waitUntilExit()
  } catch {
    FileHandle.standardError.write(Data("could not open LidOnce: \(error)\n".utf8))
    exit(1)
  }
  if process.terminationStatus != 0 {
    FileHandle.standardError.write(Data("could not open LidOnce\n".utf8))
    exit(1)
  }
}

let command = (CommandLine.arguments.dropFirst().first ?? "status").lowercased()
switch command {
case "on", "on1", "on2", "on3", "on4", "on5", "on6", "on7", "on8", "on9":
  let hours = command == "on" ? nil : Int(command.suffix(1))
  send(command)
  if !waitForLimit(hours) {
    openApp()
    Thread.sleep(forTimeInterval: 0.5)
    send(command)
    guard waitForLimit(hours) else {
      FileHandle.standardError.write(Data("LidOnce did not accept the \(command) command\n".utf8))
      exit(1)
    }
  }
case "off", "reset":
  send("off")
  guard waitForState(["off"]) else {
    FileHandle.standardError.write(Data("LidOnce did not accept the off command\n".utf8))
    exit(1)
  }
case "status":
  print(currentState())
case "open":
  openApp()
default:
  usage()
}
