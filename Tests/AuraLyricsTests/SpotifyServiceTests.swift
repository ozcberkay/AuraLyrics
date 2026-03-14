import XCTest

final class SpotifyServiceTests: XCTestCase {

    // THRD-03: Compiled NSAppleScript instance reused — not re-inited per poll
    func testPollScriptCompiledOnce() {
        XCTFail("Not yet implemented — implement after Plan 02 @MainActor + Plan 03 serial queue")
    }

    // TIMR-01: pollTimer stored as AnyCancellable? (not Timer.scheduledTimer)
    func testPollTimerCancellable() {
        XCTFail("Not yet implemented — implement after Plan 02 timer migration")
    }

    // TIMR-03: Polling stops on NOT_RUNNING, resumes on next non-NOT_RUNNING result
    func testPollingPausesWhenNotRunning() {
        XCTFail("Not yet implemented — implement after Plan 03 serial queue")
    }

    // NETW-03: Previous artwork task cancelled when new track starts
    func testArtworkTaskCancelledOnTrackChange() {
        XCTFail("Not yet implemented — implement after Plan 03 async artwork")
    }
}
