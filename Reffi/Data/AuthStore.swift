import Foundation
import Observation
import os
import Supabase

/// 인증 상태 — Supabase Auth 세션의 단일 소스.
/// 신규 로그인 없이 로컬에서 사용한다. 기존 설치의 세션 복원과 계정 삭제만 유지한다.
/// 세션은 supabase-swift가 Keychain에 영속화하고, `authStateChanges`로 복원·구독한다.
@Observable
@MainActor
final class AuthStore {

    /// 프로젝트 URL·publishable(anon) key — 클라이언트 임베드용 공개 값(RLS로 보호).
    static let supabaseURL = URL(string: "https://bzzpmaeitfbbunsmjvmd.supabase.co")!
    static let anonKey = "sb_publishable_RolVTNQCWTf9t9XBEcCz1w_HcEeYquc"

    /// Supabase 클라이언트 — publishable key는 클라이언트 임베드용 공개 키(RLS로 보호).
    static let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey,
        options: .init(auth: .init(emitLocalSessionAsInitialSession: true)))

    /// 인증 진단 로그(FridgeStore.log와 같은 서브시스템). 화면에 못 내보내는 서버 원문이 여기로 간다.
    static let log = Logger(subsystem: "com.reffi.app", category: "auth")

    // MARK: - 상태

    private(set) var session: Session?
    /// 서버 계정 없이 사용하는 로컬 모드.
    private(set) var localGuest: Bool
    /// 저장된 세션 복원 중(첫 프레임 스플래시 판단용).
    private(set) var restoring = true
    /// Only an explicit erase/delete flow leaves the saved local owner. Token expiry does not.
    private(set) var retainsLocalDataOwner = true
    /// 네트워크 요청 진행 중(버튼 비활성).
    private(set) var busy = false

    var errorMessage: String?
    /// 계정 관리 안내.
    var notice: String?

    /// 게스트 = 과거 익명 세션 또는 로컬 모드.
    var isGuest: Bool { session?.user.isAnonymous == true || localGuest }
    /// 앱 진입은 로컬 자료 접근이다. 만료된 캐시도 소유자 복원에 사용하며 서버 작업은 별도로 인증한다.
    var isSignedIn: Bool { session != nil || localGuest }
    var userEmail: String? { session?.user.email }
    /// 로컬 저장 공간의 소유자. 익명/로컬 게스트는 별도 guest 공간을 사용한다.
    var accountUserID: String? {
        guard let user = session?.user, !user.isAnonymous else { return nil }
        return user.id.uuidString
    }

    init() {
        var guest = true
        #if DEBUG
        // 스크린샷·QA용 — 인증 게이트 건너뛰기(-fridgeTab 선례).
        if ProcessInfo.processInfo.arguments.contains("-skipAuth") { guest = true }
        if ProcessInfo.processInfo.arguments.contains("-authGate") { guest = false }
        #endif
        localGuest = guest
        Task { await listen() }
    }

    /// Keychain의 세션을 복원하고 이후 변경(로그인·로그아웃·갱신)을 구독.
    private func listen() async {
        for await (event, session) in Self.client.auth.authStateChanges {
            let wasAnonymous = self.session?.user.isAnonymous == true
            if self.session?.user.id != session?.user.id {
                Analytics.shared.changeAccount(to: session?.user.id.uuidString)
            }
            self.session = session
            setLocalGuest(session == nil)
            if event == .initialSession { restoring = false }
            trackAuthChange(event, session: session, wasAnonymous: wasAnonymous)
        }
    }

    /// 계정 이벤트(64차) — 로그인 방식·익명 여부·익명→정식 승계만 남긴다(이메일·id는 싣지 않는다).
    /// 세션이 생기는 순간 큐를 밀어낸다: `user_id`는 서버가 `auth.uid()`로 채우므로 세션 없인 못 올린다.
    private func trackAuthChange(_ event: AuthChangeEvent, session: Session?, wasAnonymous: Bool) {
        switch event {
        case .signedIn:
            guard let user = session?.user else { return }
            Analytics.shared.track(.authSignIn(provider: Self.provider(of: user), anonymous: user.isAnonymous))
            Analytics.shared.flushSoon()
        case .userUpdated:
            guard let user = session?.user, wasAnonymous, !user.isAnonymous else { return }
            Analytics.shared.track(.authUpgrade(provider: Self.provider(of: user)))
        case .signedOut:
            Analytics.shared.track(.authSignOut)
        case .initialSession, .tokenRefreshed:
            if session != nil { Analytics.shared.flushSoon() }
        default:
            break
        }
    }

    private static func provider(of user: User) -> String {
        user.appMetadata["provider"]?.stringValue ?? (user.isAnonymous ? "anonymous" : "unknown")
    }

    // MARK: - 게스트 · 로그아웃

    /// 서버 요청 없이 기기 내에서 시작한다.
    func continueAsGuest() async {
        setLocalGuest(true)
    }

    /// 기기 초기화 또는 계정 삭제 후 인증 세션을 해제한다.
    /// Supabase의 로컬 세션 제거는 서버 요청보다 먼저 이뤄지므로 오프라인에서도 로그아웃한다.
    func signOut() async {
        retainsLocalDataOwner = false
        errorMessage = nil
        notice = nil
        setLocalGuest(false)
        busy = true
        defer { busy = false }
        try? await Self.client.auth.signOut(scope: .local)
        session = nil
        setLocalGuest(true)
    }

    // MARK: - 계정 관리

    /// 서버가 삭제를 확정한 뒤에만 호출부가 로컬 자료를 지우고 로그아웃한다.
    func deleteAccount() async -> Bool {
        guard accountUserID != nil, !busy else { return false }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            try await Self.client.rpc("delete_own_account").execute()
            return true
        } catch {
            errorMessage = String(localized: "Couldn't delete your account. Your data is still saved. Check your connection and try again.")
            return false
        }
    }

    private func setLocalGuest(_ v: Bool) {
        guard localGuest != v else { return }
        localGuest = v
        UserDefaults.standard.set(v, forKey: Key.guest)
    }

    private enum Key {
        static let guest = "auth.guest"
    }

}
