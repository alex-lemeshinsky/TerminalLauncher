import ArgumentParser

public struct TL: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "tl",
        abstract: "Save folders for the TerminalLauncher widget.",
        subcommands: [Add.self, Rm.self, Ls.self],
        defaultSubcommand: Add.self
    )

    public init() {}

    public struct Add: AsyncParsableCommand {
        @Argument(help: "Folder to add, e.g. .")
        public var path: String

        public init() {}

        public func run() async throws {
            try await Commands.live().add(path).finish()
        }
    }

    public struct Rm: AsyncParsableCommand {
        @Argument(help: "Number from tl ls, or a folder path")
        public var target: String

        public init() {}

        public func run() async throws {
            try await Commands.live().remove(target).finish()
        }
    }

    public struct Ls: AsyncParsableCommand {
        public init() {}

        public func run() async throws {
            try Commands.live().list().finish()
        }
    }
}

extension CommandResult {
    /// Prints the result, then turns a non-zero exit code into an `ExitCode` error.
    fileprivate func finish() throws {
        emit()
        if exitCode != 0 { throw ExitCode(exitCode) }
    }
}
