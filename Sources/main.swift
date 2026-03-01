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
            try? task.run()
        }

        // Activate application by bundle identifier
        if let bundleId = userInfo["activate"] as? String {
            if let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId
            ) {
                NSWorkspace.shared.open(url)
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
        completionHandler([.banner, .sound])
    }
}

func sendNotification(title: String, message: String, execute: String?, activate: String?) {
    let center = UNUserNotificationCenter.current()

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            fputs("Error requesting notification permission: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        guard granted else {
            fputs("Notification permission denied\n", stderr)
            exit(1)
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        var info: [String: String] = [:]
        if let execute = execute { info["execute"] = execute }
        if let activate = activate { info["activate"] = activate }
        content.userInfo = info

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                fputs("Error sending notification: \(error.localizedDescription)\n", stderr)
                exit(1)
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
      -h, --help               Show this help message
    """)
}

// Parse arguments
var title = "macnotifier"
var message: String?
var execute: String?
var activate: String?

var i = 1
let args = CommandLine.arguments
while i < args.count {
    switch args[i] {
    case "-t", "--title":
        i += 1
        guard i < args.count else {
            fputs("Error: -t requires a value\n", stderr)
            exit(1)
        }
        title = args[i]
    case "-m", "--message":
        i += 1
        guard i < args.count else {
            fputs("Error: -m requires a value\n", stderr)
            exit(1)
        }
        message = args[i]
    case "-e", "--execute":
        i += 1
        guard i < args.count else {
            fputs("Error: -e requires a value\n", stderr)
            exit(1)
        }
        execute = args[i]
    case "-a", "--activate":
        i += 1
        guard i < args.count else {
            fputs("Error: -a requires a value\n", stderr)
            exit(1)
        }
        activate = args[i]
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        fputs("Error: unknown option '\(args[i])'\n", stderr)
        printUsage()
        exit(1)
    }
    i += 1
}

guard let message = message else {
    fputs("Error: -m (message) is required\n", stderr)
    printUsage()
    exit(1)
}

// Launch application
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = NotificationDelegate()
UNUserNotificationCenter.current().delegate = delegate

sendNotification(title: title, message: message, execute: execute, activate: activate)

// Terminate after timeout if no click action is registered
let hasAction = execute != nil || activate != nil
if !hasAction {
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        NSApplication.shared.terminate(nil)
    }
}

app.run()
