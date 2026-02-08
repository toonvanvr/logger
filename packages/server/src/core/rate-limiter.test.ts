import { describe, expect, it } from 'bun:test';
import { RateLimiter } from './rate-limiter';

describe('RateLimiter', () => {
  it('consumes tokens up to limit', () => {
    // 10 tokens/sec, session 5 tokens/sec, burst 1× (no burst bonus)
    const limiter = new RateLimiter(10, 5, 1);

    // Should be able to consume 5 tokens (session limit)
    for (let i = 0; i < 5; i++) {
      expect(limiter.tryConsume('sess-1')).toBe(true);
    }
  });

  it('rejects when session tokens depleted', () => {
    const limiter = new RateLimiter(100, 3, 1);

    expect(limiter.tryConsume('sess-1')).toBe(true);
    expect(limiter.tryConsume('sess-1')).toBe(true);
    expect(limiter.tryConsume('sess-1')).toBe(true);
    // 4th should fail
    expect(limiter.tryConsume('sess-1')).toBe(false);
  });

  it('rejects when global tokens depleted', () => {
    const limiter = new RateLimiter(3, 100, 1);

    expect(limiter.tryConsume('sess-1')).toBe(true);
    expect(limiter.tryConsume('sess-2')).toBe(true);
    expect(limiter.tryConsume('sess-3')).toBe(true);
    // 4th should fail (global exhausted)
    expect(limiter.tryConsume('sess-4')).toBe(false);
  });

  it('refills after time passes', async () => {
    const limiter = new RateLimiter(100, 5, 1);

    // Exhaust session tokens
    for (let i = 0; i < 5; i++) {
      limiter.tryConsume('sess-1');
    }
    expect(limiter.tryConsume('sess-1')).toBe(false);

    // Wait for refill (5 tokens/sec → 1 token per 200ms)
    await new Promise((resolve) => setTimeout(resolve, 250));
    expect(limiter.tryConsume('sess-1')).toBe(true);
  });

  it('isolates per-session buckets', () => {
    const limiter = new RateLimiter(100, 2, 1);

    // Exhaust sess-1
    limiter.tryConsume('sess-1');
    limiter.tryConsume('sess-1');
    expect(limiter.tryConsume('sess-1')).toBe(false);

    // sess-2 should still have tokens
    expect(limiter.tryConsume('sess-2')).toBe(true);
  });

  it('burst allows 2× rate', () => {
    const limiter = new RateLimiter(100, 5, 2);

    // Burst capacity = 5 * 2 = 10
    let consumed = 0;
    for (let i = 0; i < 15; i++) {
      if (limiter.tryConsume('sess-1')) consumed++;
    }
    expect(consumed).toBe(10);
  });

  it('getStats returns token counts', () => {
    const limiter = new RateLimiter(10, 5, 1);

    limiter.tryConsume('sess-1');
    limiter.tryConsume('sess-2');

    const stats = limiter.getStats();
    expect(stats.globalTokens).toBeLessThan(10);
    expect(stats.sessionBuckets).toBe(2);
    expect(stats.sessions.has('sess-1')).toBe(true);
    expect(stats.sessions.has('sess-2')).toBe(true);
  });
});
