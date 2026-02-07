import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

// Minimal 1x1 red pixel PNG (base64-encoded)
const RED_PIXEL_PNG =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='

// Minimal 1x1 blue pixel PNG (base64-encoded)
const BLUE_PIXEL_PNG =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPj/HwADBwIAMCbHYQAAAABJRU5ErkJggg=='

export async function runImageLogging() {
  const logger = new Logger({ app: 'demo-images', transport: 'http' })

  try {
    logger.info('Demonstrating image logging capabilities')
    await delay(200)

    // Send a small test image
    logger.info('Sending 1x1 red pixel PNG')
    logger.image(RED_PIXEL_PNG, 'image/png')
    await delay(300)

    // Send another test image
    logger.info('Sending 1x1 blue pixel PNG')
    logger.image(BLUE_PIXEL_PNG, 'image/png')
    await delay(300)

    // Image with replaceable ID (simulating screenshot updates)
    logger.info('Simulating periodic screenshot capture (updating in-place)')
    logger.image(RED_PIXEL_PNG, 'image/png', { id: 'live-screenshot' })
    await delay(500)
    logger.image(BLUE_PIXEL_PNG, 'image/png', { id: 'live-screenshot' })
    await delay(500)
    logger.image(RED_PIXEL_PNG, 'image/png', { id: 'live-screenshot' })
    await delay(200)

    logger.info('Image logging demo complete')
    logger.info('Note: real screenshots would require platform-specific APIs')

    await logger.flush()
  } finally {
    await logger.close()
  }
}
