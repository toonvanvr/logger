import { z } from 'zod';

// ─── TreeNode (recursive) ────────────────────────────────────────────

export interface TreeNode {
  label: string;
  icon?: string;
  meta?: string;
  color?: string;
  children?: TreeNode[];
  expanded?: boolean;
}

export const TreeNodeSchema: z.ZodType<TreeNode> = z.object({
  label: z.string().max(256),
  icon: z.string().optional(),
  meta: z.string().max(256).optional(),
  color: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/)
    .optional(),
  children: z
    .lazy(() => z.array(TreeNodeSchema).max(500))
    .optional(),
  expanded: z.boolean().optional(),
});

// ─── Individual Custom Renderer Schemas ──────────────────────────────

export const TableRendererData = z.object({
  custom_type: z.literal('table'),
  custom_data: z.object({
    columns: z.array(z.string()).min(1).max(100),
    rows: z
      .array(z.array(z.union([z.string(), z.number(), z.boolean(), z.null()])))
      .max(10000),
    highlight_column: z.number().int().min(0).optional(),
    sortable: z.boolean().optional(),
    caption: z.string().max(256).optional(),
  }),
});

export const ProgressRendererData = z.object({
  custom_type: z.literal('progress'),
  custom_data: z.object({
    value: z.number(),
    max: z.number().optional(),
    label: z.string().max(256).optional(),
    sublabel: z.string().max(256).optional(),
    color: z
      .string()
      .regex(/^#[0-9a-fA-F]{6}$/)
      .optional(),
    style: z.enum(['bar', 'ring']).optional(),
  }),
});

export const KvRendererData = z.object({
  custom_type: z.literal('kv'),
  custom_data: z.object({
    entries: z
      .array(
        z.object({
          key: z.string().max(128),
          value: z.union([z.string(), z.number(), z.boolean()]),
          icon: z.string().optional(),
          color: z
            .string()
            .regex(/^#[0-9a-fA-F]{6}$/)
            .optional(),
        }),
      )
      .min(1)
      .max(50),
    layout: z.enum(['inline', 'stacked']).optional(),
  }),
});

export const ChartRendererData = z.object({
  custom_type: z.literal('chart'),
  custom_data: z.object({
    type: z.enum(['sparkline', 'bar', 'area', 'dense_bar']),
    values: z.array(z.number()).min(2).max(1000),
    labels: z.array(z.string()).optional(),
    color: z
      .string()
      .regex(/^#[0-9a-fA-F]{6}$/)
      .optional(),
    height: z.number().int().min(24).max(200).optional(),
    min: z.number().optional(),
    max: z.number().optional(),
    title: z.string().max(256).optional(),
  }),
});

export const DiffRendererData = z.object({
  custom_type: z.literal('diff'),
  custom_data: z.object({
    before: z.string().max(10000),
    after: z.string().max(10000),
    language: z.enum(['json', 'yaml', 'sql', 'text']).optional(),
    context_lines: z.number().int().min(0).max(20).optional(),
  }),
});

export const TreeRendererData = z.object({
  custom_type: z.literal('tree'),
  custom_data: z.object({
    root: TreeNodeSchema,
    default_expanded_depth: z.number().int().min(0).max(10).optional(),
  }),
});

export const TimelineRendererData = z.object({
  custom_type: z.literal('timeline'),
  custom_data: z.object({
    events: z
      .array(
        z.object({
          label: z.string().max(256),
          time: z.string().datetime({ offset: true }),
          duration_ms: z.number().min(0).optional(),
          color: z
            .string()
            .regex(/^#[0-9a-fA-F]{6}$/)
            .optional(),
          icon: z.string().optional(),
          meta: z.string().max(256).optional(),
        }),
      )
      .min(1)
      .max(200),
    show_duration: z.boolean().optional(),
    total_label: z.string().max(256).optional(),
  }),
});

export const HttpRequestRendererData = z.object({
  custom_type: z.literal('http_request'),
  custom_data: z.object({
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
    started_at: z.string(),
    duration_ms: z.number().optional(),
    ttfb_ms: z.number().optional(),
    request_id: z.string().optional(),
    content_type: z.string().optional(),
    is_error: z.boolean().optional(),
  }),
});

// ─── Discriminated Union ─────────────────────────────────────────────

export const CustomRendererData = z.discriminatedUnion('custom_type', [
  TableRendererData,
  ProgressRendererData,
  KvRendererData,
  ChartRendererData,
  DiffRendererData,
  TreeRendererData,
  TimelineRendererData,
  HttpRequestRendererData,
]);
export type CustomRendererData = z.infer<typeof CustomRendererData>;
