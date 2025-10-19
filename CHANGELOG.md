# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-19

### Added
- Sliding window circular buffer circuit breaker (`Deflector.CircuitBreaker`).
- Concurrent process bulkhead isolation engine (`Deflector.Bulkhead`).
- Sub-millisecond continuous token bucket rate limiter (`Deflector.RateLimiter`).
- Unified execution pipeline via `Deflector.protect/2`.
- Telemetry metrics dispatching hooks (`Deflector.Telemetry`).
- Comprehensive unit and integration test coverage.

## [0.1.0] - 2025-10-02

### Added
- Project foundation, build configuration, and documentation.