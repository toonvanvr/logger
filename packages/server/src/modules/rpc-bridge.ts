// ─── Types ───────────────────────────────────────────────────────────

/** Outbound WebSocket message. */
type ServerMessage = Record<string, unknown>

export interface RpcToolInfo {
  name: string
  description: string
  category: 'getter' | 'tool'
  argsSchema?: Record<string, unknown>
  confirm?: boolean
}

export interface RpcRequest {
  rpcId: string
  targetSessionId: string
  method: string
  args: unknown
  viewerWs: { send(data: string): void }
}

interface PendingRequest {
  viewerWs: { send(data: string): void }
  timer: Timer
  resolve: () => void
}

// ─── RPC Bridge ──────────────────────────────────────────────────────

export class RpcBridge {
  private tools = new Map<string, RpcToolInfo[]>();
  private pending = new Map<string, PendingRequest>();
  private clientSender: ((sessionId: string, message: ServerMessage) => void) | null = null;
  private readonly timeoutMs: number

  constructor(options?: { timeoutMs?: number }) {
    this.timeoutMs = options?.timeoutMs ?? 30_000
  }

  /** Set the function used to route messages to client sessions. */
  setClientSender(fn: (sessionId: string, message: ServerMessage) => void): void {
    this.clientSender = fn
  }

  /** Register a client's available RPC tools. */
  registerTools(sessionId: string, tools: RpcToolInfo[]): void {
    this.tools.set(sessionId, tools)
  }

  /** Get available tools for a session. */
  getTools(sessionId: string): RpcToolInfo[] {
    return this.tools.get(sessionId) ?? []
  }

  /** Get all tools across all sessions. */
  getAllTools(): Map<string, RpcToolInfo[]> {
    return new Map(this.tools)
  }

  /**
   * Handle incoming RPC request from viewer.
   * Routes to the target client session and waits for response or timeout.
   */
  async handleRequest(request: RpcRequest): Promise<void> {
    const { rpcId, targetSessionId, method, args, viewerWs } = request

    // Check if session has registered tools
    const sessionTools = this.tools.get(targetSessionId)
    if (!sessionTools) {
      this.sendErrorToViewer(viewerWs, rpcId, `Session "${targetSessionId}" not found`)
      return
    }

    // Check if the requested method exists
    const tool = sessionTools.find((t) => t.name === method)
    if (!tool) {
      this.sendErrorToViewer(viewerWs, rpcId, `Unknown method "${method}" on session "${targetSessionId}"`)
      return
    }

    if (!this.clientSender) {
      this.sendErrorToViewer(viewerWs, rpcId, 'No client sender configured')
      return
    }

    // Create pending request with timeout
    return new Promise<void>((resolve) => {
      const timer = setTimeout(() => {
        this.pending.delete(rpcId)
        this.sendErrorToViewer(viewerWs, rpcId, `RPC timeout after ${this.timeoutMs}ms`)
        resolve()
      }, this.timeoutMs)

      this.pending.set(rpcId, { viewerWs, timer, resolve })

      // Forward request to client
      this.clientSender!(targetSessionId, {
        type: 'rpc_request',
        rpc_id: rpcId,
        method,
        args,
      })
    })
  }

  /** Handle incoming RPC response from client. */
  handleResponse(response: { rpcId: string; data?: unknown; error?: string }): void {
    const entry = this.pending.get(response.rpcId)
    if (!entry) return

    clearTimeout(entry.timer)
    this.pending.delete(response.rpcId)

    if (response.error) {
      this.sendErrorToViewer(entry.viewerWs, response.rpcId, response.error)
    } else {
      const msg: ServerMessage = {
        type: 'rpc_response',
        rpc_id: response.rpcId,
        result: response.data,
      }
      entry.viewerWs.send(JSON.stringify(msg))
    }

    entry.resolve()
  }

  /** Unregister all tools and cancel pending requests for a session. */
  unregisterSession(sessionId: string): void {
    this.tools.delete(sessionId)
  }

  /** Get the number of pending requests (for diagnostics). */
  getPendingCount(): number {
    return this.pending.size
  }

  /** Clear all pending RPC timers and requests. */
  shutdown(): void {
    for (const [, entry] of this.pending) {
      clearTimeout(entry.timer)
    }
    this.pending.clear()
  }

  // ─── Internals ───────────────────────────────────────────────────

  private sendErrorToViewer(ws: { send(data: string): void }, rpcId: string, error: string): void {
    const msg: ServerMessage = {
      type: 'rpc_response',
      rpc_id: rpcId,
      error,
    }
    ws.send(JSON.stringify(msg))
  }
}
