import { LogRequest } from './schema/log.request'
import { SessionRequest } from './schema/session.request'

Bun.serve({
  routes: {
    '/session': {
      POST: async (req) => {
        // TODO: error handling etc
        const body = await req.json()
        const sessionRequest = SessionRequest.parse(body)
        console.log(sessionRequest)
        return new Response(JSON.stringify({
          sessionId: crypto.randomUUID(),
        }))
      }
    },
    '/log': {
      POST: async (req) => {
        const body = await req.json()
        const logRequest = LogRequest.parse(body)
        console.log(logRequest)
        return new Response("ok")
      }
    }
  },
  port: 8080,
})