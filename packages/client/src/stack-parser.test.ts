import { describe, expect, test } from 'bun:test';
import { parseStackTrace } from './stack-parser.js';

describe('parseStackTrace', () => {
  test('parse V8 stack trace', () => {
    const stack = `Error: something failed
    at myFunction (/home/user/project/src/index.ts:10:5)
    at Object.run (/home/user/project/src/runner.ts:42:12)`;

    const frames = parseStackTrace(stack);
    expect(frames).toHaveLength(2);

    expect(frames[0].location.symbol).toBe('myFunction');
    expect(frames[0].location.uri).toBe('/home/user/project/src/index.ts');
    expect(frames[0].location.line).toBe(10);
    expect(frames[0].location.column).toBe(5);
    expect(frames[0].is_vendor).toBe(false);

    expect(frames[1].location.symbol).toBe('Object.run');
    expect(frames[1].location.uri).toBe('/home/user/project/src/runner.ts');
    expect(frames[1].location.line).toBe(42);
    expect(frames[1].location.column).toBe(12);
  });

  test('parse Bun stack trace (no parens)', () => {
    const stack = `Error: boom
    at /home/user/project/src/main.ts:5:3`;

    const frames = parseStackTrace(stack);
    expect(frames).toHaveLength(1);
    expect(frames[0].location.uri).toBe('/home/user/project/src/main.ts');
    expect(frames[0].location.line).toBe(5);
    expect(frames[0].location.column).toBe(3);
    expect(frames[0].location.symbol).toBeUndefined();
  });

  test('handle async frames', () => {
    const stack = `Error: async fail
    at async loadData (/home/user/project/src/loader.ts:20:10)
    at async main (/home/user/project/src/index.ts:5:3)`;

    const frames = parseStackTrace(stack);
    expect(frames).toHaveLength(2);
    expect(frames[0].location.symbol).toBe('loadData');
    expect(frames[0].location.uri).toBe('/home/user/project/src/loader.ts');
    expect(frames[1].location.symbol).toBe('main');
  });

  test('mark vendor frames', () => {
    const stack = `Error: dep error
    at myCode (/home/user/project/src/app.ts:1:1)
    at depFunc (/home/user/project/node_modules/some-lib/index.js:50:8)
    at internal (node:internal/process:10:5)`;

    const frames = parseStackTrace(stack);
    expect(frames).toHaveLength(3);
    expect(frames[0].is_vendor).toBe(false);
    expect(frames[1].is_vendor).toBe(true);
    expect(frames[2].is_vendor).toBe(true);
  });

  test('handle malformed stack', () => {
    const stack = `not a stack trace at all
just some random text
123`;

    const frames = parseStackTrace(stack);
    expect(frames).toHaveLength(0);
  });
});
