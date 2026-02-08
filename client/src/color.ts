const ESC = '\x1B['

// ─── Foreground Colors ───────────────────────────────────────
export const red = (t: string) => `${ESC}31m${t}${ESC}39m`
export const green = (t: string) => `${ESC}32m${t}${ESC}39m`
export const yellow = (t: string) => `${ESC}33m${t}${ESC}39m`
export const blue = (t: string) => `${ESC}34m${t}${ESC}39m`
export const magenta = (t: string) => `${ESC}35m${t}${ESC}39m`
export const cyan = (t: string) => `${ESC}36m${t}${ESC}39m`
export const white = (t: string) => `${ESC}37m${t}${ESC}39m`
export const gray = (t: string) => `${ESC}90m${t}${ESC}39m` // bright black
export const black = (t: string) => `${ESC}30m${t}${ESC}39m`

// ─── Bright Foreground ───────────────────────────────────────
export const brightRed = (t: string) => `${ESC}91m${t}${ESC}39m`
export const brightGreen = (t: string) => `${ESC}92m${t}${ESC}39m`
export const brightYellow = (t: string) => `${ESC}93m${t}${ESC}39m`
export const brightBlue = (t: string) => `${ESC}94m${t}${ESC}39m`
export const brightMagenta = (t: string) => `${ESC}95m${t}${ESC}39m`
export const brightCyan = (t: string) => `${ESC}96m${t}${ESC}39m`
export const brightWhite = (t: string) => `${ESC}97m${t}${ESC}39m`

// ─── Background Colors ──────────────────────────────────────
export const bgRed = (t: string) => `${ESC}41m${t}${ESC}49m`
export const bgGreen = (t: string) => `${ESC}42m${t}${ESC}49m`
export const bgYellow = (t: string) => `${ESC}43m${t}${ESC}49m`
export const bgBlue = (t: string) => `${ESC}44m${t}${ESC}49m`
export const bgMagenta = (t: string) => `${ESC}45m${t}${ESC}49m`
export const bgCyan = (t: string) => `${ESC}46m${t}${ESC}49m`
export const bgWhite = (t: string) => `${ESC}47m${t}${ESC}49m`
export const bgBlack = (t: string) => `${ESC}40m${t}${ESC}49m`

// ─── Style Modifiers ─────────────────────────────────────────
export const bold = (t: string) => `${ESC}1m${t}${ESC}22m`
export const dim = (t: string) => `${ESC}2m${t}${ESC}22m`
export const italic = (t: string) => `${ESC}3m${t}${ESC}23m`
export const underline = (t: string) => `${ESC}4m${t}${ESC}24m`

// ─── Advanced ────────────────────────────────────────────────
export function rgb(r: number, g: number, b: number, t: string): string {
  const clamp = (n: number) => Math.max(0, Math.min(255, Math.round(n)))
  return `${ESC}38;2;${clamp(r)};${clamp(g)};${clamp(b)}m${t}${ESC}39m`
}

export function bgRgb(r: number, g: number, b: number, t: string): string {
  const clamp = (n: number) => Math.max(0, Math.min(255, Math.round(n)))
  return `${ESC}48;2;${clamp(r)};${clamp(g)};${clamp(b)}m${t}${ESC}49m`
}

export function color256(n: number, t: string): string {
  const idx = Math.max(0, Math.min(255, Math.round(n)))
  return `${ESC}38;5;${idx}m${t}${ESC}39m`
}

// ─── Utility ─────────────────────────────────────────────────
const ANSI_RE = /\x1B\[[0-9;]*m/g
export const strip = (t: string) => t.replace(ANSI_RE, '')
