//
//  LingvanexAPI.swift
//  LingvanexAPI
//
//  Created by Medyannik Dmitri on 07.02.2021.
//

import Foundation

/// The 0.x entry point, kept so existing code keeps compiling.
///
/// It forwards to ``LingvanexClient``. Three things changed that no wrapper can hide:
/// a failure now arrives as a ``LingvanexError`` where it used to arrive as `nil, nil`,
/// an unconfigured client reports `.notConfigured` instead of crashing, and the type is
/// bound to the main actor.
///
/// The main-actor binding is what the mutable singleton always needed and never declared:
/// reconfiguring it from one thread while a request read the key was a data race. Callers
/// that used it from the main thread — which is what the completion handlers assumed —
/// are unaffected, and their completions now arrive on the main actor by construction.
///
/// This type is removed in 2.0.
@MainActor
public final class LingvanexAPI {

    @available(*, deprecated, message: "Create a LingvanexClient with its key instead of configuring a singleton")
    public static let shared = LingvanexAPI()

    private let template: LingvanexConfiguration?
    private var client: LingvanexClient?

    public init() {
        template = nil
    }

    /// Lets the wrapper be exercised without a network.
    init(configuration: LingvanexConfiguration) {
        template = configuration
        client = LingvanexClient(configuration: configuration)
    }

    @available(*, deprecated, message: "Pass the key to LingvanexClient(apiKey:)")
    public func start(with apiKey: String) {
        if var configuration = template {
            configuration.apiKey = APIKey(apiKey)
            client = LingvanexClient(configuration: configuration)
        } else {
            client = LingvanexClient(apiKey: apiKey)
        }
    }

    @available(*, deprecated, renamed: "LingvanexClient.translate(_:from:to:options:)")
    public func translate(
        _ from: String,
        _ to: String,
        _ data: String,
        _ platform: String = "api",
        _ completion: @escaping @MainActor (_ translate: Translation?, _ error: Error?) -> Void
    ) {
        guard let client else {
            completion(nil, LingvanexError.notConfigured)
            return
        }
        guard let target = LanguageCode(rawValue: to) else {
            completion(nil, LingvanexError.invalidLanguageCode(to))
            return
        }
        let source = LanguageCode(rawValue: from)

        Task { @MainActor in
            do {
                let translation = try await client.translate(.text(data), from: source, to: target)
                completion(translation, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    @available(*, deprecated, renamed: "LingvanexClient.languages(displayLanguage:)")
    public func getLanguages(
        _ code: String?,
        _ platform: String = "api",
        _ completion: @escaping @MainActor (_ languages: [Language]?, _ error: Error?) -> Void
    ) {
        guard let client else {
            completion(nil, LingvanexError.notConfigured)
            return
        }
        let displayLanguage = code.flatMap(LanguageCode.init(rawValue:))

        Task { @MainActor in
            do {
                let languages = try await client.languages(displayLanguage: displayLanguage)
                completion(languages, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
