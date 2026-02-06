export class LokiClient {
  private lokiUrl: string

  constructor(lokiUrl?: string) {
    this.lokiUrl = lokiUrl || process.env.LOKI_URL || 'http://localhost:3100'
  }

  async pushLog(labels: Record<string, string>, line: string, timestamp?: number) {
    const ts = timestamp || Date.now()
    const payload = {
      streams: [
        {
          stream: labels,
          values: [[`${ts}000000`, line]] // Loki expects nanoseconds
        }
      ]
    }

    try {
      const response = await fetch(`${this.lokiUrl}/loki/api/v1/push`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      })

      if (!response.ok) {
        console.error(`Failed to push log to Loki: ${response.status} ${response.statusText}`)
      }
    } catch (error) {
      console.error('Error pushing log to Loki:', error)
    }
  }

  async pushStructuredLog(labels: Record<string, string>, data: any, timestamp?: number) {
    const line = JSON.stringify(data)
    await this.pushLog(labels, line, timestamp)
  }
}

export const lokiClient = new LokiClient()
