import SwiftUI

struct ContentView: View {
    @StateObject private var manager = HealthKitManager()
    @AppStorage("serverHost") private var serverHost = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.12),
                    Color(red: 0.05, green: 0.12, blue: 0.22),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 140, y: 240)

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("HEALTH SYNC")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(.cyan.opacity(0.85))

                    Text("Apple Health Exporter")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("WINDOWS 主机 IP")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.7))

                    TextField("例如 192.168.1.100", text: $serverHost)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                        )
                        .foregroundColor(.white)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal, 24)

                Button {
                    Task { await runSync() }
                } label: {
                    HStack(spacing: 12) {
                        if manager.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                        Text(manager.isSyncing ? "同步中…" : "一键同步全部健康数据")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.2, green: 0.7, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .cyan.opacity(0.45), radius: 16, y: 6)
                }
                .disabled(manager.isSyncing || serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    if manager.isSyncing || manager.progress > 0 {
                        ProgressView(value: manager.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                            .padding(.horizontal, 24)
                    }

                    Text(manager.statusMessage)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                }

                Spacer()

                Text("\(manager.exportTypeCount) 类指标全量导出")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func runSync() async {
        errorMessage = nil
        do {
            try await manager.syncAll(to: serverHost)
        } catch {
            errorMessage = error.localizedDescription
            manager.statusMessage = "同步失败"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
