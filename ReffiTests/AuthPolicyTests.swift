import Testing
import Foundation
import Supabase
@testable import Reffi

/// 로그인 화면·콜백의 순수 판정 함수를 고정한다 — PR #24 리뷰에서 드러난 회귀 두 가지가 다시 생기지
/// 않게: ① 비밀번호 하한(8자)이 **로그인**까지 막아 옛 6~7자 계정이 영원히 못 들어오던 것,
/// ② PKCE 재설정 링크가 `.passwordRecovery`를 내지 않아 새 비밀번호 시트가 열리지 않던 것.
struct AuthPolicyTests {

    // MARK: 제출 판정 — 하한은 가입에만

    @Test func signInAcceptsLegacyShortPassword() {
        #expect(AuthView.canSubmit(email: "a@b.co", password: "sixchr", isSignIn: true))
    }

    @Test func signUpEnforcesClientMinimum() {
        #expect(!AuthView.canSubmit(email: "a@b.co", password: "seven77", isSignIn: false))
        #expect(AuthView.canSubmit(email: "a@b.co", password: "eight888", isSignIn: false))
        #expect(AuthView.PasswordRule.min == 8)
    }

    @Test func emptyPasswordOrMalformedEmailNeverSubmits() {
        #expect(!AuthView.canSubmit(email: "a@b.co", password: "", isSignIn: true))
        #expect(!AuthView.canSubmit(email: "nobody", password: "longenough", isSignIn: true))
        #expect(!AuthView.canSubmit(email: "nobody", password: "longenough", isSignIn: false))
    }

    // MARK: 재설정 링크 판정 — 요청 기억 또는 URL 힌트

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let callback = URL(string: "reffi://auth-callback?code=abc")!

    @Test func recentResetRequestOpensPasswordSheet() {
        #expect(AuthStore.isRecoveryCallback(callback, requestedAt: now.addingTimeInterval(-600), now: now))
    }

    @Test func staleOrMissingResetRequestDoesNot() {
        #expect(!AuthStore.isRecoveryCallback(callback, requestedAt: now.addingTimeInterval(-3 * 86_400), now: now))
        #expect(!AuthStore.isRecoveryCallback(callback, requestedAt: nil, now: now))
    }

    @Test func urlTypeHintOpensPasswordSheetWithoutMemory() {
        let hinted = URL(string: "reffi://auth-callback?code=abc&type=recovery")!
        #expect(AuthStore.isRecoveryCallback(hinted, requestedAt: nil, now: now))
    }

    // MARK: 콜백 실패 분류 — 오프라인은 "다시 탭", 그 외는 "새 링크"

    @Test func networkFailureAsksToRetryNotToRequestNewLink() {
        #expect(AuthStore.callbackFailure(for: URLError(.notConnectedToInternet)) == .linkOffline)
    }

    @Test func exchangeFailureAsksForNewLink() {
        let expired = AuthError.pkceGrantCodeExchange(message: "Email link is invalid or has expired",
                                                      error: "access_denied", code: "otp_expired")
        #expect(AuthStore.callbackFailure(for: expired) == .linkInvalid)
        #expect(AuthStore.callbackFailure(for: AuthError.sessionMissing) == .linkInvalid)
    }

    @MainActor
    @Test(arguments: [["length"], ["characters"], ["length", "characters"], []])
    func passwordPolicyFailureDoesNotClaimABreach(reasons: [String]) {
        let error = AuthError.weakPassword(message: "Password does not meet policy", reasons: reasons)
        #expect(AuthStore.friendly(error) == String(localized: "That password doesn't meet the requirements.\nTry a longer one with letters and numbers."))
    }

    @MainActor
    @Test func confirmedBreachedPasswordGetsSpecificGuidance() {
        let error = AuthError.weakPassword(message: "Weak password", reasons: ["pwned"])
        #expect(AuthStore.friendly(error) == String(localized: "This password has appeared in a data breach.\nChoose a different one."))
    }

    @MainActor
    @Test func legacyBreachMessageStillGetsSpecificGuidance() {
        let error = AuthError.api(message: "Password is known to be weak and easy to guess", errorCode: .weakPassword,
                                  underlyingData: Data(),
                                  underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 422, httpVersion: nil, headerFields: nil)!)
        #expect(AuthStore.friendly(error) == String(localized: "This password has appeared in a data breach.\nChoose a different one."))
    }

    @MainActor
    @Test func genericWeakPasswordCodeDoesNotClaimABreach() {
        let error = AuthError.api(message: "Password should contain a digit", errorCode: .weakPassword,
                                  underlyingData: Data(),
                                  underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 422, httpVersion: nil, headerFields: nil)!)
        #expect(AuthStore.friendly(error) == String(localized: "That password doesn't meet the requirements.\nTry a longer one with letters and numbers."))
    }

}
