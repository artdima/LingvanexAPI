import Testing
@testable import LingvanexAPI

@Suite("Package wiring")
struct SmokeTests {

    @Test("The library builds and exposes its entry point")
    func sharedInstanceExists() {
        #expect(LingvanexAPI.shared === LingvanexAPI.shared)
    }
}
