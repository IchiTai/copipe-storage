import Testing
@testable import CopipeCore

@Suite struct LimitsTests {
    @Test func defaults() {
        let limits = Limits()
        #expect(limits.maxClips == 1000)
        #expect(limits.maxClipBytes == 50 * 1024 * 1024)
    }

    @Test(arguments: [(50, 100), (100, 100), (1234, 1234), (3000, 3000), (9999, 3000)])
    func clampsCount(input: Int, expected: Int) {
        #expect(Limits(maxClips: input).maxClips == expected)
    }
}
