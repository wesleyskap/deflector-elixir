# Deflector

Resilient fault-tolerance engine for Elixir applications. Provides high-throughput sliding window circuit breaking, concurrent process bulkhead isolation, and token bucket rate limiting with zero external runtime dependencies.

## Key Features

- **Circuit Breaker**: Sliding window circular buffer tracking error ratios with automatic half-open probes.
- **Bulkhead Isolation**: Bounded concurrency execution partitions protecting critical OTP processes.
- **Rate Limiter**: Sub-millisecond token bucket implementation with monotonic clock replenishment.
- **Unified Pipeline**: Single `Deflector.protect/2` call composing circuit breaker, bulkhead, and rate limiter.
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

## Basic Usage

### Supervised Initialization

```elixir
# In your application supervision tree
children = [
  {Deflector.CircuitBreaker, name: :api_breaker, threshold: 0.5, reset_timeout: 5000},
  {Deflector.Bulkhead, name: :api_bulkhead, max_concurrent: 20, max_queue: 100},
  {Deflector.RateLimiter, name: :api_limiter, rate: 100, capacity: 100}
]
```

### Unified Execution

```elixir
result = Deflector.protect(
  [circuit_breaker: :api_breaker, bulkhead: :api_bulkhead, rate_limiter: :api_limiter],
  fn ->
    HTTPClient.post("https://service.internal/orders", payload)
  end
)
```