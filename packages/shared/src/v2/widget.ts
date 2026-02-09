import { z } from 'zod'
import { MAX_TEXT_SIZE } from '../constants.js'

// ─── TreeNode (recursive) ────────────────────────────────────────────

export interface TreeNode {
  label: string
  icon?: string
  meta?: string
  color?: string
  children?: TreeNode[]
  expanded?: boolean
}

export const TreeNodeSchema: z.ZodType<TreeNode> = z.object({
  label: z.string().max(256),
  icon: z.string().optional(),
  meta: z.string().max(256).optional(),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  children: z.lazy(() => z.array(TreeNodeSchema).max(500)).optional(),
  expanded: z.boolean().optional(),
})

// ─── Content Widgets ─────────────────────────────────────────────────

const JsonWidget = z.object({
  type: z.literal('json'),
  data: z.unknown(),
}).passthrough()

const HtmlWidget = z.object({
  type: z.literal('html'),
  content: z.string().max(MAX_TEXT_SIZE),
}).passthrough()

const BinaryWidget = z.object({
  type: z.literal('binary'),
  data: z.string(),
  encoding: z.literal('base64'),
}).passthrough()

const ImageWidget = z.object({
  type: z.literal('image'),
  data: z.string().optional(),
  ref: z.string().optional(),
  mime_type: z.string().optional(),
  label: z.string().optional(),
  width: z.number().int().optional(),
  height: z.number().int().optional(),
}).passthrough()

// ─── Rich Widgets ────────────────────────────────────────────────────

const TableWidget = z.object({
  type: z.literal('table'),
  columns: z.array(z.string()).min(1).max(100),
  rows: z.array(z.array(z.union([z.string(), z.number(), z.boolean(), z.null()]))).max(10000),
  highlight_column: z.number().int().min(0).optional(),
  sortable: z.boolean().optional(),
  caption: z.string().max(256).optional(),
}).passthrough()

const ProgressWidget = z.object({
  type: z.literal('progress'),
  value: z.number(),
  max: z.number().optional(),
  label: z.string().max(256).optional(),
  sublabel: z.string().max(256).optional(),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  style: z.enum(['bar', 'ring']).optional(),
}).passthrough()

const KvWidget = z.object({
  type: z.literal('kv'),
  entries: z.array(z.object({
    key: z.string().max(128),
    value: z.union([z.string(), z.number(), z.boolean()]),
    icon: z.string().optional(),
    color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  })).min(1).max(50),
  layout: z.enum(['inline', 'stacked']).optional(),
}).passthrough()

const ChartWidget = z.object({
  type: z.literal('chart'),
  chart_type: z.enum(['sparkline', 'bar', 'area', 'dense_bar']),
  values: z.array(z.number()).max(1000).optional().describe('Optional — may be accumulated from data pushes'),
  labels: z.array(z.string()).optional(),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  height: z.number().int().min(24).max(200).optional(),
  min: z.number().optional(),
  max: z.number().optional(),
  title: z.string().max(256).optional(),
}).passthrough()

const DiffWidget = z.object({
  type: z.literal('diff'),
  before: z.string().max(10000),
  after: z.string().max(10000),
  language: z.enum(['json', 'yaml', 'sql', 'text']).optional(),
  context_lines: z.number().int().min(0).max(20).optional(),
}).passthrough()

const TreeWidget = z.object({
  type: z.literal('tree'),
  root: TreeNodeSchema,
  default_expanded_depth: z.number().int().min(0).max(10).optional(),
}).passthrough()

const TimelineWidget = z.object({
  type: z.literal('timeline'),
  events: z.array(z.object({
    label: z.string().max(256),
    time: z.string().datetime({ offset: true }),
    duration_ms: z.number().min(0).optional(),
    color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
    icon: z.string().optional(),
    meta: z.string().max(256).optional(),
  })).min(1).max(200),
  show_duration: z.boolean().optional(),
  total_label: z.string().max(256).optional(),
}).passthrough()

const HttpRequestWidget = z.object({
  type: z.literal('http_request'),
  method: z.string(),
  url: z.string(),
  request_headers: z.record(z.string()).optional(),
  request_body: z.string().optional(),
  request_body_size: z.number().optional(),
  status: z.number().optional(),
  status_text: z.string().optional(),
  response_headers: z.record(z.string()).optional(),
  response_body: z.string().optional(),
  response_body_size: z.number().optional(),
  started_at: z.string().optional(),
  duration_ms: z.number().optional(),
  ttfb_ms: z.number().optional(),
  request_id: z.string().optional(),
  content_type: z.string().optional(),
  is_error: z.boolean().optional(),
}).passthrough()

// ─── WidgetPayload (discriminated union) ─────────────────────────────

export const WidgetPayload = z.discriminatedUnion('type', [
  JsonWidget,
  HtmlWidget,
  BinaryWidget,
  ImageWidget,
  TableWidget,
  ProgressWidget,
  KvWidget,
  ChartWidget,
  DiffWidget,
  TreeWidget,
  TimelineWidget,
  HttpRequestWidget,
])
export type WidgetPayload = z.infer<typeof WidgetPayload>
