import SwiftUI
import LocalAuthentication
import Combine
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    var body: some View {
        EntryView()
    }
}

struct EntryView: View {
    @AppStorage("permanentUsername") private var username = ""
    @State private var signedIn = false
    @AppStorage("accentChoice") private var accentChoice = AccentChoice.indigo.rawValue
    @AppStorage("appearanceChoice") private var appearanceChoice = AppearanceChoice.system.rawValue

    var body: some View {
        Group {
            if signedIn, !username.isEmpty {
                MainExperience(username: username, signedIn: $signedIn)
            } else {
                WelcomeSignInView(signedIn: $signedIn)
            }
        }
        .tint(AccentChoice(rawValue: accentChoice)?.color ?? AccentChoice.indigo.color)
        .preferredColorScheme(AppearanceChoice(rawValue: appearanceChoice)?.scheme)
        .animation(.easeInOut(duration: 0.25), value: signedIn)
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case indigo = "Indigo"
    case violet = "Violet"
    case rose = "Rose"
    case orange = "Orange"
    case graphite = "Graphite"
    case blue = "Ocean"

    var id: Self { self }
    var color: Color {
        switch self {
        case .indigo: .indigo
        case .violet: .purple
        case .rose: .pink
        case .orange: .orange
        case .graphite: Color(white: 0.42)
        case .blue: .blue
        }
    }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: Self { self }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private enum VisualPreset: String, CaseIterable, Identifiable {
    case clarity = "Clarity"
    case midnight = "Midnight"
    case warm = "Warm"
    case studio = "Studio"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .clarity: "sun.max.fill"
        case .midnight: "moon.stars.fill"
        case .warm: "sunset.fill"
        case .studio: "sparkles.rectangle.stack.fill"
        }
    }
    var colors: [Color] {
        switch self {
        case .clarity: [.cyan, .blue]
        case .midnight: [.indigo, .purple]
        case .warm: [.orange, .pink]
        case .studio: [.gray, .indigo]
        }
    }
}

private struct WelcomeSignInView: View {
    @AppStorage("permanentUsername") private var savedUsername = ""
    @AppStorage("profileName") private var savedName = ""
    @AppStorage("profileEmail") private var savedEmail = ""
    @AppStorage("appLockEnabled") private var appLockEnabled = true
    @AppStorage("appLockConfigured") private var appLockConfigured = false
    @Binding var signedIn: Bool
    @State private var mode = AuthMode.signUp
    @State private var fullName = ""
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var loginIdentifier = ""
    @State private var accepted = false
    @State private var errorMessage = ""
    @State private var showingFailure = false
    @State private var failureTask: Task<Void, Never>?
    @State private var attemptedAutomaticLogin = false

    private enum AuthMode: String, CaseIterable, Identifiable {
        case signUp = "Sign up"
        case login = "Log in"
        var id: Self { self }
    }

    private var normalized: String {
        username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        normalized.count >= 3 && normalized.count <= 20
        && normalized.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        && fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        && (email.isEmpty || email.contains("@"))
    }

    private var signUpValidationMessage: String? {
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 { return "Enter your full name." }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanEmail.isEmpty {
            let emailParts = cleanEmail.split(separator: "@")
            if emailParts.count != 2 || !emailParts[1].contains(".") { return "Enter a valid email address or leave it blank." }
        }
        if normalized.count < 3 || normalized.count > 20 || !normalized.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Username must contain 3–20 letters, numbers or underscores."
        }
        if !accepted { return "Confirm that the username is permanent." }
        return nil
    }

    private var authMaxWidth: CGFloat {
        switch AegisDeviceClass.current { case .phone: 340; case .pad: 460; case .mac: 440 }
    }

    private var authHorizontalMargin: CGFloat {
        switch AegisDeviceClass.current { case .phone: 12; case .pad: 36; case .mac: 44 }
    }

    private var authSpacing: CGFloat {
        switch AegisDeviceClass.current { case .phone: 10; case .pad: 22; case .mac: 18 }
    }

    var body: some View {
        ZStack {
            WelcomeBackground()

            GeometryReader { geometry in
                let contentWidth = max(280, min(authMaxWidth, geometry.size.width - authHorizontalMargin * 2))
                ScrollView {
                    VStack(spacing: authSpacing) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: AegisDeviceClass.current == .phone ? 32 : 48))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Welcome to AegisDesk")
                            .font(AegisDeviceClass.current == .phone ? .title.bold() : .largeTitle.bold())
                        Text("Your private professional AI workspace")
                            .font(AegisDeviceClass.current == .phone ? .subheadline : .title3)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 11 : 15) {
                    Picker("Authentication", selection: $mode) {
                        ForEach(AuthMode.allCases) { item in Text(item.rawValue).tag(item) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .signUp {
                        signUpForm
                    } else {
                        loginForm
                    }

                    if !errorMessage.isEmpty {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Label("This profile stays on this device and is protected by Face ID, Touch ID or the device passcode.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(AegisDeviceClass.current == .phone ? 11 : 22)
                    .frame(width: contentWidth)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 22 : 28, style: .continuous))
                    }
                    .frame(width: contentWidth)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if showingFailure {
                FailureOverlay(message: errorMessage)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: showingFailure)
        .onAppear {
            if !appLockConfigured {
                appLockEnabled = true
                appLockConfigured = true
            }
            if !savedUsername.isEmpty {
                mode = .login
            }
        }
        .task(id: mode) {
            guard mode == .login, !savedUsername.isEmpty, !attemptedAutomaticLogin else { return }
            attemptedAutomaticLogin = true
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            loginWithSystemAuthentication()
        }
    }

    private var signUpForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !savedUsername.isEmpty {
                Label("A profile already exists on this device. Log in as @\(savedUsername) instead of creating a second permanent username.", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Go to Log in") { mode = .login; loginIdentifier = savedUsername }
                    .buttonStyle(AegisPrimaryButtonStyle())
            }
            TextField("Full name", text: $fullName)
                .textContentType(.name)
            TextField("Email address (optional)", text: $email)
                .textContentType(.emailAddress)
            TextField("Permanent username", text: $username)
                .autocorrectionDisabled()
                .textContentType(.username)
            Text("Username: 3–20 letters, numbers or underscores. It cannot be changed after setup.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("I understand this username is permanent", isOn: $accepted)

            Button("Create profile") { createProfile() }
                .buttonStyle(AegisPrimaryButtonStyle())
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!savedUsername.isEmpty)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !savedUsername.isEmpty {
                HStack(spacing: 11) {
                    AegisIconTile(symbol: "person.crop.circle.fill", size: AegisDeviceClass.current == .phone ? 40 : 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local account").font(.caption).foregroundStyle(.secondary)
                        Text("@\(savedUsername)").font(.headline)
                    }
                    Spacer()
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                }
                .padding(AegisDeviceClass.current == .phone ? 10 : 12)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                loginWithSystemAuthentication()
            } label: {
                Label("Unlock with biometrics or passcode", systemImage: "person.badge.key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AegisPrimaryButtonStyle())
            .controlSize(.large)

            if savedUsername.isEmpty {
                Text("No local profile was found. Choose Sign up first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func createProfile() {
        guard savedUsername.isEmpty else {
            errorMessage = "A username has already been set on this device."
            return
        }
        if let validationMessage = signUpValidationMessage {
            showFailure(validationMessage)
            return
        }
        savedUsername = normalized
        savedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        savedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        password = ""
        confirmation = ""
        signedIn = true
    }

    private func loginWithSystemAuthentication() {
        let identifier = loginIdentifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !savedUsername.isEmpty else {
            showInlineMessage("No local profile was found. Choose Sign up first.")
            return
        }
        if !identifier.isEmpty,
           identifier != savedUsername.lowercased(),
           identifier != savedEmail.lowercased() {
            showFailure("That username or email does not match. Try again.")
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Device Passcode"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            showInlineMessage(authenticationMessage(for: error))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your local AegisDesk account") { success, evaluationError in
            Task { @MainActor in
                if success {
                    errorMessage = ""
                    signedIn = true
                } else if let evaluationError = evaluationError as? LAError {
                    switch evaluationError.code {
                    case .userCancel, .systemCancel, .appCancel:
                        showInlineMessage("Authentication was cancelled. You can try again when ready.")
                    case .biometryNotAvailable:
                        showInlineMessage("Biometric authentication is unavailable on this device. Use the device passcode instead.")
                    case .biometryNotEnrolled:
                        showInlineMessage("No Face ID or Touch ID is enrolled. Set it up in device Settings or use the passcode.")
                    case .biometryLockout:
                        showInlineMessage("Biometrics are temporarily locked. Unlock the device with its passcode, then try again.")
                    case .passcodeNotSet:
                        showInlineMessage("Set a device passcode before enabling secure login.")
                    case .authenticationFailed:
                        showFailure("Face ID, Touch ID or the device passcode was not accepted.")
                    default:
                        showInlineMessage("Authentication could not be completed. Please try again.")
                    }
                } else {
                    showInlineMessage("Authentication could not be completed. Please try again.")
                }
            }
        }
    }

    private func authenticationMessage(for error: NSError?) -> String {
        guard let error, let code = LAError.Code(rawValue: error.code) else {
            return "System authentication is unavailable. Configure Face ID, Touch ID or a device passcode first."
        }
        switch code {
        case .biometryNotEnrolled: return "No Face ID or Touch ID is enrolled. Configure it in device Settings first."
        case .biometryNotAvailable: return "Biometric authentication is unavailable. Use a device with biometrics or configure a passcode."
        case .passcodeNotSet: return "A device passcode is required before secure login can be used."
        case .biometryLockout: return "Biometrics are locked. Unlock the device with its passcode first."
        default: return "System authentication is unavailable. Check the device security settings and try again."
        }
    }

    private func showInlineMessage(_ message: String) {
        failureTask?.cancel()
        showingFailure = false
        errorMessage = message
    }

    private func showFailure(_ message: String) {
        failureTask?.cancel()
        errorMessage = message
        showingFailure = true
        failureTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showingFailure = false
                errorMessage = ""
            }
        }
    }
}

private struct FailureOverlay: View {
    let message: String
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 120))
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: true)
            Text("Try again")
                .font(.largeTitle.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(42)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
        .shadow(radius: 30)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Authentication failed. Try again.")
    }
}

