import SwiftUI
import LocalAuthentication
#if os(iOS)
import UIKit
#endif

struct ProfessionalInsightsView: View {
    @AppStorage("totalWorkSeconds") private var totalWorkSeconds = 0.0
    @AppStorage("workClockInTimestamp") private var clockInTimestamp = 0.0
    @AppStorage("profileEmail") private var profileEmail = ""
    @State private var pay = ""
    @State private var payUnlocked = false
    @State private var statusMessage = ""

    private var isClockedIn: Bool { clockInTimestamp > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 9 : 14) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: AegisDeviceClass.current == .phone ? 140 : 190), spacing: 8)], spacing: 8) {
                        insightCard("Total work", value: duration(totalWorkSeconds + currentSession(at: context.date)), symbol: "clock.fill")
                        insightCard("Current session", value: isClockedIn ? duration(currentSession(at: context.date)) : "Not clocked in", symbol: "timer")
                        insightCard("Account email", value: profileEmail.isEmpty ? "Not connected" : profileEmail, symbol: "envelope.fill")
                        insightCard("Local device", value: deviceStatus, symbol: "laptopcomputer.and.iphone")
                    }
                }

                GroupBox("Work session") {
                    HStack {
                        Text(isClockedIn ? "Your work timer is running." : "Clock in to measure professional activity accurately.")
                        Spacer()
                        Button(isClockedIn ? "Clock out" : "Clock in", systemImage: isClockedIn ? "stop.fill" : "play.fill") {
                            toggleClock()
                        }
                        .buttonStyle(AegisPrimaryButtonStyle())
                    }.padding(.vertical, 4)
                }

                GroupBox("Private pay information") {
                    VStack(alignment: .leading, spacing: 9) {
                        if payUnlocked {
                            SecureField("Current pay or hourly rate", text: $pay)
                                .textFieldStyle(.roundedBorder)
                            Button("Save securely", systemImage: "key.fill") { savePay() }
                                .buttonStyle(AegisPrimaryButtonStyle())
                        } else {
                            Text("Stored only in Apple Keychain and available after system authentication.")
                                .foregroundStyle(.secondary)
                            Button("Unlock pay information", systemImage: "touchid") { authenticateForPay() }
                        }
                        if !statusMessage.isEmpty { Text(statusMessage).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 4)
                }

                GroupBox("Connections") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("This device: local status available", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Label("Other devices: requires an authenticated device registry or organisation MDM", systemImage: "lock.shield")
                        Label("Email inbox: requires provider OAuth and encrypted token storage", systemImage: "envelope.badge.shield.half.filled")
                    }.font(.subheadline).padding(.vertical, 4)
                }
            }
            .frame(maxWidth: AegisLayout.contentMaxWidth(960), alignment: .leading)
        }
        .contentMargins(AegisLayout.pagePadding, for: .scrollContent)
        .navigationTitle("Professional Insights")
    }

    private func insightCard(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 4 : 7) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: AegisDeviceClass.current == .phone ? 54 : 68, alignment: .leading)
        .padding(AegisDeviceClass.current == .phone ? 9 : 13)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 13 : 16))
    }

    private var deviceStatus: String {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? "Battery \(Int(level * 100))%" : "Battery unavailable"
        #else
        return ProcessInfo.processInfo.isLowPowerModeEnabled ? "Low Power Mode" : "Active"
        #endif
    }

    private func currentSession(at date: Date) -> Double { isClockedIn ? max(0, date.timeIntervalSince1970 - clockInTimestamp) : 0 }
    private func duration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    private func toggleClock() {
        if isClockedIn {
            totalWorkSeconds += currentSession(at: Date())
            clockInTimestamp = 0
        } else { clockInTimestamp = Date().timeIntervalSince1970 }
    }
    private func authenticateForPay() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "View private pay information") { success, _ in
            Task { @MainActor in
                if success { payUnlocked = true; pay = (try? SecureKeychain.read(account: "currentPay")) ?? "" }
                else { statusMessage = "Authentication failed." }
            }
        }
    }
    private func savePay() {
        do { try SecureKeychain.save(pay, account: "currentPay"); statusMessage = "Saved securely in Apple Keychain." }
        catch { statusMessage = error.localizedDescription }
    }
}
