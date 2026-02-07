import type { LogEntry } from '@logger/shared';
import { config } from './config';

export type HookPhase = 'pre-validate' | 'post-validate' | 'post-store';

type PreValidateHook = (raw: unknown) => unknown;
type PostValidateHook = (entry: LogEntry) => LogEntry;
type PostStoreHook = (entry: LogEntry) => void;

export class HookManager {
  private preValidateHooks: PreValidateHook[] = [];
  private postValidateHooks: PostValidateHook[] = [];
  private postStoreHooks: PostStoreHook[] = [];

  constructor() {
    // Register built-in redact hook if patterns are configured
    if (config.hookRedactPatterns.length > 0) {
      this.registerHook('post-validate', createRedactHook(config.hookRedactPatterns));
    }
  }

  registerHook(phase: 'pre-validate', fn: PreValidateHook): void;
  registerHook(phase: 'post-validate', fn: PostValidateHook): void;
  registerHook(phase: 'post-store', fn: PostStoreHook): void;
  registerHook(phase: HookPhase, fn: PreValidateHook | PostValidateHook | PostStoreHook): void {
    switch (phase) {
      case 'pre-validate':
        this.preValidateHooks.push(fn as PreValidateHook);
        break;
      case 'post-validate':
        this.postValidateHooks.push(fn as PostValidateHook);
        break;
      case 'post-store':
        this.postStoreHooks.push(fn as PostStoreHook);
        break;
    }
  }

  runPreValidate(raw: unknown): unknown {
    let result = raw;
    for (const hook of this.preValidateHooks) {
      result = hook(result);
    }
    return result;
  }

  runPostValidate(entry: LogEntry): LogEntry {
    let result = entry;
    for (const hook of this.postValidateHooks) {
      result = hook(result);
    }
    return result;
  }

  runPostStore(entry: LogEntry): void {
    for (const hook of this.postStoreHooks) {
      hook(entry);
    }
  }
}

/**
 * Create a redact hook that replaces patterns in text fields with [REDACTED].
 */
export function createRedactHook(patterns: readonly string[]): PostValidateHook {
  const regexes = patterns.map((p) => new RegExp(p, 'g'));

  return (entry: LogEntry): LogEntry => {
    if (!entry.text) return entry;

    let text = entry.text;
    for (const re of regexes) {
      re.lastIndex = 0;
      text = text.replace(re, '[REDACTED]');
    }

    if (text === entry.text) return entry;
    return { ...entry, text };
  };
}
