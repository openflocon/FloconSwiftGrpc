import SwiftUI

struct ContentView: View {
    private let service = GreeterService()

    @State private var name = "Florent"
    @State private var status = "Start the test server, then call it: the calls show up in the Network section of Flocon."
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Result") {
                    HStack {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }

                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                    Button("Say hello") {
                        call { try await service.sayHello(name: name) }
                    }
                    Button("Call a closed port (connection refused)") {
                        call { try await service.sayHello(name: name, port: GreeterService.closedPort) }
                    }
                } header: {
                    Text("helloworld.Greeter/SayHello")
                } footer: {
                    Text("Server: grpc-test-server/start.sh, on \(GreeterService.host):\(GreeterService.port).")
                }
            }
            .disabled(isLoading)
            .navigationTitle("Flocon gRPC sample")
        }
    }

    private func call(_ action: @escaping @Sendable () async throws -> String) {
        Task {
            isLoading = true
            do {
                status = "Reply: \(try await action())"
            } catch {
                status = "Error: \(error)"
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
