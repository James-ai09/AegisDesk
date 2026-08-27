import Foundation

enum AISecurityGate {
    static func warning(for text: String) -> String? {
        let checks: [(String, String)] = [
            (#"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"#, "A private key was detected. Remove it before asking the AI."),
            (#"\bsk-[A-Za-z0-9_-]{16,}\b"#, "A likely API key was detected. Remove it before asking the AI."),
            (#"\bAKIA[0-9A-Z]{16}\b"#, "A likely cloud access key was detected. Remove it before asking the AI."),
            (#"(?i)\b(password|passwd|secret|api[_ -]?key)\s*[:=]\s*\S{6,}"#, "A password or secret value was detected. Remove it before asking the AI.")
        ]

        for (pattern, message) in checks {
            if text.range(of: pattern, options: .regularExpression) != nil { return message }
        }
        return nil
    }
}
