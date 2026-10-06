import TLCommands

// Called from an async function so Swift picks `AsyncParsableCommand.main()`;
// in top-level code it picks the synchronous `ParsableCommand.main()`, which
// refuses async root commands.
func runTL() async {
    await TL.main()
}

await runTL()
