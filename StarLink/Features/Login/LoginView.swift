import SwiftUI

/// 登录页 ViewModel（设计书 4.2）
@Observable
final class LoginViewModel {
    var account = ""
    var password = ""
    var showPassword = false
    var isSubmitting = false
    var errorMessage: String?

    var isFormValid: Bool { !account.isEmpty && !password.isEmpty }
    var canSubmit: Bool { !isSubmitting && isFormValid }

    func submit(session: SessionStore) async {
        guard !isSubmitting else { return }
        guard !account.isEmpty else {
            errorMessage = "请输入账号"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await session.login(account: account, password: password)
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = APIError.unknown.userMessage
        }
    }
}

/// 登录页（设计书 4.2）：语义色、语义字体、键盘避让走系统行为
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case account, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.spacing24) {
                logo
                form
                loginButton
            }
            .padding(.horizontal, Metrics.spacing24)
            .padding(.top, Metrics.spacing24)
            .padding(.bottom, Metrics.spacing16)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Text(Self.versionText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, Metrics.spacing8)
        }
    }

    // MARK: - 子视图

    private var logo: some View {
        VStack(spacing: Metrics.spacing12) {
            Text("星链")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.starlinkAccent)
            Text("内部版")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, Metrics.spacing16)
    }

    private var form: some View {
        VStack(spacing: Metrics.spacing12) {
            TextField("账号", text: $viewModel.account)
                .focused($focusedField, equals: .account)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            HStack(spacing: Metrics.spacing8) {
                Group {
                    if viewModel.showPassword {
                        TextField("密码", text: $viewModel.password)
                    } else {
                        SecureField("密码", text: $viewModel.password)
                    }
                }
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await viewModel.submit(session: session) } }
                .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.showPassword.toggle()
                } label: {
                    Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(viewModel.showPassword ? "隐藏密码" : "显示密码")
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var loginButton: some View {
        Button {
            Task { await viewModel.submit(session: session) }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("登录")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!viewModel.canSubmit)
    }

    private static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }
}
