import { type LogRequest } from '../../server/src/schema/log.request'

setInterval(() => {
  const logRequest: LogRequest = {
    application: {
      name: 'demo-app',
      version: '1.0.0',
      sessionId: 'abc123',
    },
    severity: 'info',
    request: {
      generatedAt: new Date().toISOString(),
      sentAt: new Date().toISOString(),
    },
    payload: {
      message: 'Hello, Loki!',
      timestamp: new Date().toISOString(),
    },
  }

  fetch(`${process.env.SERVER_URL}/log`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(logRequest),
  }).then((response) => {
    console.log('Log sent, response status:', response.status)
  }).catch((error) => {
    console.error('Error sending log:', error)
  })
}, 5000)