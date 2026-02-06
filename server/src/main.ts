import { lokiClient } from './modules/loki-client'
import { LogRequest } from './schema/log.request'

const srv = Bun.serve({
  port: 8080,
  routes: {
    '/health': {
      GET: () => new Response('ok'),
    },
    '/log': {
      POST: async (req) => {
        const body = await req.json()
        const logRequest = LogRequest.parse(body)

        await lokiClient.pushStructuredLog(
          {
            type: 'log_request',
            applicationName: logRequest.application?.name || '',
            applicationVersion: logRequest.application?.version || '',
            applicationSessionId: logRequest.application?.sessionId || '',
            severity: logRequest.severity,
            requestGeneratedAt: logRequest.request?.generatedAt || '',
            requestSentAt: logRequest.request?.sentAt || '',
          },
          {
            payload: logRequest.payload,
            exception: logRequest.exception,
          }
        )

        return new Response("ok")
      }
    }
  },
})