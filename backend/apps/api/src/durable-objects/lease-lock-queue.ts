import { DEFAULT_LEASE_TTL_MS, MIN_LEASE_WAIT_MS } from './apartment-coordinator.constants';

interface ActiveLease {
  readonly token: string;
  readonly expiresAtMs: number;
}

export class LeaseLockQueue {
  private activeLease: ActiveLease | null = null;
  private leaseCounter = 0;
  private readonly waiters: (() => void)[] = [];

  async acquire(
    leaseTtlMs: number = DEFAULT_LEASE_TTL_MS,
    nowMs: number = Date.now(),
  ): Promise<string> {
    while (this.activeLease !== null && this.activeLease.expiresAtMs > nowMs) {
      await this.waitForReleaseOrExpiry(this.activeLease, nowMs);
      nowMs = Date.now();
    }
    this.leaseCounter += 1;
    const token = `lease-${String(this.leaseCounter)}`;
    this.activeLease = { token, expiresAtMs: nowMs + leaseTtlMs };
    return token;
  }

  release(token: string): boolean {
    if (this.activeLease === null || this.activeLease.token !== token) {
      return false;
    }
    this.activeLease = null;
    this.waiters.shift()?.();
    return true;
  }

  private waitForReleaseOrExpiry(lease: ActiveLease, nowMs: number): Promise<void> {
    return new Promise<void>((resolve) => {
      const wake = (): void => {
        clearTimeout(timer);
        resolve();
      };
      const delayMs = Math.max(MIN_LEASE_WAIT_MS, lease.expiresAtMs - nowMs);
      const timer = setTimeout(() => {
        const index = this.waiters.indexOf(wake);
        if (index !== -1) {
          this.waiters.splice(index, 1);
        }
        if (this.activeLease?.token === lease.token) {
          this.activeLease = null;
        }
        resolve();
      }, delayMs);
      this.waiters.push(wake);
    });
  }
}
