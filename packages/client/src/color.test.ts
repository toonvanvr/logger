import { describe, expect, it } from 'bun:test'
import { bgRed, bgRgb, bold, brightRed, color256, dim, gray, green, italic, red, rgb, strip, underline } from './color'

describe('color helpers', () => {
  it('wraps text with foreground ANSI codes', () => {
    expect(red('hello')).toBe('\x1B[31mhello\x1B[39m')
    expect(green('ok')).toBe('\x1B[32mok\x1B[39m')
    expect(gray('muted')).toBe('\x1B[90mmuted\x1B[39m')
  })

  it('wraps text with style modifiers', () => {
    expect(bold('strong')).toBe('\x1B[1mstrong\x1B[22m')
    expect(italic('em')).toBe('\x1B[3mem\x1B[23m')
    expect(underline('link')).toBe('\x1B[4mlink\x1B[24m')
    expect(dim('faint')).toBe('\x1B[2mfaint\x1B[22m')
  })

  it('supports nesting with per-attribute resets', () => {
    const nested = bold(red('error'))
    expect(nested).toBe('\x1B[1m\x1B[31merror\x1B[39m\x1B[22m')
    // Bold wraps red — red's 39m reset only clears fg, not bold
  })

  it('supports bright foreground variants', () => {
    expect(brightRed('alert')).toBe('\x1B[91malert\x1B[39m')
  })

  it('supports background colors', () => {
    expect(bgRed('highlight')).toBe('\x1B[41mhighlight\x1B[49m')
  })

  it('supports RGB colors', () => {
    const result = rgb(255, 128, 0, 'orange')
    expect(result).toBe('\x1B[38;2;255;128;0morange\x1B[39m')
  })

  it('clamps RGB values', () => {
    const result = rgb(-10, 300, 128, 'clamped')
    expect(result).toBe('\x1B[38;2;0;255;128mclamped\x1B[39m')
  })

  it('supports bgRgb', () => {
    expect(bgRgb(0, 0, 0, 'dark')).toBe('\x1B[48;2;0;0;0mdark\x1B[49m')
  })

  it('supports 256-color mode', () => {
    expect(color256(196, 'red256')).toBe('\x1B[38;5;196mred256\x1B[39m')
  })

  it('strips all ANSI codes', () => {
    expect(strip(bold(red('hello')))).toBe('hello')
    expect(strip('plain text')).toBe('plain text')
    expect(strip('')).toBe('')
  })

  it('handles empty text', () => {
    expect(red('')).toBe('\x1B[31m\x1B[39m')
  })
})
