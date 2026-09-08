import SwiftUI

/// Offline policy for the account-free release. Website publication uses the same copy.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReffiSpace.s6) {
                    Text("Effective date: September 7, 2026").reffiType(.caption)
                        .accessibilityIdentifier("privacy.effectiveDate")
                    Text("Your fridge stays on this device. No sign-in or usage sharing is required.").reffiType(.body)
                    Link("Reffi website", destination: URL(string: "https://reffi-site.vercel.app")!)
                        .frame(minHeight: 44).accessibilityIdentifier("privacy.website")
                    section("Who operates Reffi", "Reffi is operated by Jongmin Lee and Heejae Eo for general audiences in the United States and South Korea. Both operators handle privacy requests at lee1993ljm@gmail.com. Our website is https://reffi-site.vercel.app. This policy describes the version of Reffi that works without new accounts or sign-in.")
                    section("Information on your device", "Ingredient names, quantities, dates, shopping notes, cooking history, saved recipes, nickname, food preferences, allergy entries and settings stay in this device’s app storage. They support inventory management, reminders and recipe matching. Allergy entries are optional and are used only for local filtering. Receipt text recognition runs on the device. Reffi does not upload receipt photos or your fridge to its servers or to an external AI service. This version does not collect or transmit usage analytics, display advertising, sell personal information or share it for cross-context behavioral advertising.")
                    section("Permissions and your choices", "Camera access is requested for receipt scanning. Photo selection gives the app the images you choose. Notifications are optional and are scheduled locally. You may deny or change these permissions in iOS Settings and still enter ingredients by hand. Sharing a cooking card sends the content you select only to the destination you choose. The app does not request your precise location, contacts or advertising tracking permission.")
                    section("Links, video searches and inquiries", "Tapping Videos opens a YouTube search in the current app language. The query can contain a recipe or ingredient name, including a name you entered. YouTube and Google may process the search, connection information and cookies under their own privacy policy. Opening our website connects your browser to its hosting provider, Vercel, which processes web requests and connection information. Our homepage also loads Google Fonts, which sends font requests and connection information to Google. Sending a privacy inquiry gives the operators your email address, message and chosen attachments through Gmail, provided by Google LLC. We use inquiries to respond, verify requests when necessary and protect user rights. These providers operate internationally, including in the United States, and information may be processed outside your country. You can avoid these optional transfers by not opening external links or sending email. Local inventory functions remain available. Do not email passwords or unnecessary sensitive information.")
                    section("Accounts from earlier versions", "New email registration, sign-in and password reset are unavailable in this version. If an earlier installation has a saved account session, the app preserves its local data and supports deletion of that existing account. Authentication and deletion requests use Supabase Inc., a US-based provider; this project’s primary database is in Seoul, South Korea. Existing account records can include your email, account identifier, authentication records and previously shared usage events. They are used to maintain and delete the existing account, not to collect new usage events. Your fridge and allergy entries are not included in these requests. Use Delete account when an existing session is available, or contact the privacy email if you can no longer access it. We may request limited verification before deleting server records.")
                    section("Retention and deletion", "Local records stay until you delete them, reset the current data, erase this device’s app data or delete the app. Erase this device clears all local fridge and profile copies; it does not delete an earlier server account. The current local fridge remains accessible if a saved account session expires. Unsent analytics queues from previous versions are cleared and new events are not recorded. Existing server account and application usage records remain until account deletion or a verified deletion request. In-app account deletion clears the active account and its usage records on the server, then clears that account’s local data after success. Failures are reported. Inquiry messages are kept only as needed to resolve and follow up on the request, then deleted when no longer needed, unless applicable law requires retention. If a specific legal retention requirement applies, we will explain its basis and duration. Provider security logs and recovery copies follow the provider’s retention processes and may not be erased immediately with active records. This project has no scheduled database backups. Device system backups are controlled by your Apple settings. Deleting the app does not delete a server account or copies in system backups.")
                    section("Your rights and safeguards", "You may request access, correction, deletion, restriction or withdrawal of optional consent, as applicable to your location, directly or through an authorized representative. Edit or remove local entries in the app. Contact lee1993ljm@gmail.com for records held by the operators or service providers. We handle requests within the periods required by applicable law and explain any lawful restriction or refusal. You may also complain to the relevant privacy authority, including South Korea’s Personal Information Protection Commission. Server requests use HTTPS and account access controls. Keep your device locked and review its backup settings. No system can guarantee absolute security. This app’s recommendations do not make decisions about legal rights or access to essential services.")
                    section("Children and policy changes", "Reffi is not directed to children under 13 in the United States or under 14 in South Korea. This version does not collect birth dates or offer guardian consent. A parent or guardian who believes a child has provided personal information should contact the privacy email so we can investigate and delete information where required. We will update this policy when our processing changes and provide additional notice or obtain consent where required by applicable law.")
                    Link("Email the privacy contact", destination: URL(string: "mailto:lee1993ljm@gmail.com")!).frame(minHeight: 44)
                    Link("Supabase service providers", destination: URL(string: "https://supabase.com/legal/customer-resources/subprocessor-list")!).frame(minHeight: 44)
                    Link("Google Privacy Policy", destination: URL(string: "https://policies.google.com/privacy")!).frame(minHeight: 44)
                    Link("Vercel Privacy Notice", destination: URL(string: "https://vercel.com/legal/privacy-notice")!).frame(minHeight: 44)
                    Link("Korea Privacy Portal", destination: URL(string: "https://www.privacy.go.kr")!).frame(minHeight: 44)
                }
                .padding(ReffiSpace.s5).frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity).textSelection(.enabled)
            }
            .accessibilityIdentifier("privacy.content")
            .background(PaperCanvasBackground()).tint(ReffiColor.blueDark)
            .navigationTitle("Privacy Policy").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
    private func section(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Text(title).reffiType(.subhead).accessibilityAddTraits(.isHeader)
            Text(text).reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }.fixedSize(horizontal: false, vertical: true)
    }
}
