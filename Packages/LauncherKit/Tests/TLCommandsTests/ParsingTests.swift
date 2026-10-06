import ArgumentParser
import Testing
@testable import TLCommands

@Suite struct ParsingTests {
    @Test func dotMeansAdd() throws { #expect((try TL.parseAsRoot(["."]) as? TL.Add)?.path == ".") }
    @Test func explicitAdd() throws { #expect((try TL.parseAsRoot(["add", "~/x"]) as? TL.Add)?.path == "~/x") }
    @Test func rmTakesTarget() throws { #expect((try TL.parseAsRoot(["rm", "2"]) as? TL.Rm)?.target == "2") }
    @Test func ls() throws { #expect(try TL.parseAsRoot(["ls"]) is TL.Ls) }
    @Test func folderNamedLs() throws { #expect((try TL.parseAsRoot(["./ls"]) as? TL.Add)?.path == "./ls") }
    @Test func noArgumentsIsUsageError() {
        do { _ = try TL.parseAsRoot([]); Issue.record("expected error") }
        catch { #expect(TL.exitCode(for: error).rawValue == 64) }
    }
}
