import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SnapPasteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private var service: ScreenshotService?
    private var statusItem: NSStatusItem?
    private var hotKeyID: UInt32?
    private var hotKeyCode: UInt32?
    private var restoreIconWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_: Notification) {
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
            return
        }

        do {
            service = try ScreenshotService(directory: ScreenshotService.defaultDirectory())
        } catch {
            showError("Geçici klasör oluşturulamadı", error)
        }

        setUpStatusItem()
        registerHotKey()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(keyboardLayoutChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        runFirstLaunchSetup()
    }

    // MARK: - Capture

    private func startCapture() {
        guard let service, !service.isCapturing else { return }
        // Without the permission macOS 26's screencapture fails outright, so ask before capturing.
        guard ScreenRecordingPermission.isGranted else {
            if settings.didRequestScreenRecording {
                showPermissionAlert()
            } else {
                settings.didRequestScreenRecording = true
                ScreenRecordingPermission.request() // the system prompt is the UI here
            }
            return
        }

        let mode = settings.captureMode
        let display = mode == .fullScreen ? CaptureCommand.displayNumberUnderMouse() : nil
        service.capture(mode: mode, playSound: settings.playSound, displayNumber: display) { [weak self] result in
            switch result {
            case .success(.copied):
                self?.flashStatusIcon()
            case .success(.cancelled):
                break
            case let .failure(error as CaptureError) where !ScreenRecordingPermission.isGranted:
                self?.showPermissionAlert(detail: error.localizedDescription)
            case let .failure(error):
                self?.showError("Ekran görüntüsü alınamadı", error)
            }
        }
    }

    @objc private func captureFromMenu() {
        // Let the menu finish fading out so it doesn't end up in a full-screen capture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.startCapture() }
    }

    @objc private func copyLastScreenshot() {
        do {
            if try service?.copyLastScreenshot() == true { flashStatusIcon() }
        } catch {
            showError("Son görüntü kopyalanamadı", error)
        }
    }

    // MARK: - Hotkey

    private func registerHotKey() {
        let keyCode = KeyboardLayout.currentKeyCode(for: "s") ?? UInt32(kVK_ANSI_S)
        guard keyCode != hotKeyCode || hotKeyID == nil else { return }

        if let hotKeyID { HotKeyCenter.shared.unregister(hotKeyID) }
        hotKeyID = try? HotKeyCenter.shared.register(keyCode: keyCode, modifiers: [.shift, .option]) { [weak self] in
            // Leave the Carbon event handler before anything that may run a modal alert.
            DispatchQueue.main.async { self?.startCapture() }
        }
        hotKeyCode = hotKeyID == nil ? nil : keyCode
    }

    @objc private func keyboardLayoutChanged() {
        registerHotKey()
    }

    // MARK: - Menu

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = symbol("camera.viewfinder")
        item.button?.toolTip = "SnapPaste — ⇧⌥S ile ekran görüntüsü al, ⌘V ile yapıştır"
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !ScreenRecordingPermission.isGranted {
            menu.addItem(menuItem("⚠️ Ekran Kaydı İzni Ver…", #selector(openScreenRecordingSettings)))
            menu.addItem(.separator())
        }
        if hotKeyID == nil {
            let warning = menuItem("⚠️ ⇧⌥S başka bir uygulama tarafından kullanılıyor", nil)
            warning.isEnabled = false
            menu.addItem(warning)
        }

        let capture = menuItem("Ekran Görüntüsü Al", #selector(captureFromMenu))
        capture.keyEquivalent = "s"
        capture.keyEquivalentModifierMask = [.shift, .option]
        capture.isEnabled = service?.isCapturing == false
        menu.addItem(capture)

        let copyAgain = menuItem("Son Görüntüyü Tekrar Kopyala", #selector(copyLastScreenshot))
        copyAgain.isEnabled = service?.lastScreenshotURL != nil
        menu.addItem(copyAgain)

        menu.addItem(.separator())
        let header = menuItem("Çekim Modu", nil)
        header.isEnabled = false
        menu.addItem(header)
        for mode in CaptureMode.allCases {
            let item = menuItem(mode.title, #selector(selectMode(_:)))
            item.representedObject = mode.rawValue
            item.state = mode == settings.captureMode ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let sound = menuItem("Deklanşör Sesi", #selector(toggleSound))
        sound.state = settings.playSound ? .on : .off
        menu.addItem(sound)

        let login = menuItem("Oturum Açılışında Başlat", #selector(toggleLoginItem))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = menuItem("SnapPaste'ten Çık", #selector(NSApplication.terminate(_:)))
        quit.target = NSApp
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = CaptureMode(rawValue: raw) else { return }
        settings.captureMode = mode
    }

    @objc private func toggleSound() {
        settings.playSound.toggle()
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            showError("Oturum açılışı ayarı değiştirilemedi", error)
        }
    }

    @objc private func openScreenRecordingSettings() {
        ScreenRecordingPermission.request() // makes SnapPaste appear in the list
        ScreenRecordingPermission.openSystemSettings()
    }

    // MARK: - Helpers

    private func runFirstLaunchSetup() {
        // A hotkey utility is only useful if it's always running, so enable launch-at-login
        // once — but only from an installed copy, never from a DMG or Downloads.
        if !settings.didOfferLoginItem, isInstalledInApplicationsFolder {
            settings.didOfferLoginItem = true
            try? SMAppService.mainApp.register()
        }
        if !settings.didRequestScreenRecording, !ScreenRecordingPermission.isGranted {
            settings.didRequestScreenRecording = true
            ScreenRecordingPermission.request()
        }
    }

    private var isInstalledInApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        return path == "/Applications" || path == NSHomeDirectory() + "/Applications"
    }

    private func isAnotherInstanceRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }

    private func flashStatusIcon() {
        statusItem?.button?.image = symbol("checkmark.circle.fill")
        restoreIconWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.statusItem?.button?.image = self?.symbol("camera.viewfinder")
        }
        restoreIconWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "SnapPaste")
        image?.isTemplate = true
        return image
    }

    private func menuItem(_ title: String, _ action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func showError(_ message: String, _ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func showPermissionAlert(detail: String? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Ekran Kaydı izni gerekli"
        alert.informativeText = """
        SnapPaste'in ekran görüntüsü alabilmesi için Sistem Ayarları › Gizlilik ve Güvenlik › \
        Ekran ve Sistem Sesi Kaydı bölümünde SnapPaste'i açın. macOS ardından uygulamayı \
        yeniden başlatmanızı isteyebilir.
        """ + (detail.map { "\n\n(\($0))" } ?? "")
        alert.addButton(withTitle: "Sistem Ayarlarını Aç")
        alert.addButton(withTitle: "Vazgeç")
        if alert.runModal() == .alertFirstButtonReturn {
            ScreenRecordingPermission.openSystemSettings()
        }
    }
}

private extension CaptureMode {
    var title: String {
        switch self {
        case .region: return "Alan Seç"
        case .window: return "Pencere"
        case .fullScreen: return "Tam Ekran"
        }
    }
}
