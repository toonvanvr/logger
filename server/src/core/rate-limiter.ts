interface Bucket {
  tokens: number;
  lastRefill: number;
}

export interface RateLimiterStats {
  globalTokens: number;
  sessionBuckets: number;
  sessions: Map<string, { tokens: number }>;
}

export class RateLimiter {
  private readonly globalRate: number;
  private readonly sessionRate: number;
  private readonly burstMultiplier: number;
  private globalBucket: Bucket;
  private sessionBuckets = new Map<string, Bucket>();

  constructor(globalRate: number, sessionRate: number, burstMultiplier: number) {
    this.globalRate = globalRate;
    this.sessionRate = sessionRate;
    this.burstMultiplier = burstMultiplier;

    this.globalBucket = {
      tokens: globalRate * burstMultiplier,
      lastRefill: Date.now(),
    };
  }

  tryConsume(sessionId: string): boolean {
    const now = Date.now();

    // Refill and check global bucket
    this.refill(this.globalBucket, this.globalRate, now);
    if (this.globalBucket.tokens < 1) {
      return false;
    }

    // Refill and check session bucket
    let session = this.sessionBuckets.get(sessionId);
    if (!session) {
      session = {
        tokens: this.sessionRate * this.burstMultiplier,
        lastRefill: now,
      };
      this.sessionBuckets.set(sessionId, session);
    }
    this.refill(session, this.sessionRate, now);
    if (session.tokens < 1) {
      return false;
    }

    // Consume from both buckets
    this.globalBucket.tokens -= 1;
    session.tokens -= 1;
    return true;
  }

  getStats(): RateLimiterStats {
    const sessions = new Map<string, { tokens: number }>();
    for (const [id, bucket] of this.sessionBuckets) {
      sessions.set(id, { tokens: bucket.tokens });
    }
    return {
      globalTokens: this.globalBucket.tokens,
      sessionBuckets: this.sessionBuckets.size,
      sessions,
    };
  }

  private refill(bucket: Bucket, rate: number, now: number): void {
    const elapsed = (now - bucket.lastRefill) / 1000; // seconds
    if (elapsed <= 0) return;

    const maxCapacity = rate * this.burstMultiplier;
    bucket.tokens = Math.min(maxCapacity, bucket.tokens + elapsed * rate);
    bucket.lastRefill = now;
  }
}
