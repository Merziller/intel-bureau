import type { Trend } from '@/api/types'

/** 一条情报的手写素材；build.ts 补齐 id、证据时间、来源计数、评分等 */
export interface IntelSeed {
  short: string                      // 星图话题节点名
  title: string
  hook: string
  summary: string
  cat: string                        // 分类代码 01..08
  kind: string
  groups: string[]                   // 来源群 id，第一个是主来源
  steps: string[]
  tools: string[]
  links?: { url: string; title?: string }[]
  ev: [string, string][]             // [发言人, 原文]
  sc: [number, number, number]       // novelty, actionability, credibility（0~5）
  heat: number                       // 0~5
  risk?: string[]
  tags: string[]
  trend: Trend
}
