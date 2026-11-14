/** v2 mock 素材的类型：专题文章、资源、分群摘要（全部虚构） */
import type { ResourceKind } from '@/api/types'

export interface PromptSpec { label: string; text: string; who: string; group: string; use: string }

export interface ArticleSpec {
  /** IntelSeed 下标；第一个是主素材（证据、步骤、工具、分类取自它） */
  seeds: number[]
  title?: string
  hook?: string
  cat?: string
  background: string[]
  prompts?: PromptSpec[]
  steps?: string[]
  /** 扩展研究：每条结论后标 [n] */
  research: string[]
  /** 与群内说法冲突时写明 */
  conflict?: string
  refs: { title: string; url: string }[]
  scope: string[]
  /** 风险说明（风险标签来自 items.V2_RISK 或素材） */
  riskNote?: string
  images?: string[]
  /** 知识库：版本数；isNew 表示今天新建 */
  kb: { versions: number; isNew?: boolean }
}

export interface ResourceSpec {
  kind: ResourceKind; title: string; url: string; code?: string; meta?: Record<string, unknown>; note?: string
  who: string; group: string; hoursAgo: number
}

export interface DigestSpec { group: string; summary: string; highlights: string[]; counts: [links: number, prompts: number, sops: number, data: number] }
