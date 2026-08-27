import SwiftUI

struct SensitiveDataScannerView: View {
    @State private var input = ""

    private var findings: [SensitiveFinding] {
        SensitiveDataScanner.scan(input)
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $input)
                    .frame(minHeight: 180)
                    .font(.body.monospaced())
                    .accessibilityLabel("Text to scan")
            } header: {
                Text("Text to review")
            } footer: {
                Text("Scanning happens locally on this device. Aegis Desk does not upload this text.")
            }

            Section("Scan result") {
                if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Paste or type text to begin", systemImage: "doc.text.magnifyingglass")
                        .foregroundStyle(.secondary)
                } else if findings.isEmpty {
                    Label("No common sensitive-data patterns found", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                } else {
                    ForEach(findings) { finding in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: finding.systemImage)
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(finding.kind)
                                    .font(.headline)
                                Text(finding.redactedValue)
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            if !input.isEmpty {
                Section {
                    Button("Clear text", systemImage: "trash", role: .destructive) {
                        input = ""
                    }
                }
            }
        }
        .navigationTitle("Sensitive Data Scanner")
    }
}

private struct SensitiveFinding: Identifiable {
    let id = UUID()
    let kind: String
    let redactedValue: String
    let systemImage: String
}

private enum SensitiveDataScanner {
    private struct Rule {
        let name: String
        let pattern: String
        let systemImage: String
    }

    private static let rules = [
        Rule(name: "Email address", pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, systemImage: "envelope"),
        Rule(name: "Phone number", pattern: #"(?<!\w)(?:\+?\d[\d\s().-]{7,}\d)(?!\w)"#, systemImage: "phone"),
        Rule(name: "Possible API key", pattern: #"(?i)(?:api[_-]?key|token|secret)\s*[:=]\s*[A-Z0-9_\-]{12,}"#, systemImage: "key"),
        Rule(name: "Possible payment card", pattern: #"(?<!\d)(?:\d[ -]*?){13,19}(?!\d)"#, systemImage: "creditcard")
    ]

    static func scan(_ text: String) -> [SensitiveFinding] {
        var results: [SensitiveFinding] = []

        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                results.append(
                    SensitiveFinding(
                        kind: rule.name,
                        redactedValue: redact(String(text[matchRange])),
                        systemImage: rule.systemImage
                    )
                )
            }
        }

        return results
    }

    private static func redact(_ value: String) -> String {
        guard value.count > 6 else { return String(repeating: "•", count: value.count) }
        return "\(value.prefix(3))\(String(repeating: "•", count: min(12, value.count - 5)))\(value.suffix(2))"
    }
}

#Preview {
    NavigationStack {
        SensitiveDataScannerView()
    }
}
