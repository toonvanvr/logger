export interface StackFrame {
  location: { uri: string; line: number; column: number; symbol?: string }
  isVendor: boolean
  raw: string
}

/**
 * Parse a V8 / Bun stack trace string into structured StackFrame[].
 *
 * Handles:
 *   at functionName (file:line:col)
 *   at file:line:col
 *   at async functionName (file:line:col)
 *   at new ClassName (file:line:col)
 */
export function parseStackTrace(stack: string): StackFrame[] {
  const frames: StackFrame[] = [];
  const lines = stack.split('\n');

  // Matches:  "  at [async] [new] symbol (uri:line:col)"
  //           "  at [async] uri:line:col"
  const RE_FRAME =
    /^\s*at\s+(?:async\s+)?(?:new\s+)?(?:(.+?)\s+\((.+?):(\d+):(\d+)\)|(.+?):(\d+):(\d+))\s*$/;

  for (const line of lines) {
    const m = RE_FRAME.exec(line);
    if (!m) continue;

    const hasParens = m[2] !== undefined;
    const symbol = hasParens ? m[1] : undefined;
    const uri = hasParens ? m[2]! : m[5]!;
    const lineNo = parseInt(hasParens ? m[3]! : m[6]!, 10);
    const col = parseInt(hasParens ? m[4]! : m[7]!, 10);
    const isVendor = uri.includes('node_modules') || uri.startsWith('node:');

    frames.push({
      location: {
        uri,
        line: lineNo,
        column: col,
        ...(symbol ? { symbol } : {}),
      },
      isVendor,
      raw: line.trim(),
    });
  }

  return frames;
}
