# Deflector

Resilient fault-tolerance engine for Elixir applications. Provides high-throughput sliding window circuit breaking, concurrent process bulkhead isolation, and token bucket rate limiting with zero external runtime dependencies.

## Key Features

- **Circuit Breaker**: Sliding window circular buffer tracking error ratios with automatic half-open probes.
- **Bulkhead Isolation**: Bounded concurrency execution partitions protecting critical OTP processes.
- **Rate Limiter**: Sub-millisecond token bucket implementation with monotonic clock replenishment.
- **Telemetry**: Zero-cost instrumentation and metrics dispatching for observability.

## Installation

Add `deflector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:deflector, "~> 1.0.0"}
  ]
end
```