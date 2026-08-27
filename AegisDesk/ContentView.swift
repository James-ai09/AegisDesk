//
//  ContentView.swift
//  AegisDesk
//
//  Milestone 1: Universal adaptive app shell.
//

import SwiftUI
import LocalAuthentication

struct ProfessionalToolsView: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = true
    @AppStorage("appLockConfigured") private var appLockConfigured = false
    @AppStorage("activeWorkspaceID") private var activeWorkspaceID = "general-business"
    @State private var isUnlocked = false
    @State private var selection: AppSection? = .home
    @State private var selectedWorkspace = Workspace.generalBusiness
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        ZStack {
            ambientBackground

            Group {
                if AegisDeviceClass.current == .phone {
                    phoneLayout
                } else {
                    NavigationSplitView(columnVisibility: $columnVisibility) {
                        SidebarView(selection: $selection, selectedWorkspace: $selectedWorkspace)
                            .navigationSplitViewColumnWidth(min: 225, ideal: 260, max: 300)
                    } detail: {
                        detail
                    }
                    .navigationSplitViewStyle(.balanced)
                }
            }
            .blur(radius: appLockEnabled && !isUnlocked ? 18 : 0)
            .allowsHitTesting(!appLockEnabled || isUnlocked)

            if appLockEnabled && !isUnlocked {
                AppLockView(unlock: authenticate)
                    .transition(.opacity)
            }
        }
        .task {
            if !appLockConfigured {
                appLockEnabled = true
                appLockConfigured = true
            }
            if let saved = Workspace.available.first(where: { $0.id == activeWorkspaceID }) {
                selectedWorkspace = saved
            }
            if appLockEnabled { authenticate() } else { isUnlocked = true }
        }
        .onChange(of: selectedWorkspace) { _, workspace in
            activeWorkspaceID = workspace.id
        }
        .animation(.easeInOut(duration: 0.2), value: isUnlocked)
    }

    private var phoneLayout: some View {
        VStack(spacing: 0) {
                VStack(spacing: 5) {
                    Menu {
                        ForEach(Workspace.available) { workspace in
                            Button { selectedWorkspace = workspace } label: {
                                Label(workspace.name, systemImage: workspace.systemImage)
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: selectedWorkspace.systemImage)
                                .foregroundStyle(selectedWorkspace.sectorColor)
                            Text(selectedWorkspace.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
                        ForEach(AppSection.allCases) { section in
                            Button { selection = section } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: section.systemImage)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(section.compactTitle)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }
                                .foregroundStyle(selection == section ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity, minHeight: 27)
                                .glassEffect(.regular.tint(selection == section ? Color.accentColor.opacity(0.20) : .clear).interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)

                Divider().opacity(0.35)
                detail.id(selection)
        }
        .navigationTitle("Professional Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ambientBackground: some View {
        ZStack {
            Color.primary.opacity(0.018)
            Circle()
                .fill(AppTheme.accent.opacity(0.10))
                .frame(width: 520, height: 520)
                .blur(radius: 90)
                .offset(x: 330, y: -260)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = false
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock AegisDesk and protect your professional workspace."
        ) { success, _ in
            Task { @MainActor in isUnlocked = success }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .home {
        case .home:
            HomeDashboard(workspace: selectedWorkspace)
        case .conversations:
            ConversationListView()
        case .tools:
            ToolsCatalogueView(workspace: selectedWorkspace)
        case .insights:
            ProfessionalInsightsView()
        case .privacy:
            PrivacyCentreView()
        case .settings:
            SettingsView()
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case home
    case conversations
    case tools
    case insights
    case privacy
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .conversations: "Conversations"
        case .tools: "Industry tools"
        case .insights: "Insights"
        case .privacy: "Privacy centre"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "rectangle.grid.2x2"
        case .conversations: "bubble.left.and.bubble.right"
        case .tools: "square.grid.2x2"
        case .insights: "chart.bar.xaxis"
        case .privacy: "lock.shield"
        case .settings: "gearshape"
        }
    }

    var compactTitle: String {
        switch self {
        case .home: "Home"
        case .conversations: "Chats"
        case .tools: "Tools"
        case .insights: "Insights"
        case .privacy: "Privacy"
        case .settings: "Settings"
        }
    }
}

private struct Workspace: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let reviewNotice: String

    static let generalBusiness = Workspace(
        id: "general-business",
        name: "General Business",
        systemImage: "briefcase",
        reviewNotice: "Review important outputs before use."
    )

    static let software = Workspace(
        id: "software-it",
        name: "Software & IT",
        systemImage: "chevron.left.forwardslash.chevron.right",
        reviewNotice: "Never submit credentials. Approve external changes explicitly."
    )

    static let legal = Workspace(
        id: "legal-services",
        name: "Legal Services",
        systemImage: "building.columns",
        reviewNotice: "Generated material is not definitive legal advice."
    )

    static let healthcare = Workspace(id: "healthcare", name: "Healthcare", systemImage: "cross.case", reviewNotice: "Not a substitute for diagnosis or emergency care. Clinical review is required.")
    static let finance = Workspace(id: "finance", name: "Finance & Accounting", systemImage: "chart.line.uptrend.xyaxis", reviewNotice: "Confirm assumptions and consequential financial actions.")
    static let education = Workspace(id: "education", name: "Education", systemImage: "graduationcap", reviewNotice: "Follow safeguarding and academic-integrity policy.")
    static let humanResources = Workspace(id: "human-resources", name: "Human Resources", systemImage: "person.2", reviewNotice: "AI must not make final employment decisions.")
    static let sales = Workspace(id: "sales", name: "Sales", systemImage: "target", reviewNotice: "Confirm before sending messages or changing records.")
    static let customerSupport = Workspace(id: "support", name: "Customer Support", systemImage: "headphones", reviewNotice: "Check sensitive information before sharing.")
    static let construction = Workspace(id: "construction", name: "Construction", systemImage: "hammer", reviewNotice: "Qualified review is required for safety-critical output.")
    static let engineering = Workspace(id: "engineering", name: "Engineering", systemImage: "gearshape.2", reviewNotice: "AI output does not prove safety or regulatory compliance.")
    static let government = Workspace(id: "government", name: "Government", systemImage: "building.2", reviewNotice: "AI must not make high-impact decisions about individuals.")
    static let realEstate = Workspace(id: "real-estate", name: "Real Estate", systemImage: "house.and.flag", reviewNotice: "Verify legal, financial and property information independently.")
    static let insurance = Workspace(id: "insurance", name: "Insurance", systemImage: "umbrella", reviewNotice: "AI must not make final eligibility or claims decisions.")
    static let manufacturing = Workspace(id: "manufacturing", name: "Manufacturing", systemImage: "shippingbox", reviewNotice: "Human review is required for operational and safety changes.")
    static let retail = Workspace(id: "retail", name: "Retail & Ecommerce", systemImage: "cart", reviewNotice: "Confirm before publishing or changing customer records.")
    static let marketing = Workspace(id: "marketing", name: "Marketing", systemImage: "megaphone", reviewNotice: "Review claims, consent and brand requirements.")
    static let media = Workspace(id: "media", name: "Media & Publishing", systemImage: "newspaper", reviewNotice: "Verify facts, rights and source attribution.")
    static let nonprofit = Workspace(id: "nonprofit", name: "Nonprofit", systemImage: "heart", reviewNotice: "Protect beneficiary and donor information.")
    static let hospitality = Workspace(id: "hospitality", name: "Hospitality & Travel", systemImage: "airplane", reviewNotice: "Confirm bookings, safety information and customer changes.")
    static let logistics = Workspace(id: "logistics", name: "Logistics & Supply Chain", systemImage: "truck.box", reviewNotice: "Verify time-critical and safety-relevant information.")
    static let energy = Workspace(id: "energy", name: "Energy & Utilities", systemImage: "bolt", reviewNotice: "Qualified review is required for infrastructure decisions.")

    static let available: [Workspace] = [
        .generalBusiness, .healthcare, .legal, .finance, .education, .software,
        .humanResources, .sales, .customerSupport, .construction, .engineering,
        .government, .realEstate, .insurance, .manufacturing, .retail, .marketing,
        .media, .nonprofit, .hospitality, .logistics, .energy
    ]

    var sectorColor: Color {
        switch id {
        case "finance": .green
        case "government": .indigo
        case "healthcare": .red
        case "legal-services": .brown
        case "education": .orange
        case "software-it": .purple
        case "construction", "engineering", "manufacturing": .orange
        case "sales", "marketing", "retail": .pink
        case "energy": .yellow
        default: .blue
        }
    }

    var quickActions: [(String, String)] {
        switch id {
        case "finance": [("Track money", "sterlingsign.circle"), ("Review trades", "chart.xyaxis.line"), ("Explain a report", "doc.text.magnifyingglass")]
        case "government": [("Election overview", "checkmark.seal"), ("Summarise policy", "building.columns"), ("Citizen update", "person.text.rectangle")]
        case "healthcare": [("Summarise document", "cross.case"), ("Plain-language explanation", "text.book.closed"), ("Redact sensitive data", "eye.slash")]
        case "software-it": [("Review code", "chevron.left.forwardslash.chevron.right"), ("Analyse logs", "doc.text.below.ecg"), ("Create tests", "checkmark.circle")]
        case "education": [("Lesson plan", "graduationcap"), ("Create quiz", "questionmark.circle"), ("Rubric feedback", "checklist")]
        case "legal-services": [("Review contract", "doc.text.magnifyingglass"), ("Compare clauses", "arrow.left.arrow.right"), ("Extract obligations", "checklist")]
        case "human-resources": [("Draft job description", "person.text.rectangle"), ("Check biased wording", "text.magnifyingglass"), ("Onboarding plan", "person.badge.plus")]
        case "sales": [("Account brief", "person.crop.rectangle.stack"), ("Draft proposal", "doc.badge.plus"), ("Follow-up plan", "arrow.turn.up.right")]
        case "support": [("Summarise case", "text.bubble"), ("Draft reply", "envelope"), ("Search knowledge", "books.vertical")]
        case "construction": [("Site checklist", "checklist"), ("Extract materials", "shippingbox"), ("Review site risks", "exclamationmark.triangle")]
        case "engineering": [("Review specification", "ruler"), ("Compare revisions", "arrow.left.arrow.right"), ("Risk register", "exclamationmark.shield")]
        case "real-estate": [("Property summary", "house"), ("Compare listings", "rectangle.2.swap"), ("Draft viewing notes", "note.text")]
        case "insurance": [("Policy summary", "umbrella"), ("Claim timeline", "calendar.badge.clock"), ("Coverage questions", "questionmark.circle")]
        case "manufacturing": [("Production summary", "gearshape.2"), ("Quality checklist", "checkmark.seal"), ("Downtime analysis", "clock.badge.exclamationmark")]
        case "retail": [("Product description", "tag"), ("Inventory review", "shippingbox"), ("Customer reply", "person.crop.circle.badge.checkmark")]
        case "marketing": [("Campaign brief", "megaphone"), ("Content calendar", "calendar"), ("Claims review", "checkmark.bubble")]
        case "media": [("Editorial brief", "newspaper"), ("Fact-check list", "checkmark.seal"), ("Rights checklist", "c.circle")]
        case "nonprofit": [("Grant draft", "doc.badge.plus"), ("Impact summary", "heart.text.square"), ("Donor update", "envelope")]
        case "hospitality": [("Guest reply", "person.crop.circle"), ("Itinerary", "map"), ("Shift handover", "arrow.left.arrow.right")]
        case "logistics": [("Shipment summary", "truck.box"), ("Supplier risks", "exclamationmark.triangle"), ("Route checklist", "map")]
        case "energy": [("Asset summary", "bolt"), ("Outage report", "exclamationmark.octagon"), ("Safety checklist", "checkmark.shield")]
        case "general-business": [("Meeting summary", "person.3"), ("Draft document", "square.and.pencil"), ("Project plan", "checklist")]
        default: [("Summarise", "doc.text.magnifyingglass"), ("Draft", "square.and.pencil"), ("Plan", "checklist")]
        }
    }
}

private struct ConversationSummary: Identifiable {
    let id = UUID()
    let title: String
    let preview: String
    let date: String
    let isPrivate: Bool

    static let samples: [ConversationSummary] = [
        ConversationSummary(
            title: "Quarterly report summary",
            preview: "Key findings, assumptions, and follow-up questions",
            date: "Today",
            isPrivate: false
        ),
        ConversationSummary(
            title: "Project risk review",
            preview: "Risks grouped by likelihood and impact",
            date: "Yesterday",
            isPrivate: false
        ),
        ConversationSummary(
            title: "Private draft",
            preview: "Not retained in normal conversation history",
            date: "Friday",
            isPrivate: true
        )
    ]
}

private struct ToolDefinition: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let systemImage: String
}

private enum AppTheme {
    static let accent = Color.accentColor
    static let softAccent = Color.accentColor.opacity(0.12)
}

private struct SidebarView: View {
    @Binding var selection: AppSection?
    @Binding var selectedWorkspace: Workspace

    var body: some View {
        List(selection: $selection) {
            Section {
                Menu {
                    ForEach(Workspace.available) { workspace in
                        Button {
                            selectedWorkspace = workspace
                        } label: {
                            Label(workspace.name, systemImage: workspace.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedWorkspace.systemImage)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.softAccent, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Workspace")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedWorkspace.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Current workspace, \(selectedWorkspace.name)")
                .accessibilityHint("Opens the workspace selector")
            }

            Section("Navigate") {
                ForEach(AppSection.allCases) { section in
                    NavigationLink(value: section) {
                        HStack(spacing: 12) {
                            AegisIconTile(symbol: section.systemImage, size: 36)
                            Text(section.title).font(.body.weight(.medium))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                PrivacyStatusCard()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("AegisDesk")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Protected connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

private struct PrivacyStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Standard history", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
            Text("Messages are retained according to your workspace policy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("Open Privacy centre for controls", systemImage: "arrow.right.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct HomeDashboard: View {
    let workspace: Workspace
    @State private var selectedTask: QuickTask?
    @State private var conversationPrompt = ""

    private let columns = [
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 8 : 16) {
                header
                SectorMetricsView(workspace: workspace)
                newConversationCard

                VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 6 : 10) {
                    Text("Start with a task")
                        .font(AegisDeviceClass.current == .phone ? .headline : .title2.weight(.semibold))

                    LazyVGrid(columns: columns, spacing: AegisDeviceClass.current == .phone ? 6 : 10) {
                        ForEach(Array(workspace.quickActions.enumerated()), id: \.offset) { _, action in
                            QuickActionCard(
                                title: action.0,
                                description: "Available for the \(workspace.name) workspace.",
                                systemImage: action.1,
                                action: { selectedTask = QuickTask(title: action.0, workspace: workspace.name) }
                            )
                        }
                    }
                }

                reviewNotice
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(AegisLayout.pagePadding, for: .scrollContent)
        .background(Color.primary.opacity(0.025))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(workspace.sectorColor.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: 90, y: -150)
                .allowsHitTesting(false)
        }
        .navigationTitle("Home")
        .sheet(item: $selectedTask) { task in QuickTaskWorkspace(task: task) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedTask = QuickTask(title: "New professional task", workspace: workspace.name)
                } label: {
                    Label("New conversation", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workspace.name)
                .font(AegisDeviceClass.current == .phone ? .title2.bold() : .largeTitle.bold())
            Text("Professional AI assistance with visible privacy controls.")
                .font(AegisDeviceClass.current == .phone ? .caption : .title3)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var newConversationCard: some View {
        VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 7 : 10) {
            HStack {
                Label("New conversation", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Label("Standard history", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("What would you like help with?")
                .font(AegisDeviceClass.current == .phone ? .subheadline.weight(.medium) : .title2.weight(.medium))

            TextField("Describe the task", text: $conversationPrompt)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()

                Button {
                    let title = conversationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    selectedTask = QuickTask(title: title.isEmpty ? "New professional task" : title, workspace: workspace.name)
                    conversationPrompt = ""
                } label: {
                    Label("Start", systemImage: "arrow.up")
                }
                .buttonStyle(AegisPrimaryButtonStyle())
            }
        }
        .padding(AegisDeviceClass.current == .phone ? 9 : 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 13 : 18))
    }

    private var reviewNotice: some View {
        Label {
            Text(workspace.reviewNotice)
        } icon: {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(AppTheme.accent)
        }
        .font(AegisDeviceClass.current == .phone ? .caption : .subheadline)
        .padding(AegisDeviceClass.current == .phone ? 9 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.softAccent, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SectorMetricsView: View {
    let workspace: Workspace
    @AppStorage("financeBalance") private var financeBalance = 24_680.50
    @AppStorage("financeTrades") private var financeTrades = 18
    @AppStorage("governmentVotes") private var governmentVotes = 128_450
    @AppStorage("governmentTurnout") private var governmentTurnout = 64
    @State private var selectedMetric: MetricSelection?

    private var metrics: [(String, String, String)] {
        switch workspace.id {
        case "finance": [
            ("Tracked balance", financeBalance.formatted(.currency(code: "GBP")), "sterlingsign.circle"),
            ("Monthly change", "+2.4%", "arrow.up.right")
        ]
        case "government": [
            ("Votes recorded", governmentVotes.formatted(), "checkmark.seal"),
            ("Sample turnout", "\(governmentTurnout)%", "person.3"),
            ("Reporting areas", "12", "map")
        ]
        case "healthcare": [("Documents reviewed", "12", "doc.text"), ("Items requiring review", "3", "exclamationmark.triangle"), ("Redactions", "28", "eye.slash")]
        case "software-it": [("Open reviews", "7", "chevron.left.forwardslash.chevron.right"), ("Tests drafted", "42", "checkmark.circle"), ("Warnings", "4", "exclamationmark.triangle")]
        case "education": [("Lesson plans", "14", "book"), ("Quizzes", "8", "questionmark.circle"), ("Students", "Local demo", "person.3")]
        case "legal-services": [("Documents", "24", "doc.text"), ("Clauses flagged", "9", "flag"), ("Deadlines", "5", "calendar.badge.exclamationmark")]
        case "human-resources": [("Draft policies", "6", "doc.text"), ("Bias checks", "11", "text.magnifyingglass"), ("Human reviews", "4", "person.badge.clock")]
        case "sales": [("Active accounts", "38", "person.crop.rectangle.stack"), ("Proposals", "9", "doc.badge.plus"), ("Follow-ups", "14", "arrow.turn.up.right")]
        case "support": [("Open cases", "27", "text.bubble"), ("Draft replies", "16", "envelope"), ("Escalations", "3", "arrow.up.right.circle")]
        case "construction": [("Site notes", "19", "note.text"), ("Inspections", "7", "checklist"), ("Safety reviews", "4", "exclamationmark.shield")]
        case "engineering": [("Specifications", "15", "ruler"), ("Revision checks", "8", "arrow.left.arrow.right"), ("Risks", "6", "exclamationmark.triangle")]
        case "real-estate": [("Properties", "42", "house"), ("Viewings", "11", "calendar"), ("Documents", "26", "doc.text")]
        case "insurance": [("Policies", "31", "umbrella"), ("Claims reviewed", "18", "doc.text.magnifyingglass"), ("Human decisions", "7", "person.badge.clock")]
        case "manufacturing": [("Work orders", "33", "gearshape.2"), ("Quality checks", "21", "checkmark.seal"), ("Downtime events", "4", "clock.badge.exclamationmark")]
        case "retail": [("Products", "248", "tag"), ("Low stock", "17", "shippingbox"), ("Customer drafts", "23", "person.crop.circle")]
        case "marketing": [("Campaigns", "8", "megaphone"), ("Draft assets", "34", "photo.on.rectangle"), ("Claims to review", "5", "checkmark.bubble")]
        case "media": [("Stories", "16", "newspaper"), ("Fact checks", "29", "checkmark.seal"), ("Rights reviews", "6", "c.circle")]
        case "nonprofit": [("Programmes", "12", "heart"), ("Grant drafts", "5", "doc.badge.plus"), ("Impact reports", "7", "chart.bar.doc.horizontal")]
        case "hospitality": [("Guest requests", "31", "person.crop.circle"), ("Arrivals", "18", "door.left.hand.open"), ("Handover items", "9", "arrow.left.arrow.right")]
        case "logistics": [("Shipments", "86", "truck.box"), ("Delayed", "7", "clock.badge.exclamationmark"), ("Supplier risks", "5", "exclamationmark.triangle")]
        case "energy": [("Assets monitored", "54", "bolt"), ("Open incidents", "3", "exclamationmark.octagon"), ("Safety reviews", "11", "checkmark.shield")]
        case "general-business": [("Projects", "12", "folder"), ("Completed tasks", "31", "checkmark.circle"), ("Needs review", "4", "eye")]
        default: [("Active items", "12", "tray.full"), ("Completed", "31", "checkmark.circle"), ("Needs review", "4", "eye")]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 7 : 10) {
            HStack {
                Text("Workspace overview").font(.headline)
                Spacer()
                Text("SAMPLE LOCAL DATA")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: metricColumns, spacing: AegisDeviceClass.current == .phone ? 6 : 12) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    Button {
                        selectedMetric = MetricSelection(title: metric.0, value: metric.1, symbol: metric.2)
                    } label: {
                        HStack(spacing: AegisDeviceClass.current == .phone ? 7 : 12) {
                            AegisIconTile(symbol: metric.2, tint: workspace.sectorColor, size: AegisDeviceClass.current == .phone ? 30 : 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.0).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                Text(metric.1).font(AegisDeviceClass.current == .phone ? .subheadline.weight(.semibold) : .headline).foregroundStyle(.primary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: AegisDeviceClass.current == .phone ? 42 : 0)
                        .padding(AegisDeviceClass.current == .phone ? 6 : 16)
                        .contentShape(Rectangle())
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens records and actions for \(metric.0)")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    overviewActions
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 10) {
                    overviewActions
                }
            }

            if workspace.id == "finance" {
                Stepper("Trades recorded: \(financeTrades)", value: $financeTrades, in: 0...10_000)
                    .font(.caption)
            } else if workspace.id == "government" {
                Text("Election figures are manually entered sample data. They are not live, certified, or an official result.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $selectedMetric) { metric in
            MetricDetailView(workspace: workspace, metric: metric)
        }
    }

    private var metricColumns: [GridItem] {
        if AegisDeviceClass.current == .phone {
            return [GridItem(.flexible())]
        }
        return [GridItem(.adaptive(minimum: 190), spacing: 12)]
    }

    @ViewBuilder
    private var overviewActions: some View {
        Button {
            if let first = metrics.first {
                selectedMetric = MetricSelection(title: first.0, value: first.1, symbol: first.2)
            }
        } label: {
            Label("Add record", systemImage: "plus")
        }
        .buttonStyle(AegisPrimaryButtonStyle())

        ShareLink(item: metrics.map { "\($0.0): \($0.1)" }.joined(separator: "\n")) {
            Label("Export overview", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(AegisSecondaryButtonStyle())
    }
}

private struct MetricSelection: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbol: String
}

private struct MetricRecord: Identifiable {
    let id = UUID()
    var title: String
    var note: String
    var completed: Bool
}

private struct MetricDetailView: View {
    let workspace: Workspace
    let metric: MetricSelection
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ""
    @State private var records: [MetricRecord]

    init(workspace: Workspace, metric: MetricSelection) {
        self.workspace = workspace
        self.metric = metric
        _records = State(initialValue: [
            MetricRecord(title: "Review current \(metric.title.lowercased())", note: "Added from sample workspace data", completed: false),
            MetricRecord(title: "Confirm owner and deadline", note: "Human review required", completed: false),
            MetricRecord(title: "Document completed work", note: "Ready for review", completed: true)
        ])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: metric.symbol)
                        .font(.title2)
                        .foregroundStyle(workspace.sectorColor)
                        .frame(width: 48, height: 48)
                        .background(workspace.sectorColor.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.title).font(.title2.bold())
                        Text("Current overview value: \(metric.value)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShareLink(item: records.map { "\($0.completed ? "✓" : "○") \($0.title) — \($0.note)" }.joined(separator: "\n")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Menu {
                        Button("Remove completed", systemImage: "trash") { records.removeAll { $0.completed } }
                    } label: { Label("More", systemImage: "ellipsis.circle") }
                }
                .padding()

                Divider()

                List {
                    Section("Records") {
                        ForEach($records) { $record in
                            HStack(spacing: 12) {
                                Button {
                                    record.completed.toggle()
                                } label: {
                                    Image(systemName: record.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(record.completed ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Record title", text: $record.title)
                                        .textFieldStyle(.plain)
                                        .strikethrough(record.completed)
                                    TextField("Note", text: $record.note)
                                        .textFieldStyle(.plain)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                HStack {
                    TextField("Add a new item", text: $newItem)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .onSubmit { addRecord() }
                    Button("Add", systemImage: "plus") { addRecord() }
                        .buttonStyle(AegisPrimaryButtonStyle())
                        .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(15)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                .padding()
            }
            .navigationTitle(workspace.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(idealWidth: 700, idealHeight: 620)
    }

    private func addRecord() {
        let title = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        records.append(MetricRecord(title: title, note: "Added just now", completed: false))
        newItem = ""
    }
}

private struct QuickActionCard: View {
    let title: String
    let description: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AegisDeviceClass.current == .phone ? 8 : 11) {
                AegisIconTile(symbol: systemImage, size: AegisDeviceClass.current == .phone ? 34 : 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if AegisDeviceClass.current != .phone {
                        Text(description).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: AegisDeviceClass.current == .phone ? 44 : 68, alignment: .leading)
            .padding(AegisDeviceClass.current == .phone ? 8 : 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AegisDeviceClass.current == .phone ? 13 : 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts a new conversation for this task")
    }
}

private struct QuickTask: Identifiable {
    let id = UUID()
    let title: String
    let workspace: String
}

private struct QuickTaskWorkspace: View {
    let task: QuickTask
    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var checklist = ["Define the outcome", "Gather permitted source material", "Review before use"]
    @State private var completed = Set<String>()

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    LabeledContent("Workspace", value: task.workspace)
                    Text(task.title).font(.headline)
                }
                Section("Working notes") {
                    TextEditor(text: $notes).frame(minHeight: 120)
                }
                Section("Checklist") {
                    ForEach(checklist, id: \.self) { item in
                        Button {
                            if completed.contains(item) { completed.remove(item) } else { completed.insert(item) }
                        } label: {
                            Label(item, systemImage: completed.contains(item) ? "checkmark.circle.fill" : "circle")
                        }.buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Professional Task")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .frame(idealWidth: 600, idealHeight: 520)
    }
}

private struct ConversationListView: View {
    @State private var searchText = ""
    @State private var newTask: QuickTask?

    private var filteredConversations: [ConversationSummary] {
        guard !searchText.isEmpty else { return ConversationSummary.samples }
        return ConversationSummary.samples.filter {
            $0.title.localizedStandardContains(searchText)
            || $0.preview.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List(filteredConversations) { conversation in
            NavigationLink {
                VStack(alignment: .leading, spacing: 12) {
                    Text(conversation.preview).font(.title3)
                    Label(conversation.isPrivate ? "Private session preview" : "Standard history", systemImage: conversation.isPrivate ? "lock.fill" : "clock")
                        .foregroundStyle(.secondary)
                    Text("This sample entry is readable and searchable. Live AI conversations are managed in the main AI Assistant history tab.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .navigationTitle(conversation.title)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: conversation.isPrivate ? "lock.fill" : "bubble.left")
                        .foregroundStyle(conversation.isPrivate ? AppTheme.accent : .secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(conversation.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if conversation.isPrivate {
                                Text("PRIVATE")
                                    .font(.caption2.bold())
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        Text(conversation.preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                    Text(conversation.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .scrollContentBackground(.hidden)
        .overlay {
            if filteredConversations.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Conversations")
        .sheet(item: $newTask) { QuickTaskWorkspace(task: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newTask = QuickTask(title: "New conversation notes", workspace: "Professional tools")
                } label: {
                    Label("New conversation", systemImage: "square.and.pencil")
                }
            }
        }
    }
}

private struct ToolsCatalogueView: View {
    let workspace: Workspace

    private let tools = [
        ToolDefinition(
            title: "Document summary",
            description: "Identify main points, decisions, risks, and actions.",
            systemImage: "doc.text.magnifyingglass"
        ),
        ToolDefinition(
            title: "Professional draft",
            description: "Create a neutral first draft for human review.",
            systemImage: "pencil.and.outline"
        ),
        ToolDefinition(
            title: "Structured extraction",
            description: "Turn permitted source material into organised fields.",
            systemImage: "tablecells"
        ),
        ToolDefinition(
            title: "Sensitive data scanner",
            description: "Check text locally for common personal data and secret patterns.",
            systemImage: "checkmark.shield"
        )
    ]

    var body: some View {
        List {
            Section {
                ForEach(tools) { tool in
                    NavigationLink {
                        if tool.title == "Sensitive data scanner" {
                            SensitiveDataScannerView()
                        } else {
                            QuickTaskWorkspace(task: QuickTask(title: tool.title, workspace: workspace.name))
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tool.title)
                                    .foregroundStyle(.primary)
                                Text(tool.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: tool.systemImage)
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(.vertical, 5)
                    }
                }
            } header: {
                Text(workspace.name)
            } footer: {
                Text("Available tools are controlled by workspace policy.")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Industry tools")
    }
}

private struct PrivacyCentreView: View {
    var body: some View {
        List {
            Section("Current protections") {
                SettingsRow(
                    title: "Provider processing",
                    detail: "Third-party model processing is disclosed before use.",
                    systemImage: "network"
                )
                SettingsRow(
                    title: "Training use",
                    detail: "Off — conversations are not used for model training.",
                    systemImage: "hand.raised"
                )
                SettingsRow(
                    title: "Retention",
                    detail: "Standard workspace policy",
                    systemImage: "calendar.badge.clock"
                )
            }

            Section("Your controls") {
                NavigationLink {
                    PlaceholderDetailView(
                        title: "Private conversations",
                        message: "Private-mode controls will be added in the conversation milestone."
                    )
                } label: {
                    Label("Private conversations", systemImage: "lock")
                }

                NavigationLink {
                    PlaceholderDetailView(
                        title: "Export and deletion",
                        message: "Authenticated export and deletion will be connected to the backend in a later milestone."
                    )
                } label: {
                    Label("Export and deletion", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Text("AegisDesk does not claim that AI output is error-free, professionally definitive, or automatically compliant with law or regulation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Privacy centre")
    }
}

private struct SettingsView: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = true
    @AppStorage("hidePreviews") private var hidePreviews = true
    @AppStorage("sensitiveDataWarnings") private var sensitiveDataWarnings = true
    @AppStorage("lockTiming") private var lockTiming = "Immediately"

    var body: some View {
        Form {
            Section("App protection") {
                Toggle(isOn: $appLockEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("System app lock")
                            Text("Uses Face ID, Touch ID or your device password")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Picker("Require authentication", selection: $lockTiming) {
                    Text("Immediately").tag("Immediately")
                    Text("After 1 minute").tag("After 1 minute")
                    Text("After 5 minutes").tag("After 5 minutes")
                }
                .disabled(!appLockEnabled)
            }

            Section("Privacy on this device") {
                Toggle("Hide content in app previews", isOn: $hidePreviews)
                Toggle("Warn before sharing sensitive data", isOn: $sensitiveDataWarnings)
                SettingsRow(
                    title: "Credentials",
                    detail: "Keychain only — never stored in app settings",
                    systemImage: "key.fill"
                )
            }

            Section("Account security") {
                SettingsRow(
                    title: "Multi-factor authentication",
                    detail: "Authenticator app and recovery codes",
                    systemImage: "checkmark.shield"
                )
                SettingsRow(
                    title: "Passkeys",
                    detail: "Managed by the identity service",
                    systemImage: "person.badge.key"
                )
                SettingsRow(
                    title: "Active sessions",
                    detail: "Device list and remote revocation",
                    systemImage: "iphone.and.arrow.forward"
                )
            }

            Section("Workspace security") {
                LabeledContent("Your role", value: "Member")
                LabeledContent("Training use", value: "Off")
                LabeledContent("Policy status", value: "Current")
            }

            Section {
                Text("AegisDesk never stores an app password. Apple system authentication protects local access. MFA, passkeys, sessions and organisation controls require the secure production backend.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Security & settings")
    }
}

private struct SettingsRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accent)
        }
    }
}

private struct PlaceholderDetailView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text(message)
        )
        .navigationTitle(title)
    }
}

private struct AppLockView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46))
                .foregroundStyle(AppTheme.accent)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("AegisDesk is locked")
                    .font(.title2.bold())
                Text("Authenticate with Apple system security to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: unlock) {
                Label("Unlock", systemImage: "touchid")
                    .frame(minWidth: 110)
            }
            .buttonStyle(AegisPrimaryButtonStyle())
        }
        .padding(34)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .frame(maxWidth: 360)
        .padding()
    }
}

#Preview {
    ProfessionalToolsView()
}