private struct WelcomeBackground: View {
    var body: some View {
        ZStack {
            Color.primary.opacity(0.02)
            Circle().fill(.indigo.opacity(0.16)).frame(width: 560).blur(radius: 100).offset(x: 340, y: -300)
            Circle().fill(.purple.opacity(0.12)).frame(width: 500).blur(radius: 110).offset(x: -330, y: 280)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case assistant = "AI Assistant"
    case planner = "Planner"
    case creative = "Creative Studio"
    case people = "Secure Chat"
    case appearance = "Appearance"
    case settings = "Settings"
    case original = "Professional tools"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .dashboard: "house"
        case .assistant: "sparkles"
        case .planner: "calendar.badge.clock"
        case .creative: "wand.and.stars"
        case .people: "bubble.left.and.bubble.right.fill"
        case .appearance: "paintpalette"
        case .settings: "gearshape"
        case .original: "briefcase"
        }
    }
}

private struct MainExperience: View {
    private enum PhoneTab: Hashable {
        case home, assistant, planner, create, more
    }

    let username: String
    @Binding var signedIn: Bool
    @State private var selection: MainSection? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var conversationStore = ConversationStore()
    @StateObject private var secureChatStore = SecureChatStore()
    @State private var showingQuickFind = false
    @State private var phoneTab: PhoneTab = .home
    @State private var phoneMorePath: [MainSection] = []
    @AppStorage("requestedSection") private var requestedSection = ""
    @AppStorage("requestedAssistantPrompt") private var requestedAssistantPrompt = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch AegisDeviceClass.current {
            case .phone: phoneExperience
            case .pad: padExperience
            case .mac: macExperience
            }
        }
        .sheet(isPresented: $showingQuickFind) {
            QuickFindView(selection: $selection)
        }
        .onChange(of: selection) { _, section in
            columnVisibility = section == .original ? .detailOnly : .all
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { conversationStore.saveNow() }
        }
        .onDisappear { conversationStore.saveNow() }
        .onAppear { handleRequestedSection() }
        .onChange(of: requestedSection) { _, _ in handleRequestedSection() }
    }

    private var phoneExperience: some View {
        ZStack {
            Color.primary.opacity(0.018).ignoresSafeArea()
            phoneSelectedContent
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            phoneNavigationBar
        }
    }

    @ViewBuilder
    private var phoneSelectedContent: some View {
        switch phoneTab {
        case .home: NavigationStack { sectionContent(.dashboard) }
        case .assistant: NavigationStack { sectionContent(.assistant) }
        case .planner: NavigationStack { sectionContent(.planner) }
        case .create: NavigationStack { sectionContent(.creative) }
        case .more: phoneMoreExperience
        }
    }

    private var phoneNavigationBar: some View {
        HStack(spacing: 2) {
            phoneTabButton(.home, "Home", "house.fill")
            phoneTabButton(.assistant, "AI", "sparkles")
            phoneTabButton(.planner, "Plan", "calendar")
            phoneTabButton(.create, "Create", "wand.and.stars")
            phoneTabButton(.more, "More", "ellipsis")
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 1)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.45) }
    }

    private func phoneTabButton(_ tab: PhoneTab, _ title: String, _ symbol: String) -> some View {
        Button {
            if tab == .more {
                // Always reopen More at its stable root instead of restoring a
                // potentially stale destination after an authentication sheet.
                phoneMorePath.removeAll()
            }
            phoneTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption2.weight(phoneTab == tab ? .semibold : .regular))
            }
            .foregroundStyle(phoneTab == tab ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(phoneTab == tab ? .isSelected : [])
    }

    private var phoneMoreExperience: some View {
        NavigationStack(path: $phoneMorePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        AegisIconTile(symbol: "person.crop.circle.fill", size: 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("@\(username)").font(.subheadline.weight(.semibold))
                            Text("Signed in securely").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    }
                    .padding(10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("More features").font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                        ForEach([MainSection.people, .appearance, .settings, .original]) { section in
                            NavigationLink(value: section) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Image(systemName: section.symbol)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                    Text(section.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                                .padding(11)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Label("Your local data is encrypted", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MainSection.self) { section in
                sectionContent(section)
            }
        }
    }

    private var padExperience: some View {
        VStack(spacing: 0) {
            iPadWorkspaceDock
            Divider().opacity(0.45)
            ZStack {
                AppleEditorialBackground()
                sectionContent(selection ?? .dashboard)
                    .id(selection)
            }
        }
        .background(Color.primary.opacity(0.012))
    }

    private var iPadWorkspaceDock: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                AegisIconTile(symbol: "sparkles.rectangle.stack.fill", size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("AegisDesk").font(.headline)
                    Text("@\(username)").font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider().frame(height: 34)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(MainSection.allCases) { section in
                        Button {
                            navigate(to: section)
                        } label: {
                            Label(section.rawValue, systemImage: section.symbol)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .foregroundStyle(selection == section ? Color.white : Color.primary)
                                .background(
                                    selection == section ? Color.accentColor : Color.primary.opacity(0.055),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var macExperience: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Section {
                    HStack(spacing: 12) {
                        AegisIconTile(symbol: "person.crop.circle.fill", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("@\(username)")
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section {
                    ForEach(MainSection.allCases) { item in
                        NavigationLink(value: item) {
                            HStack(spacing: 13) {
                                AegisIconTile(symbol: item.symbol, size: 38)
                                Text(item.rawValue)
                                    .font(.body.weight(.medium))
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section {
                    Label("Local demo mode", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AegisDesk")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 235, ideal: 265, max: 300)
        } detail: {
            ZStack {
                AppleEditorialBackground()
                sectionContent(selection ?? .dashboard)
                .id(selection)
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingQuickFind = true
                } label: {
                    Label("Quick Find", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            if selection != .dashboard {
                ToolbarItem(placement: .navigation) {
                    Button {
                        navigate(to: .dashboard)
                    } label: {
                        Label("Back to Dashboard", systemImage: "chevron.left")
                    }
                    .keyboardShortcut("[", modifiers: .command)
                }
            }
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                } label: {
                    Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
            #endif
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: MainSection) -> some View {
        switch section {
        case .dashboard:
            DemoDashboard(username: username) { destination in
                navigate(to: destination)
            } startPrompt: { prompt in
                conversationStore.prompt = prompt
                navigate(to: .assistant)
            }
        case .assistant:
            AIConversationView(store: conversationStore)
        case .planner:
            PlannerView { prompt in
                conversationStore.prompt = prompt
                navigate(to: .assistant)
            }
        case .creative:
            ImageStudioView()
        case .people:
            PeopleView(username: username, store: secureChatStore)
        case .appearance:
            AppearanceView()
        case .settings:
            AuthenticatedSettingsView(username: username, signedIn: $signedIn)
        case .original:
            ProfessionalToolsView()
        }
    }

    private func navigate(to section: MainSection) {
        if AegisDeviceClass.current == .phone {
            switch section {
            case .dashboard: phoneTab = .home
            case .assistant: phoneTab = .assistant
            case .planner: phoneTab = .planner
            case .creative: phoneTab = .create
            case .people, .appearance, .settings, .original:
                phoneMorePath = [section]
                phoneTab = .more
            }
            selection = section
            return
        }
        // Restore the outer navigation before swapping content. This avoids
        // stale detail-only state after leaving Professional Tools.
        columnVisibility = section == .original ? .detailOnly : .all
        withAnimation(.easeInOut(duration: 0.18)) {
            selection = section
        }
    }

    private func handleRequestedSection() {
        guard !requestedSection.isEmpty,
              let destination = MainSection.allCases.first(where: { $0.rawValue == requestedSection }) else { return }
        if destination == .assistant && !requestedAssistantPrompt.isEmpty {
            conversationStore.prompt = requestedAssistantPrompt
            requestedAssistantPrompt = ""
        }
        requestedSection = ""
        navigate(to: destination)
    }
}

private struct QuickFindView: View {
    @Binding var selection: MainSection?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [MainSection] {
        guard !query.isEmpty else { return MainSection.allCases }
        return MainSection.allCases.filter {
            $0.rawValue.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    Section("Go to") {
                        ForEach(results) { item in
                            Button {
                                selection = item
                                dismiss()
                            } label: {
                                Label(item.rawValue, systemImage: item.symbol)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $query, placement: .automatic, prompt: "Find a feature")
            .navigationTitle("Quick Find")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(idealWidth: 480, idealHeight: 520)
    }
}

private struct DemoDashboard: View {
    let username: String
    let openSection: (MainSection) -> Void
    let startPrompt: (String) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateEntrance = false
    @State private var heroFloating = false

    private var categories: [(MainSection, String, Color)] {
        [
            (.assistant, "AI", .blue), (.planner, "Planner", .orange), (.creative, "Create", .purple),
            (.people, "Chat", .green), (.original, "Workspaces", .indigo), (.appearance, "Style", .pink),
            (.settings, "Settings", .gray)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 9 : 26) {
                hero

                Group {
                    if AegisDeviceClass.current == .phone {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            categoryButtons
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) { categoryButtons }
                                .padding(.horizontal, 3)
                                .padding(.vertical, 8)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 7 : 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("The latest.").font(AegisDeviceClass.current == .phone ? .title2.bold() : .title.bold())
                        Text("Take a look at what’s new.").font(AegisDeviceClass.current == .phone ? .headline : .title2.bold()).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AegisDeviceClass.current == .phone ? 8 : 14) {
                            EditorialCard(eyebrow: "APPLE INTELLIGENCE", title: "Ask, analyse, create.", detail: "On-device assistance with visible working steps.", symbol: "apple.intelligence", colours: [.cyan.opacity(0.35), .blue.opacity(0.12)]) { openSection(.assistant) }
                            EditorialCard(eyebrow: "NEW", title: "Create a visual.", detail: "Professional images with Image Playground.", symbol: "wand.and.stars", colours: [.purple.opacity(0.30), .pink.opacity(0.12)]) { openSection(.creative) }
                            EditorialCard(eyebrow: "YOUR DAY", title: "Everything in view.", detail: "Calendar, reminders, focus and time zones.", symbol: "calendar.badge.clock", colours: [.orange.opacity(0.30), .yellow.opacity(0.10)]) { openSection(.planner) }
                            EditorialCard(eyebrow: "22 SECTORS", title: "Built for your work.", detail: "Specialised tools and secure professional insights.", symbol: "briefcase.fill", colours: [.indigo.opacity(0.28), .mint.opacity(0.12)]) { openSection(.original) }
                        }.padding(.vertical, 4)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 7)], spacing: 7) {
                    DashboardPanel(
                        title: "Privacy, built in",
                        symbol: "lock.shield.fill",
                        lines: ["On-device AI", "Keychain-protected pay", "Permission-based integrations"]
                    )
                    DashboardPanel(
                        title: "Ready for work",
                        symbol: "checkmark.circle.fill",
                        lines: ["22 industry workspaces", "Apple Calendar and Reminders", "Professional image studio"]
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Start something").font(AegisDeviceClass.current == .phone ? .headline : .title2.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: AegisDeviceClass.current == .phone ? 280 : 220), spacing: 7)], spacing: 7) {
                        ForEach(["Summarise today’s priorities", "Help me plan a project", "Draft a professional update", "Turn my notes into actions"], id: \.self) { prompt in
                            Button { startPrompt(prompt) } label: {
                                HStack { Image(systemName: "sparkles"); Text(prompt); Spacer(); Image(systemName: "arrow.up.right") }
                                    .font(AegisDeviceClass.current == .phone ? .caption.weight(.semibold) : .subheadline.weight(.medium)).padding(AegisDeviceClass.current == .phone ? 9 : 12)
                                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .contentShape(Rectangle())
                            }.buttonStyle(DashboardPressStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(AegisLayout.pagePadding, for: .scrollContent)
        .background(Color.primary.opacity(0.018))
        .navigationTitle("Dashboard")
        .onAppear {
            animateEntrance = true
            if !reduceMotion { heroFloating = true }
        }
    }

    @ViewBuilder
    private var categoryButtons: some View {
                        ForEach(categories, id: \.0) { item in
                            Button { openSection(item.0) } label: {
                                VStack(spacing: AegisDeviceClass.current == .phone ? 4 : 8) {
                                    Image(systemName: item.0.symbol)
                                        .font(.system(size: AegisDeviceClass.current == .phone ? 19 : 30, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: AegisDeviceClass.current == .phone ? 40 : 68, height: AegisDeviceClass.current == .phone ? 40 : 68)
                                        .background(item.2.gradient, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 13 : 20, style: .continuous))
                                        .overlay { RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 13 : 20, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 0.7) }
                                        .shadow(color: item.2.opacity(0.20), radius: 7, y: 3)
                                    Text(item.1)
                                        .font(AegisDeviceClass.current == .phone ? .caption2.weight(.semibold) : .subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }
                                .frame(maxWidth: AegisDeviceClass.current == .phone ? .infinity : 88)
                                .frame(minHeight: AegisDeviceClass.current == .phone ? 58 : 104)
                                .padding(.vertical, AegisDeviceClass.current == .phone ? 5 : 0)
                                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(DashboardPressStyle())
                            .accessibilityHint("Opens \(item.1)")
                            .opacity(animateEntrance ? 1 : 0)
                            .offset(y: animateEntrance ? 0 : 12)
                            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78), value: animateEntrance)
                        }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color.mint.opacity(0.22), Color.cyan.opacity(0.10), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.40)).frame(width: 330).blur(radius: 2).offset(x: 470, y: -30)
            HStack {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 6 : 10) {
                    Text("AEGISDESK").font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary)
                    Text("Work, beautifully.").font(.system(size: horizontalSizeClass == .compact ? 30 : 46, weight: .bold, design: .rounded))
                    Text("Welcome back, @\(username). One secure place to think, plan and create.")
                        .font(horizontalSizeClass == .compact ? .subheadline : .title3).foregroundStyle(.secondary).frame(maxWidth: horizontalSizeClass == .compact ? 250 : 520, alignment: .leading)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            heroButtons
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            heroButtons
                        }
                    }
                }
                Spacer()
                if horizontalSizeClass != .compact {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 105)).symbolRenderingMode(.hierarchical).foregroundStyle(.blue)
                        .padding(.trailing, 48)
                        .offset(y: heroFloating ? -8 : 8)
                        .rotationEffect(.degrees(heroFloating ? 1.4 : -1.4))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: heroFloating)
                }
            }.padding(horizontalSizeClass == .compact ? 14 : 34)
        }
        .frame(minHeight: AegisLayout.heroMinimumHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 22 : 30, style: .continuous))
    }

    @ViewBuilder
    private var heroButtons: some View {
        Button("Ask AegisDesk", systemImage: "sparkles") { openSection(.assistant) }.buttonStyle(AegisPrimaryButtonStyle())
        Button("Plan today", systemImage: "calendar") { openSection(.planner) }.buttonStyle(AegisSecondaryButtonStyle())
    }
}

private struct EditorialCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let symbol: String
    let colours: [Color]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: colours, startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 5 : 7) {
                    Text(eyebrow).font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(title)
                        .font(AegisDeviceClass.current == .phone ? .headline : .title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(detail)
                        .font(AegisDeviceClass.current == .phone ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(AegisDeviceClass.current == .phone ? 3 : nil)
                        .frame(maxWidth: 230, alignment: .leading)
                    Spacer()
                    Image(systemName: symbol).font(.system(size: AegisDeviceClass.current == .phone ? 54 : 76, weight: .medium)).symbolRenderingMode(.hierarchical).foregroundStyle(.primary.opacity(0.82)).frame(maxWidth: .infinity, alignment: .center)
                }.padding(AegisDeviceClass.current == .phone ? 14 : 20)
            }
            .frame(width: AegisLayout.editorialCardWidth, height: AegisLayout.editorialCardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(DashboardPressStyle())
        .scrollTransition(.animated, axis: .horizontal) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.72)
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
        }
    }
}

private struct DashboardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct DashboardPanel: View {
    let title: String
    let symbol: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 6 : 10) {
            HStack(spacing: AegisDeviceClass.current == .phone ? 8 : 12) {
                AegisIconTile(symbol: symbol, size: AegisDeviceClass.current == .phone ? 32 : 44)
                Text(title).font(.headline)
            }
            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: "checkmark.circle")
                    .font(AegisDeviceClass.current == .phone ? .caption2 : .subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AegisDeviceClass.current == .phone ? 9 : 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 14 : 20, style: .continuous))
    }
}

private struct FlowLayoutItems: View {
    let items: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "sparkles")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct FeatureCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ChatMessage: Identifiable, Codable {
    enum Role: String, Codable { case user, assistant }
    let id: UUID
    let role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

struct ChatHistorySession: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let messages: [ChatMessage]

    init(id: UUID = UUID(), createdAt: Date = Date(), messages: [ChatMessage]) {
        self.id = id
        self.createdAt = createdAt
        self.messages = messages
    }
    var title: String {
        messages.first(where: { $0.role == .user })?.text ?? "Conversation"
    }
}

private struct AIProgressStep: Identifiable {
    enum Status: Equatable { case pending, active, complete }
    let id = UUID()
    let title: String
    var status: Status
}

@MainActor
private final class ConversationStore: ObservableObject {
    @Published var prompt = ""
    @Published var messages: [ChatMessage] = [] { didSet { scheduleSave() } }
    @Published var isStreaming = false
    @Published var progressSteps: [AIProgressStep] = []
    @Published var history: [ChatHistorySession] = [] { didSet { scheduleSave() } }
    @Published private(set) var persistenceError = ""
    var streamTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var isRestoring = true

    init() {
        if let snapshot = try? ChatHistoryVault.load() {
            messages = snapshot.current
            history = snapshot.archived
        }
        isRestoring = false
    }

    private func scheduleSave() {
        guard !isRestoring else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, let self else { return }
            saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        let snapshot = ChatHistorySnapshot(current: messages, archived: Array(history.prefix(100)))
        do {
            try ChatHistoryVault.save(snapshot)
            persistenceError = ""
        } catch {
            persistenceError = "Chat history could not be saved securely. \(error.localizedDescription)"
        }
    }

    func archiveCurrentConversation() {
        guard !messages.isEmpty else { return }
        let session = ChatHistorySession(messages: messages)
        history.insert(session, at: 0)
        if history.count > 100 { history.removeLast(history.count - 100) }
        messages.removeAll()
    }
}

private protocol AIProviding {
    var status: String { get }
    func response(to prompt: String, memory: String) -> AsyncThrowingStream<String, Error>
}

private final class OnDeviceAIProvider: AIProviding {
    #if canImport(FoundationModels)
    private let model = SystemLanguageModel.default
    private lazy var session = LanguageModelSession(instructions: """
        You are AegisDesk, a professional assistant. Be direct, neutral and concise.
        For casual conversation, respond naturally and warmly while avoiding exaggerated praise, slang overload, or repetitive filler.
        Adapt tone to the user’s request and their selected response-style preference.
        Clearly distinguish facts, assumptions, uncertainty and recommendations.
        Never invent citations. Do not claim to replace a qualified professional.
        Do not make final medical, legal, employment, financial, safety or public-service decisions.
        """)
    #endif

    var status: String {
        #if canImport(FoundationModels)
        switch model.availability {
        case .available: "Apple on-device model"
        case .unavailable(.deviceNotEligible): "Apple Intelligence unavailable on this device"
        case .unavailable(.modelNotReady): "Apple Intelligence model is not ready"
        case .unavailable: "Apple Intelligence unavailable"
        }
        #else
        "Foundation Models unavailable on this platform"
        #endif
    }

    func response(to prompt: String, memory: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                #if canImport(FoundationModels)
                guard case .available = model.availability else {
                    continuation.yield("The on-device Apple Intelligence model is unavailable. Open System Settings to enable Apple Intelligence or use an eligible device. No scripted answer has been substituted.")
                    continuation.finish()
                    return
                }

                do {
                    let memoryText = memory.isEmpty ? "No saved user memory." : "User-approved memory:\n\(memory)"
                    var previous = ""
                    let stream = session.streamResponse(to: "\(memoryText)\n\nUser request:\n\(prompt)")
                    for try await snapshot in stream {
                        guard !Task.isCancelled else { return }
                        let complete = snapshot.content
                        let delta = String(complete.dropFirst(previous.count))
                        if !delta.isEmpty { continuation.yield(delta) }
                        previous = complete
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.yield("Foundation Models is not available in this build. No scripted answer has been substituted.")
                continuation.finish()
                #endif
            }
        }
    }
}

private enum IndustryContext {
    static func details(for id: String) -> String {
        switch id {
        case "healthcare": "Healthcare workspace. Assist with document summaries, terminology, redaction and professional drafts. Never diagnose; flag emergencies and require clinical review."
        case "legal-services": "Legal workspace. Summarise and compare documents, extract obligations and cite supplied sources. State jurisdiction limits and never present definitive legal advice."
        case "finance": "Finance workspace. Explain reports, show calculation assumptions, track user-entered figures and identify anomalies. Never promise returns or execute financial actions."
        case "education": "Education workspace. Create lessons, quizzes and rubric-based feedback. Respect academic integrity, teacher/student roles and safeguards for minors."
        case "software-it": "Software and IT workspace. Review code and logs, create tests and secure implementation plans. Detect credentials and never execute or change external systems without approval."
        case "human-resources": "Human resources workspace. Draft policies and onboarding material, check biased wording and protect employee data. Never make final employment decisions."
        case "sales": "Sales workspace. Create account briefs, proposals and follow-ups. Detect sensitive data and require confirmation before sending or changing records."
        case "support": "Customer support workspace. Summarise cases, draft replies and use approved product knowledge. Require confirmation before messages or record changes."
        case "construction": "Construction workspace. Summarise specifications and site notes, extract risks and create inspections. Require qualified safety review."
        case "engineering": "Engineering workspace. Compare revisions, analyse specifications and maintain risk registers. Never claim regulatory or safety compliance."
        case "government": "Government workspace. Summarise policy and draft accessible citizen communications. Never make high-impact decisions; election data must be identified as official or sample."
        case "real-estate": "Real-estate workspace. Summarise listings and property documents and prepare viewing notes. Verify financial, legal and property claims independently."
        case "insurance": "Insurance workspace. Explain policies and claim timelines. Never determine final eligibility, coverage or claims outcomes."
        case "manufacturing": "Manufacturing workspace. Summarise production, quality and downtime information. Require human approval for operational and safety changes."
        case "retail": "Retail workspace. Support products, inventory and customer replies. Confirm before publishing or editing customer records."
        case "marketing": "Marketing workspace. Create campaign briefs and calendars and review claims. Respect consent, rights and brand policy."
        case "media": "Media workspace. Create editorial briefs, fact-check lists and rights checklists. Verify facts, attribution and licences."
        case "nonprofit": "Nonprofit workspace. Support grants, impact reports and donor communication. Protect beneficiary and donor information."
        case "hospitality": "Hospitality workspace. Draft guest replies, itineraries and shift handovers. Confirm bookings, safety information and customer changes."
        case "logistics": "Logistics workspace. Summarise shipments, routes and supplier risks. Verify time-critical and safety-relevant information."
        case "energy": "Energy workspace. Summarise assets, outages and safety reviews. Require qualified review for infrastructure and safety decisions."
        case "general-business": "General business workspace. Support writing, summaries, research, extraction, planning, translation and approved knowledge."
        default: "Professional workspace. Be evidence-led, state uncertainty and require human review for consequential decisions."
        }
    }

    static func title(for id: String) -> String {
        let names = [
            "general-business": "General Business", "healthcare": "Healthcare", "legal-services": "Legal Services",
            "finance": "Finance & Accounting", "education": "Education", "software-it": "Software & IT",
            "human-resources": "Human Resources", "sales": "Sales", "support": "Customer Support",
            "construction": "Construction", "engineering": "Engineering", "government": "Government",
            "real-estate": "Real Estate", "insurance": "Insurance", "manufacturing": "Manufacturing",
            "retail": "Retail & Ecommerce", "marketing": "Marketing", "media": "Media & Publishing",
            "nonprofit": "Nonprofit", "hospitality": "Hospitality & Travel", "logistics": "Logistics & Supply Chain",
            "energy": "Energy & Utilities"
        ]
        return names[id] ?? "Professional"
    }
}

private struct AIConversationView: View {
    private enum ViewMode: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case history = "History"
        var id: Self { self }
    }

    @ObservedObject var store: ConversationStore
    @AppStorage("assistantMemory") private var assistantMemory = ""
    @AppStorage("responseStyle") private var responseStyle = "Natural"
    @AppStorage("activeWorkspaceID") private var activeWorkspaceID = "general-business"
    @AppStorage("agentModeEnabled") private var agentModeEnabled = false
    @State private var showingMemory = false
    @State private var viewMode = ViewMode.chat
    @State private var showingImageImporter = false
    @State private var attachedImageName = ""
    @State private var recognizedImageText = ""
    @State private var imageError = ""
    @State private var isProcessingImage = false
    @State private var securityWarning = ""
    @State private var showingSecurityWarning = false
    @FocusState private var composerFocused: Bool
    private let provider: any AIProviding = OnDeviceAIProvider()

    private var transcript: String {
        store.messages.map { message in
            "\(message.role == .user ? "User" : "AegisDesk"): \(message.text)"
        }.joined(separator: "\n\n")
    }

    private var suggestions: [String] {
        switch activeWorkspaceID {
        case "finance": ["Explain this financial term", "Show assumptions for a calculation", "Summarise a monthly report"]
        case "healthcare": ["Explain a medical term simply", "Draft patient instructions", "Find text that needs redaction"]
        case "legal-services": ["Extract contract obligations", "Compare two clauses", "List jurisdiction limitations"]
        case "government": ["Summarise a policy", "Draft an accessible citizen notice", "Explain the limits of sample election data"]
        case "software-it": ["Review code securely", "Create test cases", "Explain this log error"]
        default: ["Summarise my priorities", "Draft a professional message", "Help me create a plan"]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    modelStatus
                    Spacer()
                    workspaceStatus
                    privacyStatus
                }
                HStack(spacing: 8) {
                    modelStatus
                    Spacer()
                    privacyStatus
                }
                VStack(alignment: .leading, spacing: 4) {
                    modelStatus
                    workspaceStatus
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Picker("AI section", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)
            .padding(.vertical, 7)

            if agentModeEnabled && viewMode == .chat {
                AgentModeBanner()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }

            if !store.persistenceError.isEmpty {
                Label(store.persistenceError, systemImage: "exclamationmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            if viewMode == .chat {
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 9) {
                        if store.messages.isEmpty {
                            VStack(spacing: 10) {
                                ContentUnavailableView("Start a conversation", systemImage: "sparkles", description: Text("Responses use Apple’s on-device language model with \(IndustryContext.title(for: activeWorkspaceID)) safeguards."))
                                PromptSuggestionGrid(items: suggestions) { suggestion in
                                    store.prompt = suggestion
                                    send()
                                }
                            }
                            .padding(.top, 12)
                        }
                        ForEach(store.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if !store.progressSteps.isEmpty {
                            AIProgressView(steps: store.progressSteps, isActive: store.isStreaming)
                                .id("ai-progress")
                        }
                    }
                    .padding(12)
                }
                .onChange(of: store.messages.count) { _, _ in
                    if let last = store.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                }

            } else {
                AIHistoryView(store: store) { session in
                    store.messages = session.messages
                    store.history.removeAll { $0.id == session.id }
                    store.progressSteps.removeAll()
                    viewMode = .chat
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewMode == .chat { composerArea }
        }
        .navigationTitle("AI Assistant")
        .onAppear { composerFocused = true }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New chat", systemImage: "square.and.pencil") { newChat() }
                        .disabled(store.messages.isEmpty)
                    Button("Regenerate last answer", systemImage: "arrow.clockwise") { regenerate() }
                        .disabled(store.isStreaming || !store.messages.contains(where: { $0.role == .user }))
                    Button("Explain more simply", systemImage: "text.word.spacing") {
                        store.prompt = "Explain your previous answer more simply, using a short example."
                        send()
                    }
                    .disabled(store.isStreaming || store.messages.isEmpty)
                    Button("Turn into actions", systemImage: "checklist") {
                        store.prompt = "Turn the previous answer into a prioritised action list."
                        send()
                    }
                    .disabled(store.isStreaming || store.messages.isEmpty)
                    Button("Copy last answer", systemImage: "doc.on.doc") { copyLastAnswer() }
                        .disabled(!store.messages.contains(where: { $0.role == .assistant && !$0.text.isEmpty }))
                    Menu("Response style", systemImage: "textformat") {
                        ForEach(["Natural", "Professional", "Concise", "Detailed"], id: \.self) { style in
                            Button {
                                responseStyle = style
                            } label: {
                                if responseStyle == style { Label(style, systemImage: "checkmark") }
                                else { Text(style) }
                            }
                        }
                    }
                    Toggle("Agent Mode", systemImage: "cpu", isOn: $agentModeEnabled)
                } label: {
                    Label("Chat actions", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingMemory = true
                } label: {
                    Label("Memory", systemImage: assistantMemory.isEmpty ? "brain" : "brain.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: transcript) {
                    Label("Share conversation", systemImage: "square.and.arrow.up")
                }
                .disabled(store.messages.isEmpty)
            }
        }
        .sheet(isPresented: $showingMemory) {
            MemoryView(memory: $assistantMemory)
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
            processImage(result)
        }
        .alert("Sensitive information blocked", isPresented: $showingSecurityWarning) {
            Button("Review message", role: .cancel) { composerFocused = true }
        } message: {
            Text(securityWarning)
        }
    }

    private var composerArea: some View {
        VStack(spacing: 4) {
            if !attachedImageName.isEmpty || !imageError.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: imageError.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(imageError.isEmpty ? "Image ready: \(attachedImageName)" : imageError)
                        .lineLimit(1)
                    Spacer()
                    Button("Remove", systemImage: "xmark") {
                        attachedImageName = ""
                        recognizedImageText = ""
                        imageError = ""
                    }
                    .labelStyle(.iconOnly)
                }
                .font(.caption2)
                .foregroundStyle(imageError.isEmpty ? Color.secondary : Color.red)
                .padding(.horizontal, 10)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Button("Attach image", systemImage: isProcessingImage ? "hourglass" : "photo.badge.plus") {
                    showingImageImporter = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(AegisIconButtonStyle())
                .disabled(isProcessingImage || store.isStreaming)

                TextField("Message AegisDesk", text: $store.prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit { if !store.isStreaming { send() } }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(store.isStreaming ? "Stop" : "Send", systemImage: store.isStreaming ? "stop.fill" : "arrow.up") {
                    store.isStreaming ? cancel() : send()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(AegisIconButtonStyle())
                .disabled(!store.isStreaming && store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recognizedImageText.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
        // The app uses its own iPhone navigation bar. Reserve its exact visual
        // height so the composer can never sit underneath it.
        .padding(.bottom, AegisDeviceClass.current == .phone ? 48 : 0)
    }

    private var modelStatus: some View {
        Label(provider.status, systemImage: "apple.intelligence")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var workspaceStatus: some View {
        Label(IndustryContext.title(for: activeWorkspaceID), systemImage: "briefcase")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var privacyStatus: some View {
        Label("On-device processing", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func copyLastAnswer() {
        guard let answer = store.messages.last(where: { $0.role == .assistant && !$0.text.isEmpty })?.text else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(answer, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = answer
        #endif
    }

    private func send() {
        let typedText = store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageText = recognizedImageText
        let imageName = attachedImageName
        guard !typedText.isEmpty || !imageText.isEmpty else { return }
        let text = typedText.isEmpty ? "Analyse the text in this image." : typedText
        let securityInput = imageText.isEmpty ? text : "\(text)\n\(imageText)"
        if let warning = AISecurityGate.warning(for: securityInput) {
            securityWarning = warning
            showingSecurityWarning = true
            return
        }
        store.prompt = ""
        composerFocused = true
        store.messages.append(ChatMessage(role: .user, text: imageName.isEmpty ? text : "\(text)\n📎 \(imageName)"))
        store.messages.append(ChatMessage(role: .assistant, text: ""))
        store.streamTask?.cancel()
        store.isStreaming = true
        var steps = [
            AIProgressStep(title: "Understanding your request", status: .active),
            AIProgressStep(title: "Applying \(IndustryContext.title(for: activeWorkspaceID)) safeguards", status: .pending),
            AIProgressStep(title: assistantMemory.isEmpty ? "Checking memory preferences" : "Using your approved memory", status: .pending),
            AIProgressStep(title: "Generating the response", status: .pending)
        ]
        if !imageText.isEmpty { steps.insert(AIProgressStep(title: "Using text recognized on device from \(imageName)", status: .pending), at: 1) }
        store.progressSteps = steps
        attachedImageName = ""
        recognizedImageText = ""
        imageError = ""

        let lower = text.lowercased()
        if lower.hasPrefix("remember that ") {
            let fact = String(text.dropFirst("remember that ".count))
            if !fact.isEmpty {
                assistantMemory = assistantMemory.isEmpty ? fact : assistantMemory + "\n" + fact
            }
        }

        let responseID = store.messages.last?.id
        store.streamTask = Task {
            do {
                await MainActor.run {
                    for index in store.progressSteps.indices { store.progressSteps[index].status = .complete }
                    store.progressSteps[store.progressSteps.count - 1].status = .active
                }
                let agentPolicy = agentModeEnabled
                    ? "Agent Mode is enabled. Create a concise action plan and any requested code. Clearly label proposed actions. Never claim to have controlled the computer or changed a file unless an approved executor reports success. Require confirmation before consequential actions."
                    : "Agent Mode is off. Provide advice and drafts only."
                let configuredMemory = "Preferred response style: \(responseStyle).\nActive industry policy: \(IndustryContext.details(for: activeWorkspaceID))\n\(agentPolicy)\n" + assistantMemory
                let modelPrompt = imageText.isEmpty ? text : "\(text)\n\nText recognized on device from the attached image:\n\(String(imageText.prefix(8000)))"
                for try await chunk in provider.response(to: modelPrompt, memory: configuredMemory) {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let responseID,
                              let index = store.messages.firstIndex(where: { $0.id == responseID }) else { return }
                        store.messages[index].text += chunk
                    }
                }
                await MainActor.run { store.progressSteps[store.progressSteps.count - 1].status = .complete }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled,
                          let responseID,
                          let index = store.messages.firstIndex(where: { $0.id == responseID }) else { return }
                    store.messages[index].text = "The model could not complete this response: \(error.localizedDescription)"
                }
            }
            await MainActor.run { store.isStreaming = false }
        }
    }

    private func processImage(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            isProcessingImage = true
            imageError = ""
            Task {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try await ImageTextProcessor.recognizeText(at: url)
                    await MainActor.run {
                        isProcessingImage = false
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            imageError = "No readable text was found in that image."
                        } else {
                            attachedImageName = url.lastPathComponent
                            recognizedImageText = text
                        }
                    }
                } catch {
                    await MainActor.run { isProcessingImage = false; imageError = "Image processing failed: \(error.localizedDescription)" }
                }
            }
        } catch {
            imageError = error.localizedDescription
        }
    }

    private func cancel() {
        store.streamTask?.cancel()
        store.streamTask = nil
        store.isStreaming = false
        if let activeIndex = store.progressSteps.firstIndex(where: { $0.status == .active }) {
            store.progressSteps[activeIndex].status = .complete
        }
    }

    private func newChat() {
        cancel()
        store.prompt = ""
        store.archiveCurrentConversation()
        store.progressSteps.removeAll()
        composerFocused = true
    }

    private func regenerate() {
        guard !store.isStreaming,
              let lastUserIndex = store.messages.lastIndex(where: { $0.role == .user }) else { return }
        let prompt = store.messages[lastUserIndex].text
        store.messages.removeSubrange(lastUserIndex...)
        store.progressSteps.removeAll()
        store.prompt = prompt
        send()
    }
}

private struct AgentModeBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu.fill")
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent Mode").font(.caption.bold())
                Text("Plans actions and writes code. Mac execution requires an approved executor and confirmation for consequential steps.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("PLAN ONLY")
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .glassEffect(.regular.tint(.orange.opacity(0.18)), in: Capsule())
        }
        .padding(10)
        .glassEffect(.regular.tint(.accentColor.opacity(0.10)), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct AIHistoryView: View {
    @ObservedObject var store: ConversationStore
    let restore: (ChatHistorySession) -> Void

    var body: some View {
        List {
            if !store.messages.isEmpty {
                Section("Current") {
                    historyRow(ChatHistorySession(messages: store.messages))
                }
            }
            Section("Earlier conversations") {
                ForEach(store.history) { session in historyRow(session) }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if store.messages.isEmpty && store.history.isEmpty {
                ContentUnavailableView("No chat history", systemImage: "clock.arrow.circlepath", description: Text("Encrypted conversations saved on this device appear here."))
            }
        }
    }

    private func historyRow(_ session: ChatHistorySession) -> some View {
        Button { restore(session) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title).lineLimit(1).foregroundStyle(.primary)
                    Text("\(session.messages.count) messages · \(session.createdAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PromptSuggestionGrid: View {
    let items: [String]
    let action: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    action(item)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(item)
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AIProgressView: View {
    let steps: [AIProgressStep]
    let isActive: Bool
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(steps) { step in
                    HStack(spacing: 8) {
                        switch step.status {
                        case .pending:
                            Image(systemName: "circle")
                                .foregroundStyle(.tertiary)
                        case .active:
                            ProgressView().controlSize(.small)
                        case .complete:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Text(step.title)
                            .foregroundStyle(step.status == .pending ? .secondary : .primary)
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(isActive ? "Working" : "Completed steps", systemImage: isActive ? "sparkles" : "checkmark.circle")
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: isActive) { _, active in
            if !active { isExpanded = false }
        }
    }
}

private struct MemoryView: View {
    @Binding var memory: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What AegisDesk remembers") {
                    TextEditor(text: $draft)
                        .frame(minHeight: 180)
                    Text("You control this local memory. Review it before using a production model because saved details may be included with future prompts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Memory controls") {
                    Button("Save memory") {
                        memory = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    Button("Clear all memory", role: .destructive) {
                        memory = ""
                        draft = ""
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("AI memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { draft = memory }
        }
        .frame(idealWidth: 520, idealHeight: 440)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 70) }
            Text(message.text.isEmpty ? "Thinking…" : message.text)
                .foregroundStyle(message.text.isEmpty ? .secondary : .primary)
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                .contextMenu {
                    if !message.text.isEmpty {
                        Button("Copy", systemImage: "doc.on.doc") { copyMessage() }
                    }
                }
            if message.role == .assistant { Spacer(minLength: 70) }
        }
    }

    private func copyMessage() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = message.text
        #endif
    }
}

private struct Person: Identifiable {
    let id = UUID()
    let username: String
    let status: String
}

@MainActor
private final class SecureChatStore: ObservableObject {
    @Published var selectedUsername: String?
    @Published var draft = ""
    @Published var messagesByUser: [String: [String]] = [:]
}

private struct PeopleView: View {
    let username: String
    @ObservedObject var store: SecureChatStore
    @State private var search = ""
    @State private var disappearingMessages = false
    @State private var readReceipts = true

    private let people = [
        Person(username: "alex_team", status: "Available"),
        Person(username: "morgan_ops", status: "Away"),
        Person(username: "sam_review", status: "Available")
    ]

    private var filteredPeople: [Person] {
        guard !search.isEmpty else { return people }
        return people.filter {
            $0.username.localizedStandardContains(search) ||
            $0.status.localizedStandardContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    Label("Private in-memory session", systemImage: "lock.fill")
                    Label("Cleared when the app exits", systemImage: "timer")
                    Spacer()
                    Text("E2EE BACKEND REQUIRED").font(.caption2.bold()).foregroundStyle(.orange)
                }
                HStack {
                    Label("Private session", systemImage: "lock.fill")
                    Spacer()
                    Label("Clears on exit", systemImage: "timer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            NavigationSplitView {
                List(selection: $store.selectedUsername) {
                    ForEach(filteredPeople) { person in
                        HStack {
                            Image(systemName: "person.crop.circle.fill").font(.title2)
                            VStack(alignment: .leading) {
                                Text("@\(person.username)").foregroundStyle(.primary)
                                Text(person.status).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .tag(person.username)
                    }
                }
                .scrollContentBackground(.hidden)
                .overlay {
                    if filteredPeople.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                }
            } detail: {
                Group {
                    if let selectedUsername = store.selectedUsername {
                        VStack {
                            HStack(spacing: 9) {
                                AegisIconTile(symbol: "person.crop.circle.fill", tint: .green, size: 36)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("@\(selectedUsername)").font(.headline)
                                    Label("Local session • verified demo", systemImage: "checkmark.shield.fill")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Menu {
                                    Toggle("Read receipts", isOn: $readReceipts)
                                    Toggle("Disappearing messages", isOn: $disappearingMessages)
                                    Button("Clear conversation", systemImage: "trash", role: .destructive) {
                                        store.messagesByUser[selectedUsername] = []
                                    }
                                } label: { Image(systemName: "ellipsis.circle") }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(.ultraThinMaterial)

                            ScrollView {
                                VStack(alignment: .trailing, spacing: 10) {
                                    ForEach(Array((store.messagesByUser[selectedUsername] ?? []).enumerated()), id: \.offset) { _, message in
                                        Text(message)
                                            .padding(10)
                                            .glassEffect(.regular.tint(.accentColor.opacity(0.18)), in: RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding()
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(["Thanks", "I’ll review this", "Can you clarify?"], id: \.self) { reply in
                                        Button(reply) { store.draft = reply }
                                            .font(.caption)
                                            .buttonStyle(AegisSecondaryButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 10)
                            }

                            HStack(spacing: 7) {
                                TextField("Message @\(selectedUsername)", text: $store.draft)
                                    .textFieldStyle(.plain)
                                    .submitLabel(.send)
                                    .onSubmit {
                                        sendSecureMessage(to: selectedUsername)
                                    }
                                    .padding(.horizontal, 9).padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                                Button("Send", systemImage: "arrow.up") {
                                    sendSecureMessage(to: selectedUsername)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(AegisIconButtonStyle())
                                .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                        }
                    } else {
                        VStack(spacing: 20) {
                            ContentUnavailableView("Choose a person", systemImage: "bubble.left.and.bubble.right.fill", description: Text("Select a person to start a session-only private conversation."))
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Messages remain in memory during this app session", systemImage: "memorychip")
                                Label("Production E2EE requires verified device keys", systemImage: "key.horizontal")
                                Label("Key changes and new devices must be visible", systemImage: "exclamationmark.shield")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(18)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .searchable(text: $search, prompt: "Find a username")
        .navigationTitle("Secure Chat")
    }

    private func sendSecureMessage(to username: String) {
        let text = store.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.messagesByUser[username, default: []].append(text)
        store.draft = ""
    }
}

private struct AppearanceView: View {
    @AppStorage("accentChoice") private var accentChoice = AccentChoice.indigo.rawValue
    @AppStorage("appearanceChoice") private var appearanceChoice = AppearanceChoice.system.rawValue
    @AppStorage("reduceGlass") private var reduceGlass = false
    @AppStorage("largerComposer") private var largerComposer = false
    @AppStorage("visualPreset") private var visualPreset = VisualPreset.clarity.rawValue
    @AppStorage("interfaceMotion") private var interfaceMotion = true
    @AppStorage("compactInterface") private var compactInterface = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 9 : 14) {
                Text("Make AegisDesk yours")
                    .font(AegisDeviceClass.current == .phone ? .title2.bold() : .largeTitle.bold())
                Text("Choose a comfortable look. Every option keeps status text and symbols visible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("App-wide themes", systemImage: "square.grid.2x2.fill").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                        ForEach(VisualPreset.allCases) { preset in
                            Button {
                                apply(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Image(systemName: preset.symbol)
                                        Spacer()
                                        if visualPreset == preset.rawValue { Image(systemName: "checkmark.circle.fill") }
                                    }
                                    Text(preset.rawValue).font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.primary)
                                .padding(9)
                                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                                .background(LinearGradient(colors: preset.colors.map { $0.opacity(0.18) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Themes update the colour and light or dark appearance throughout the app.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(AegisDeviceClass.current == .phone ? 10 : 14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Display", systemImage: "circle.lefthalf.filled").font(.headline)
                Picker("Mode", selection: $appearanceChoice) {
                    ForEach(AppearanceChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                }
                .padding(AegisDeviceClass.current == .phone ? 10 : 14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Accent colour", systemImage: "paintpalette.fill").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: AegisDeviceClass.current == .phone ? 82 : 105))], spacing: 7) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button {
                            accentChoice = choice.rawValue
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(choice.color).frame(width: 15, height: 15)
                                Text(choice.rawValue).font(.caption.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                Spacer()
                                if accentChoice == choice.rawValue {
                                    Image(systemName: "checkmark").foregroundStyle(choice.color)
                                }
                            }
                            .padding(8)
                            .background(accentChoice == choice.rawValue ? choice.color.opacity(0.13) : Color.clear)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                }
                .padding(AegisDeviceClass.current == .phone ? 10 : 14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                Label("Interface", systemImage: "slider.horizontal.3").font(.headline)
                Toggle("Reduce glass effects", isOn: $reduceGlass)
                Toggle("Larger message composer", isOn: $largerComposer)
                Toggle("Interface animations", isOn: $interfaceMotion)
                Toggle("Compact layout", isOn: $compactInterface)
                }
                .font(.subheadline)
                .padding(AegisDeviceClass.current == .phone ? 10 : 14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Label("Colours never replace text or symbols used to communicate status.", systemImage: "accessibility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: AegisLayout.contentMaxWidth(760), alignment: .leading)
        }
        .contentMargins(AegisLayout.pagePadding, for: .scrollContent)
        .background { AppleEditorialBackground() }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func apply(_ preset: VisualPreset) {
        visualPreset = preset.rawValue
        switch preset {
        case .clarity:
            accentChoice = AccentChoice.blue.rawValue
            appearanceChoice = AppearanceChoice.light.rawValue
        case .midnight:
            accentChoice = AccentChoice.violet.rawValue
            appearanceChoice = AppearanceChoice.dark.rawValue
        case .warm:
            accentChoice = AccentChoice.orange.rawValue
            appearanceChoice = AppearanceChoice.light.rawValue
        case .studio:
            accentChoice = AccentChoice.indigo.rawValue
            appearanceChoice = AppearanceChoice.system.rawValue
        }
    }
}

private struct AuthenticatedSettingsView: View {
    let username: String
    @Binding var signedIn: Bool
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if isUnlocked {
                SettingsHubView(username: username, signedIn: $signedIn)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 42))
                        .symbolRenderingMode(.hierarchical)
                    Text("Settings locked")
                        .font(.title2.bold())
                    Text("Authenticate with Face ID, Touch ID or your device password to view and change account settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        authenticate()
                    } label: {
                        Label(isAuthenticating ? "Authenticating…" : "Unlock Settings", systemImage: "touchid")
                    }
                    .buttonStyle(AegisPrimaryButtonStyle())
                    .disabled(isAuthenticating)
                }
                .frame(maxWidth: 420)
                .padding(24)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                .padding(16)
                .navigationTitle("Settings")
            }
        }
        .task {
            if !isUnlocked { authenticate() }
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = ""
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isAuthenticating = false
            errorMessage = "Set up a device password or biometric authentication first."
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock AegisDesk Settings"
        ) { success, authenticationError in
            Task { @MainActor in
                isAuthenticating = false
                if success {
                    isUnlocked = true
                } else {
                    errorMessage = authenticationError?.localizedDescription ?? "Authentication failed. Try again."
                }
            }
        }
    }
}

private struct SettingsHubView: View {
    let username: String
    @Binding var signedIn: Bool
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("appLockEnabled") private var appLockEnabled = true
    @AppStorage("hidePreviews") private var hidePreviews = true
    @AppStorage("sensitiveDataWarnings") private var sensitiveWarnings = true
    @AppStorage("assistantMemory") private var assistantMemory = ""
    @AppStorage("responseStyle") private var responseStyle = "Natural"
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @AppStorage("soundEffects") private var soundEffects = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        Form {
            Section("Profile") {
                LabeledContent("Name", value: profileName.isEmpty ? "Not provided" : profileName)
                LabeledContent("Username", value: "@\(username)")
                LabeledContent("Email", value: profileEmail.isEmpty ? "Not provided" : profileEmail)
                Text("The permanent username cannot be edited. Name and email changes require verified backend account recovery.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Sign-in and authentication") {
                Toggle("Require system app lock", isOn: $appLockEnabled)
                SettingsDestination(title: "Password", detail: "Change and recovery require the identity server", symbol: "key")
                SettingsDestination(title: "Passkeys", detail: "Passwordless authentication", symbol: "person.badge.key")
                SettingsDestination(title: "Multi-factor authentication", detail: "Authenticator codes and recovery codes", symbol: "checkmark.shield")
                SettingsDestination(title: "Sign in with Apple", detail: "Connect an Apple identity", symbol: "apple.logo")
                SettingsDestination(title: "Active sessions", detail: "View devices and revoke sessions", symbol: "iphone.and.arrow.forward")
            }

            Section("Privacy and data") {
                Toggle("Hide content in app previews", isOn: $hidePreviews)
                Toggle("Warn about sensitive data", isOn: $sensitiveWarnings)
                Toggle("Share anonymous diagnostics", isOn: $analyticsEnabled)
                SettingsDestination(title: "Conversation retention", detail: "Standard and private-mode policies", symbol: "clock.arrow.circlepath")
                SettingsDestination(title: "Export data", detail: "Authenticated export", symbol: "square.and.arrow.up")
                SettingsDestination(title: "Delete data", detail: "Conversation and account controls", symbol: "trash")
            }

            Section("AI behaviour") {
                Picker("Response style", selection: $responseStyle) {
                    Text("Natural").tag("Natural")
                    Text("Professional").tag("Professional")
                    Text("Concise").tag("Concise")
                    Text("Detailed").tag("Detailed")
                }
                LabeledContent("Saved memory", value: assistantMemory.isEmpty ? "Empty" : "On")
                SettingsDestination(title: "AI memory", detail: "Review, edit and clear remembered information", symbol: "brain")
                SettingsDestination(title: "Model status", detail: "Apple on-device model", symbol: "apple.intelligence")
                Text("Natural mode allows friendly everyday conversation while preserving factual uncertainty and professional safeguards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance and interaction") {
                NavigationLink("Colours and appearance") { AppearanceView() }
                Toggle("Sound effects", isOn: $soundEffects)
                Toggle("Haptics", isOn: $hapticsEnabled)
                SettingsDestination(title: "Accessibility", detail: "Dynamic Type, VoiceOver and motion", symbol: "accessibility")
                SettingsDestination(title: "Keyboard shortcuts", detail: "Mac and iPad commands", symbol: "keyboard")
            }

            Section("Organisation") {
                SettingsDestination(title: "Role and permissions", detail: "Member access", symbol: "person.badge.shield.checkmark")
                SettingsDestination(title: "Workspace policies", detail: "22 sector configurations", symbol: "building.2")
                SettingsDestination(title: "Approved data sources", detail: "Organisation knowledge", symbol: "books.vertical")
                SettingsDestination(title: "Audit activity", detail: "Security metadata only", symbol: "list.bullet.clipboard")
            }

            Section("Help and about") {
                SettingsDestination(title: "Help centre", detail: "Guides and troubleshooting", symbol: "questionmark.circle")
                SettingsDestination(title: "Report a problem", detail: "Privacy-safe diagnostics", symbol: "exclamationmark.bubble")
                LabeledContent("Version", value: "Prototype 0.4")
                LabeledContent("AI processing", value: "On device")
            }

            Section {
                Button("Log out", role: .destructive) { signedIn = false }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
    }
}

private struct SettingsDestination: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        NavigationLink {
            FeatureInformationView(title: title, detail: detail, symbol: symbol)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
    }
}

private struct FeatureInformationView: View {
    let title: String
    let detail: String
    let symbol: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: symbol)
                    .font(.system(size: 54))
                    .symbolRenderingMode(.hierarchical)
                Text(title).font(.largeTitle.bold())
                Text(detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    Label("Designed for the secure production backend", systemImage: "server.rack")
                    Label("Permission and tenant checks required", systemImage: "person.badge.shield.checkmark")
                    Label("Security-relevant changes are audited", systemImage: "list.bullet.clipboard")
                }
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))

                Text("This prototype shows the intended control without claiming that unfinished server-side enforcement is active.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 620)
            .padding(36)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Label("Back to Settings", systemImage: "chevron.left")
                }
            }
        }
    }
}
