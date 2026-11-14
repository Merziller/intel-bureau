import type { Platform } from '@/api/types'

export interface GroupSeed {
  id: string; platform: Platform; native: string; name: string; members: number
  whitelisted: boolean; weight: number; tags: string[]; m24: number; speakers: number
}

/** 白名单 9 个群（微信 4、QQ 3、飞书 2）+ 未加入白名单的几个群（只在群表格里出现，不采集） */
export const GROUP_SEEDS: GroupSeed[] = [
  { id: 'sh8', platform: 'wechat', native: '48151623421@chatroom', name: '水彩手绘研习社', members: 412, whitelisted: true, weight: 1.2, tags: ['AI 绘画', '核心'], m24: 486, speakers: 71 },
  { id: 'aiimg', platform: 'wechat', native: '23905561870@chatroom', name: 'AI 出图研究所', members: 498, whitelisted: true, weight: 1.0, tags: ['AI 绘画', '提示词'], m24: 412, speakers: 64 },
  { id: 'side', platform: 'wechat', native: '19288473305@chatroom', name: 'AI 副业互助会', members: 476, whitelisted: true, weight: 0.8, tags: ['变现'], m24: 338, speakers: 58 },
  { id: 'xhs', platform: 'wechat', native: '30716645902@chatroom', name: '小红书起号营', members: 365, whitelisted: true, weight: 1.0, tags: ['小红书', '起号'], m24: 254, speakers: 47 },
  { id: 'cc', platform: 'qq', native: '738204615', name: 'Claude Code 实战营', members: 1862, whitelisted: true, weight: 1.5, tags: ['编程', '核心'], m24: 523, speakers: 82 },
  { id: 'drama', platform: 'qq', native: '615930284', name: '短剧出海交流', members: 1240, whitelisted: true, weight: 1.1, tags: ['短剧', '出海'], m24: 361, speakers: 49 },
  { id: 'comfy', platform: 'qq', native: '852117306', name: 'ComfyUI 工作流研究', members: 2000, whitelisted: true, weight: 0.9, tags: ['开源', 'AI 绘画'], m24: 197, speakers: 33 },
  { id: 'growth', platform: 'feishu', native: 'oc_5f2a9c71e0d84b6aa3c1d9e07b4f6a21', name: '飞书 · 增长小组', members: 86, whitelisted: true, weight: 1.3, tags: ['工作', '增长'], m24: 203, speakers: 24 },
  { id: 'content', platform: 'feishu', native: 'oc_9b04e3d2c6a14f7d8e5b2a1c0f9d3e77', name: '飞书 · 内容中台', members: 54, whitelisted: true, weight: 1.0, tags: ['工作', '内容'], m24: 112, speakers: 17 },
  // 未加入白名单
  { id: 'fam', platform: 'wechat', native: '27719053318@chatroom', name: '相亲相爱一家人', members: 23, whitelisted: false, weight: 1, tags: [], m24: 0, speakers: 0 },
  { id: 'estate', platform: 'wechat', native: '20361178840@chatroom', name: '小区业主 3 期', members: 488, whitelisted: false, weight: 1, tags: [], m24: 0, speakers: 0 },
  { id: 'game', platform: 'qq', native: '470118923', name: '周末开黑小分队', members: 156, whitelisted: false, weight: 1, tags: [], m24: 0, speakers: 0 },
  { id: 'cet', platform: 'qq', native: '306554218', name: '英语四六级备考', members: 1534, whitelisted: false, weight: 1, tags: [], m24: 0, speakers: 0 },
  { id: 'allhands', platform: 'feishu', native: 'oc_1d7c3a90b2e64f5c8a7d6e3b9c0f2a14', name: '飞书 · 全员通知', members: 312, whitelisted: false, weight: 1, tags: [], m24: 0, speakers: 0 },
]

export const groupById = (id: string): GroupSeed => GROUP_SEEDS.find((g) => g.id === id)!
export const groupKey = (g: GroupSeed): string => `${g.platform}:${g.native}`
export const WHITELIST = GROUP_SEEDS.filter((g) => g.whitelisted)

export const SPEAKERS = ['老K', 'Leo', '张工', '阿青', '小鹿酱', '一只猫', '墨白', '木子', 'Ryan', '橙子', '大飞', '陈同学', '沐沐', '老周',
  '阿杰', '七七', 'Kevin', '桃子', '北辰', '程序员小王', '苏苏', '安迪', '鱼丸', '十三', '画画的阿木', '短剧老炮', '运营喵', '数据狗', '野生产品经理']

export const CATEGORIES: Record<string, string> = {
  '01': '01 工具与资源', '02': '02 提示词与工作流', '03': '03 AI 创作实战', '04': '04 流量与变现', '05': '05 编程与自动化',
  '06': '06 模型与平台动态', '07': '07 需求与机会', '08': '08 风险与避坑', '99': '99 其他',
}

export const INTERESTS = ['AI 绘画', '提示词', 'Skill', 'Agent', 'Claude Code', 'Codex', '视频生成', '漫画', '起号', '变现',
  '公众号', '小红书', '视频号', '开源', '自动化', '工作流']
