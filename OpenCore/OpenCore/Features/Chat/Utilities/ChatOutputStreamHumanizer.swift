import Foundation

/// Translates raw CLI commands into compact timeline labels.
nonisolated enum ChatOutputStreamHumanizer {
    struct Info: Equatable, Sendable {
        let verb: String
        let target: String
    }

    static func humanize(_ raw: String, isRunning: Bool) -> Info {
        let command = unwrapShell(raw)
        let (tool, args) = splitToolAndArgs(command)

        switch tool {
        case "cat", "nl", "head", "tail", "sed", "less", "more":
            return Info(
                verb: isRunning ? "Reading" : "Read",
                target: lastPathComponents(from: args, fallback: "file")
            )
        case "rg", "grep", "ag", "ack":
            return Info(
                verb: isRunning ? "Searching" : "Searched",
                target: searchSummary(from: args)
            )
        case "ls":
            return Info(
                verb: isRunning ? "Listing" : "Listed",
                target: lastPathComponents(from: args, fallback: "directory")
            )
        case "find", "fd":
            return Info(
                verb: isRunning ? "Finding" : "Found",
                target: lastPathComponents(from: args, fallback: "files")
            )
        case "mkdir":
            return Info(
                verb: isRunning ? "Creating" : "Created",
                target: lastPathComponents(from: args, fallback: "directory")
            )
        case "rm":
            return Info(
                verb: isRunning ? "Removing" : "Removed",
                target: lastPathComponents(from: args, fallback: "file")
            )
        case "cp", "mv":
            return Info(
                verb: isRunning ? (tool == "cp" ? "Copying" : "Moving") : (tool == "cp" ? "Copied" : "Moved"),
                target: lastPathComponents(from: args, fallback: "file")
            )
        case "git":
            return gitInfo(args, isRunning: isRunning)
        default:
            return Info(
                verb: isRunning ? "Running" : "Ran",
                target: command
            )
        }
    }

    private static func unwrapShell(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = result.lowercased()
        let shellPrefixes = [
            "/usr/bin/bash -lc ", "/usr/bin/bash -c ",
            "/bin/bash -lc ", "/bin/bash -c ",
            "bash -lc ", "bash -c ",
            "/bin/sh -c ", "sh -c ",
        ]

        for prefix in shellPrefixes {
            guard lowered.hasPrefix(prefix) else { continue }
            result = String(result.dropFirst(prefix.count))
            if (result.hasPrefix("\"") && result.hasSuffix("\""))
                || (result.hasPrefix("'") && result.hasSuffix("'")) {
                result = String(result.dropFirst().dropLast())
            }
            if let andIndex = result.range(of: "&&") {
                result = String(result[andIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            break
        }

        if let pipeIndex = result.range(of: " | ") {
            result = String(result[result.startIndex..<pipeIndex.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        return result
    }

    private static func splitToolAndArgs(_ command: String) -> (tool: String, args: String) {
        let parts = command.split(separator: " ", maxSplits: 1)
        let rawTool = parts.first.map(String.init) ?? command
        let tool = (rawTool as NSString).lastPathComponent.lowercased()
        let args = parts.count > 1 ? String(parts[1]) : ""
        return (tool, args)
    }

    private static func lastPathComponents(from args: String, fallback: String) -> String {
        let tokens = args.split(separator: " ")
        for token in tokens.reversed() {
            let value = String(token).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !value.isEmpty, !value.hasPrefix("-") else { continue }
            return compactPath(value)
        }
        return fallback
    }

    private static func compactPath(_ path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 2 else { return path }
        return components.suffix(2).joined(separator: "/")
    }

    private static func searchSummary(from args: String) -> String {
        let tokens = args.split(separator: " ").map(String.init)
        var pattern: String?
        var path: String?

        for token in tokens {
            let value = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !value.isEmpty, !value.hasPrefix("-") else { continue }
            if pattern == nil {
                pattern = value.count > 30 ? String(value.prefix(27)) + "..." : value
            } else if path == nil {
                path = compactPath(value)
            }
        }

        if let pattern, let path {
            return "for \(pattern) in \(path)"
        }
        if let pattern {
            return "for \(pattern)"
        }
        return "..."
    }

    private static func gitInfo(_ args: String, isRunning: Bool) -> Info {
        let parts = args.split(separator: " ", maxSplits: 1)
        let sub = parts.first.map(String.init) ?? ""

        switch sub {
        case "status": return Info(verb: isRunning ? "Checking" : "Checked", target: "git status")
        case "diff": return Info(verb: isRunning ? "Comparing" : "Compared", target: "changes")
        case "log": return Info(verb: isRunning ? "Viewing" : "Viewed", target: "git log")
        case "add": return Info(verb: isRunning ? "Staging" : "Staged", target: "changes")
        case "commit": return Info(verb: isRunning ? "Committing" : "Committed", target: "changes")
        case "push": return Info(verb: isRunning ? "Pushing" : "Pushed", target: "to remote")
        case "pull": return Info(verb: isRunning ? "Pulling" : "Pulled", target: "from remote")
        case "checkout", "switch":
            let branch = parts.count > 1
                ? String(parts[1]).split(separator: " ").last.map(String.init) ?? ""
                : ""
            return Info(
                verb: isRunning ? "Switching to" : "Switched to",
                target: branch.isEmpty ? "branch" : branch
            )
        default:
            return Info(verb: isRunning ? "Running" : "Ran", target: "git " + args)
        }
    }
}
