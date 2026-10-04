import SwiftUI

enum AppLinks {
    /// Set before release (App Store requires a privacy policy URL). Hidden in the UI while nil.
    static let privacyPolicy: URL? = nil
    static let support: URL? = nil
}

struct SettingsView: View {
    let store: ProgressStore
    let shop: Store
    @Environment(\.dismiss) private var dismiss
    @State private var sound = Sound.shared.isEnabled
    @State private var music = Music.shared.isEnabled
    @State private var haptics = Haptics.isEnabled
    @State private var reminders = Reminders.isEnabled
    @State private var confirmReset = false
    @State private var restoring = false

    var body: some View {
        ZStack {
            Color(hex: 0x241B36).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    OutlinedText(text: "Settings", size: 26, color: Theme.gold)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 8) {
                        SettingToggle(title: "Sound effects", icon: "speaker.wave.2.fill", isOn: $sound)
                            .onChange(of: sound) { _, v in Sound.shared.isEnabled = v; Sound.shared.play(.tap) }
                        SettingToggle(title: "Music", icon: "music.note", isOn: $music)
                            .onChange(of: music) { _, v in
                                Music.shared.isEnabled = v
                                if v { Music.shared.play(.menu) }
                            }
                        SettingToggle(title: "Vibration", icon: "iphone.radiowaves.left.and.right", isOn: $haptics)
                            .onChange(of: haptics) { _, v in Haptics.isEnabled = v; Haptics.tap() }
                        SettingToggle(title: "Reminders", icon: "bell.fill", isOn: $reminders)
                            .onChange(of: reminders) { _, v in
                                Reminders.isEnabled = v
                                if v { Reminders.requestPermissionIfNeeded() }
                            }
                    }
                    VStack(spacing: 8) {
                        Button {
                            restoring = true
                            Task {
                                await shop.restore()
                                restoring = false
                            }
                        } label: {
                            Label(restoring ? "Restoring…" : "Restore Purchases", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.teal, cornerRadius: 12, depth: 3))
                        .disabled(restoring)
                        if AdMobService.privacyOptionsRequired {
                            Button { AdMobService.presentPrivacyOptions() } label: {
                                Label("Privacy Choices", systemImage: "checkmark.shield.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.purple, cornerRadius: 12, depth: 3))
                        }
                        if let url = AppLinks.privacyPolicy {
                            Link(destination: url) {
                                Label("Privacy Policy", systemImage: "hand.raised.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.purple, cornerRadius: 12, depth: 3))
                        }
                        if let url = AppLinks.support {
                            Link(destination: url) {
                                Label("Support", systemImage: "questionmark.circle.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.purple, cornerRadius: 12, depth: 3))
                        }
                        Button(role: .destructive) { confirmReset = true } label: {
                            Label("Reset Progress", systemImage: "trash.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.red, cornerRadius: 12, depth: 3))
                        Spacer(minLength: 0)
                        Text(versionString).font(Theme.font(11)).foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 240)
                }
            }
            .padding(16)
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) {
                store.resetAll()
                dismiss()
            }
        } message: {
            Text("Stages, seeds, upgrades and generals will be lost. Purchases can be restored.")
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Hamster Ages \(v) (\(b))"
    }
}

private struct SettingToggle: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon).font(Theme.font(15)).foregroundStyle(.white)
        }
        .tint(Theme.green)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
    }
}
