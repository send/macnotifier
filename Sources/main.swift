import Cocoa
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        // Execute shell command
        if let command = userInfo["execute"] as? String {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", command]
            do {
                try task.run()
            } catch {
                fputs("Failed to execute shell command '\(command)': \(error.localizedDescription)\n", stderr)
            }
        }

        // Activate application by bundle identifier (must run on main thread for AppKit)
        if let bundleId = userInfo["activate"] as? String {
            DispatchQueue.main.async {
                if let app = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleId
                ).first, app.activate() {
                    // activated
                } else if let url = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: bundleId
                ) {
                    NSWorkspace.shared.open(url)
                } else {
                    fputs("Warning: No application found for bundle identifier \(bundleId)\n", stderr)
                }
            }
        }

        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

// UNNotificationAttachment moves the file into its data store,
// so we must provide a temporary copy to avoid losing the original.
// UNNotificationAttachment moves the file into its data store at an
// indeterminate time, so the temp copy must outlive both init and center.add().
// A fixed temp directory is reused so at most one icon copy exists at a time.
func createIconAttachment(_ iconPath: String) -> UNNotificationAttachment? {
    let resolvedPath = (iconPath as NSString).expandingTildeInPath
    let sourceURL = URL(fileURLWithPath: resolvedPath)
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("sh.send.macnotifier")
    do {
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        // Clean up previous icon copies (best-effort; may fail if another process still needs one)
        if let old = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in old { try? FileManager.default.removeItem(at: file) }
        }
        let ext = sourceURL.pathExtension.isEmpty ? "" : ".\(sourceURL.pathExtension)"
        let tmpURL = tmpDir.appendingPathComponent(UUID().uuidString + ext)
        try FileManager.default.copyItem(at: sourceURL, to: tmpURL)
        return try UNNotificationAttachment(identifier: "icon", url: tmpURL, options: nil)
    } catch {
        fputs("Warning: Failed to attach icon '\(iconPath)': \(error.localizedDescription)\n", stderr)
        return nil
    }
}

struct NotificationParams {
    var title: String = "macnotifier"
    var message: String = ""
    var execute: String?
    var activate: String?
    var sound: String?
    var icon: String?
}

func sendNotification(_ params: NotificationParams) {
    let center = UNUserNotificationCenter.current()

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            fputs("Error requesting notification permission: \(error.localizedDescription)\n", stderr)
            DispatchQueue.main.async { exit(1) }
            return
        }
        guard granted else {
            fputs("Notification permission denied\n", stderr)
            DispatchQueue.main.async { exit(1) }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = params.title
        content.body = params.message

        if let soundName = params.sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        } else {
            content.sound = .default
        }

        if let iconPath = params.icon {
            if let attachment = createIconAttachment(iconPath) {
                content.attachments = [attachment]
            }
        }

        var info: [String: String] = [:]
        if let cmd = params.execute { info["execute"] = cmd }
        if let bundleId = params.activate { info["activate"] = bundleId }
        content.userInfo = info

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                fputs("Error sending notification: \(error.localizedDescription)\n", stderr)
                DispatchQueue.main.async { exit(1) }
            }
        }
    }
}

func printUsage() {
    print("""
    Usage: macnotifier [options]

    Options:
      -t, --title <title>      Notification title (default: "macnotifier")
      -m, --message <message>  Notification message (required)
      -e, --execute <command>  Shell command to execute on click
      -a, --activate <id>      Bundle ID of app to activate on click
          --sound <name>       Sound name in ~/Library/Sounds or /System/Library/Sounds (e.g. "Glass")
          --icon <path>        Path to image file to attach as icon
      -h, --help               Show this help message

    When launched with no arguments (e.g. by macOS for a stale notification
    click), the app runs briefly to handle the pending click action, then exits.
    """)
}

// Parse arguments
var params = NotificationParams()
var message: String?
var hasUserFlags = false

var i = 1
let args = CommandLine.arguments
while i < args.count {
    switch args[i] {
    case "-t", "--title":
        hasUserFlags = true
        i += 1
        guard i < args.count else {
            fputs("Error: -t requires a value\n", stderr)
            exit(1)
        }
        params.title = args[i]
    case "-m", "--message":
        hasUserFlags = true
        i += 1
        guard i < args.count else {
            fputs("Error: -m requires a value\n", stderr)
            exit(1)
        }
        message = args[i]
    case "-e", "--execute":
        hasUserFlags = true
        i += 1
        guard i < args.count else {
            fputs("Error: -e requires a value\n", stderr)
            exit(1)
        }
        params.execute = args[i]
    case "-a", "--activate":
        hasUserFlags = true
        i += 1
        guard i < args.count else {
            fputs("Error: -a requires a value\n", stderr)
            exit(1)
        }
        params.activate = args[i]
    case "--sound":
        hasUserFlags = true
        i += 1
        guard i < args.count else {
            fputs("Error: --sound requires a value\n", stderr)
            exit(1)
        }
        params.sound = args[i]
    case "--icon":
        hasUserFlags = true
        i += 1
        guard i < args.count else {
            fputs("Error: --icon requires a value\n", stderr)
            exit(1)
        }
        params.icon = args[i]
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        // LaunchServices may pass -psn_* when launching a .app bundle; ignore it.
        if args[i].hasPrefix("-psn_") { break }
        fputs("Error: unknown option '\(args[i])'\n", stderr)
        printUsage()
        exit(1)
    }
    i += 1
}

// Launch application and register delegate BEFORE validating -m.
// When macOS relaunches the app for a stale notification click, no arguments
// are passed. The delegate must be ready so didReceive can handle the click.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = NotificationDelegate()
UNUserNotificationCenter.current().delegate = delegate

if let message = message {
    params.message = message
    sendNotification(params)

    // Terminate after timeout; use a shorter timeout when no click action is registered
    let hasAction = params.execute != nil || params.activate != nil
    let timeout: TimeInterval = hasAction ? 60.0 : 5.0
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        NSApplication.shared.terminate(nil)
    }
} else if !hasUserFlags {
    // Launched by macOS for a notification click (no user flags, possibly only -psn_*).
    // Run briefly to let didReceive handle the pending click, then exit.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        NSApplication.shared.terminate(nil)
    }
} else {
    fputs("Error: -m (message) is required\n", stderr)
    printUsage()
    exit(1)
}

app.run()
