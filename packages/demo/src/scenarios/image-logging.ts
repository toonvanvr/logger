import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

/** Create a simple base64-encoded BMP (which Flutter can decode) of given size and color */
function createSimpleImage(width: number, height: number, color: string): string {
  // Create a BMP file in memory (Flutter can decode BMP)
  const rowSize = Math.ceil(width * 3 / 4) * 4
  const paddedDataSize = rowSize * height
  const fileSize = 54 + paddedDataSize
  const buf = new Uint8Array(fileSize)
  const view = new DataView(buf.buffer)

  // BMP header
  buf[0] = 0x42; buf[1] = 0x4D // 'BM'
  view.setUint32(2, fileSize, true) // file size
  view.setUint32(10, 54, true) // pixel data offset

  // DIB header (BITMAPINFOHEADER)
  view.setUint32(14, 40, true) // header size
  view.setInt32(18, width, true) // width
  view.setInt32(22, -height, true) // height (negative = top-down)
  view.setUint16(26, 1, true) // color planes
  view.setUint16(28, 24, true) // bits per pixel
  view.setUint32(34, paddedDataSize, true) // image size

  const colors: Record<string, [number, number, number]> = {
    red: [255, 60, 60],
    blue: [60, 100, 255],
    green: [80, 200, 120],
    cyan: [60, 200, 220],
    purple: [180, 100, 230],
    orange: [255, 165, 0],
  }
  const [r, g, b] = colors[color] ?? [200, 200, 200]

  // Write pixel data (BMP stores as BGR)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      // Add a subtle gradient
      const factor = (x + y) / (width + height)
      const offset = 54 + y * rowSize + x * 3
      buf[offset] = Math.round(b * (0.6 + 0.4 * factor)) // B
      buf[offset + 1] = Math.round(g * (0.6 + 0.4 * factor)) // G
      buf[offset + 2] = Math.round(r * (0.6 + 0.4 * factor)) // R
    }
  }

  return Buffer.from(buf).toString('base64')
}

export async function runImageLogging() {
  const logger = new Logger({ app: 'demo-images', transport: 'http' })

  try {
    logger.info('Demonstrating image logging capabilities')
    await delay(200)

    // Send a visible test image
    logger.info('Capturing UI screenshot of login page...')
    logger.image(createSimpleImage(32, 32, 'red'), 'image/bmp', { id: 'screenshot-login' })
    await delay(300)

    logger.info('Screenshot captured: dashboard overview')
    logger.image(createSimpleImage(32, 32, 'blue'), 'image/bmp', { id: 'screenshot-dashboard' })
    await delay(300)

    // Image with replaceable ID (simulating screenshot updates)
    logger.info('Live UI monitoring — screenshot updates every 500ms')
    for (let i = 0; i < 4; i++) {
      const color = i % 2 === 0 ? 'green' : 'cyan'
      logger.image(createSimpleImage(48, 8, color), 'image/bmp', { id: 'live-monitor' })
      await delay(500)
    }

    logger.info('Image logging demo complete')
    await logger.flush()
  } finally {
    await logger.close()
  }
}
