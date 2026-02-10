/**
 * Docker Log Sidecar — shared type definitions.
 */

import type { Logger } from '@logger/client'

export interface ContainerEvent {
  Action: string
  id: string
  Actor?: { Attributes?: Record<string, string> }
}

export interface ContainerInfo {
  Id: string
  Names: string[]
  Labels: Record<string, string>
  State: string
}

export interface TrackedContainer {
  logger: Logger
  abort: AbortController
}
