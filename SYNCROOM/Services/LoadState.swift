//  LoadState.swift
//  The one shape every screen uses to describe "still fetching / here it is /
//  it went wrong". Having a single vocabulary keeps loading, empty and error
//  handling consistent across all twenty-five screens.

import Foundation

enum LoadState<Value: Sendable>: Sendable {
    case loading
    case loaded(Value)
    case failed(DataSourceError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: DataSourceError? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

extension LoadState: Equatable where Value: Equatable {}

extension LoadState {
    /// Runs `work`, mapping success and failure onto the state. Cancellation is
    /// not an error — a cancelled load simply leaves the state untouched.
    static func load(_ work: () async throws -> Value) async -> LoadState<Value> {
        do {
            return .loaded(try await work())
        } catch is CancellationError {
            return .loading
        } catch let error as DataSourceError {
            return .failed(error)
        } catch {
            return .failed(.offline)
        }
    }
}
