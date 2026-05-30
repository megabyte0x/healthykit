import Foundation

enum HTTPStatusClassification: Equatable {
    case accepted
    case authError
    case transient
    case permanent
}

enum APIClientError: LocalizedError, Equatable {
    case invalidBackendURL
    case missingBackendURL
    case missingToken
    case authRejected
    case transientFailure(String)
    case serverRejected(Int)
    case invalidResponse

    var userMessage: String {
        switch self {
        case .invalidBackendURL:
            "Enter a valid backend URL."
        case .missingBackendURL:
            "Backend URL is required before syncing."
        case .missingToken:
            "Auth token is required before syncing."
        case .authRejected:
            "The backend rejected the auth token."
        case let .transientFailure(message):
            message.isEmpty ? "Network unavailable or server temporarily unavailable." : message
        case let .serverRejected(statusCode):
            "The backend rejected the sync request with status \(statusCode)."
        case .invalidResponse:
            "The backend returned an invalid response."
        }
    }

    var errorDescription: String? {
        userMessage
    }
}

struct UploadConfiguration: Equatable {
    let baseURL: String
    let token: String
    let deviceID: String
    let appVersion: String
}

struct HostedWorkspaceProvisioningResponse: Codable, Equatable {
    let workspaceID: String
    let backendURL: String
    let ingestToken: String
    let agentEndpoint: String
    let agentToken: String

    private enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace_id"
        case backendURL = "backend_url"
        case ingestToken = "ingest_token"
        case agentEndpoint = "agent_endpoint"
        case agentToken = "agent_token"
    }
}

struct HostedWorkspaceProvisioningRequest: Codable {
    let label: String?
}

protocol SyncUploading {
    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult
}

final class APIClient: SyncUploading {
    private let session: URLSession
    private let maxAttempts: Int

    init(session: URLSession = .shared, maxAttempts: Int = 3) {
        self.session = session
        self.maxAttempts = max(1, maxAttempts)
    }

    static func classify(statusCode: Int) -> HTTPStatusClassification {
        switch statusCode {
        case 200, 201, 202:
            .accepted
        case 401, 403:
            .authError
        case 429, 500...599:
            .transient
        default:
            .permanent
        }
    }

    static func makeSyncRequest(
        baseURL: String,
        token: String,
        deviceID: String,
        appVersion: String,
        payload: SyncPayload
    ) throws -> URLRequest {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw APIClientError.missingToken }
        let rootURL = try validatedRootURL(from: baseURL)

        let endpoint = rootURL
            .appendingPathComponent("api")
            .appendingPathComponent("apple-health")
            .appendingPathComponent("sync")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.httpBody = try PayloadJSON.encoder.encode(payload)
        return request
    }

    static func makeHostedWorkspaceRequest(baseURL: String, label: String?) throws -> URLRequest {
        let rootURL = try validatedRootURL(from: baseURL)
        let endpoint = rootURL
            .appendingPathComponent("api")
            .appendingPathComponent("hosted")
            .appendingPathComponent("workspaces")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(HostedWorkspaceProvisioningRequest(label: label))
        return request
    }

    func upload(batch: SyncBatch, configuration: UploadConfiguration) async throws -> UploadResult {
        let request = try Self.makeSyncRequest(
            baseURL: configuration.baseURL,
            token: configuration.token,
            deviceID: configuration.deviceID,
            appVersion: configuration.appVersion,
            payload: batch.payload
        )

        var lastTransientError: APIClientError = .transientFailure("Network unavailable or server temporarily unavailable.")
        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIClientError.invalidResponse
                }
                switch Self.classify(statusCode: httpResponse.statusCode) {
                case .accepted:
                    if data.isEmpty {
                        return UploadResult(
                            ok: true,
                            received: batch.payload.metrics.count + batch.payload.workouts.count,
                            duplicates: 0
                        )
                    }
                    return try JSONDecoder().decode(UploadResult.self, from: data)
                case .authError:
                    throw APIClientError.authRejected
                case .permanent:
                    throw APIClientError.serverRejected(httpResponse.statusCode)
                case .transient:
                    lastTransientError = .transientFailure("Server temporarily unavailable (\(httpResponse.statusCode)).")
                    if attempt < maxAttempts - 1 {
                        try await sleepBeforeRetry(attempt: attempt)
                    }
                }
            } catch let error as APIClientError {
                switch error {
                case .authRejected, .serverRejected, .invalidBackendURL, .missingBackendURL, .missingToken, .invalidResponse:
                    throw error
                case .transientFailure:
                    lastTransientError = error
                    if attempt < maxAttempts - 1 {
                        try await sleepBeforeRetry(attempt: attempt)
                    }
                }
            } catch {
                lastTransientError = .transientFailure("Network unavailable or server temporarily unavailable.")
                if attempt < maxAttempts - 1 {
                    try await sleepBeforeRetry(attempt: attempt)
                }
            }
        }
        throw lastTransientError
    }

    func provisionHostedWorkspace(baseURL: String, label: String?) async throws -> HostedWorkspaceProvisioningResponse {
        let request = try Self.makeHostedWorkspaceRequest(baseURL: baseURL, label: label)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        switch Self.classify(statusCode: httpResponse.statusCode) {
        case .accepted:
            do {
                return try JSONDecoder().decode(HostedWorkspaceProvisioningResponse.self, from: data)
            } catch {
                throw APIClientError.invalidResponse
            }
        case .authError:
            throw APIClientError.authRejected
        case .transient, .permanent:
            throw APIClientError.serverRejected(httpResponse.statusCode)
        }
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let delay = UInt64(pow(2.0, Double(attempt)) * 250_000_000)
        try await Task.sleep(nanoseconds: delay)
    }

    private static func validatedRootURL(from baseURL: String) throws -> URL {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { throw APIClientError.missingBackendURL }
        guard
            let rootURL = URL(string: trimmedURL),
            let scheme = rootURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            rootURL.host != nil
        else {
            throw APIClientError.invalidBackendURL
        }
        return rootURL
    }
}
