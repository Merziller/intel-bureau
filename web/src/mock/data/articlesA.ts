/** v2 专题素材（一）：01~06。人名、群名均为虚构 */
import type { ArticleSpec } from './v2types'

export const ARTICLES_A: ArticleSpec[] = [
  {
    seeds: [0], title: 'Claude Code 子 Agent 并行开发：worktree 隔离 + 主 Agent 只做合并',
    background: [
      '「Claude Code 实战营」里老K 分享了一次夜间重构：给 6 个子 Agent 各开一个 git worktree，主 Agent 只负责拆任务和最后合并。40 个 TODO 一晚上清完，合并只冲突了 2 处。',
      '野生产品经理照着跑了下周会的 18 个需求单，结论是「需求之间耦合低时确实快」。讨论的焦点是怎么防止子 Agent 互相覆盖文件，Leo 给出的办法是在 CLAUDE.md 里写死目录范围。',
    ],
    prompts: [{ label: '子 Agent 的 CLAUDE.md 约束', who: 'Leo', group: 'Claude Code 实战营', use: '放在每个 worktree 根目录，限定子 Agent 的改动范围',
      text: '# 子 Agent 工作约束\n- 你只负责 {任务编号}，工作目录是当前 worktree，不要访问上级目录\n- 只能修改 src/{模块名}/ 下的文件；需要改其它模块时，写进 NOTES.md 交给主 Agent\n- 不要修改 package.json、lock 文件和 CI 配置\n- 每完成一个 TODO 提交一次，提交信息以 [{任务编号}] 开头\n- 结束前在 NOTES.md 写明：改了哪些文件、还剩什么、需要主 Agent 注意的冲突点' }],
    research: [
      'git worktree 允许同一个仓库同时检出多个分支到不同目录，各目录共享对象库，切换成本几乎为零 [1]。',
      'Claude Code 每次会话都会读取工作目录里的 CLAUDE.md，适合放项目约定和边界说明 [2]。',
      '多路并行的合并顺序建议按依赖关系排列，每合并一路就跑一次测试，冲突越早暴露越好处理 [3]。',
    ],
    conflict: '群里说「冲突很少」，前提是 TODO 之间相互独立；改动集中在同一批核心文件的重构，并行收益会明显下降。',
    refs: [{ title: 'git-worktree 官方手册', url: 'https://git-scm.com/docs/git-worktree' }, { title: 'Claude Code 概览', url: 'https://docs.anthropic.com/en/docs/claude-code/overview' },
      { title: '多 Agent 并行开发的合并顺序（示例博客）', url: 'https://example.com/blog/parallel-agents-merge' }],
    scope: ['适合：TODO 多、相互独立的清理和重构；需求单之间耦合低的迭代', '成本：6 路并行按群友自述约 3 小时完成 40 个 TODO（群友自述）', '数据：合并冲突 2 处 / 40 个 TODO（群友自述）'],
    images: ['m0101.png'], kb: { versions: 3 },
  },
  {
    seeds: [1, 12], title: 'AI 绘画角色一致性：先锁线稿再上色，本地可用 Flux + ControlNet',
    hook: '先固定线稿和设定词，再拿线稿当参考图上色；本地 12G 显存也能跑 1024',
    background: [
      '水彩手绘研习社 和 AI 出图研究所今天都在聊同一个问题：连续出图到第 5 张左右，发型和五官开始漂移。画画的阿木的办法是把一次出图拆成两步，先只出线稿并锁住角色设定词，再拿线稿做参考图上色，12 张下来五官基本没跑。',
      'ComfyUI 工作流研究群补充了本地版本：Flux fp8 加 ControlNet lineart，3060 12G 可以跑 1024，ControlNet 强度 0.6 左右最自然。',
    ],
    prompts: [
      { label: '第一步：只出线稿，锁定角色设定', who: '画画的阿木', group: '水彩手绘研习社', use: '整个系列复用同一段设定词，只改动作和场景',
        text: '角色设定（全程不变）：16 岁少女，圆脸，齐肩短发带一缕蓝色挑染，琥珀色眼睛，左眼下有泪痣；白色水手服，红色领结，黑色帆布鞋。\n画面：线稿，干净的黑色线条，无上色，无阴影，白底，全身像，三分之二侧面。\n动作：{本张的动作}' },
      { label: '第二步：ComfyUI 线稿上色参数', who: '十三', group: 'ComfyUI 工作流研究', use: '本地出图时的节点参数',
        text: 'model: flux1-dev-fp8\ncontrolnet: lineart, strength 0.6, start 0.0, end 0.8\nvae: Tiled VAE Decode, tile 512\nsize: 768x1024 → 放大到 1024x1365\nsampler: euler, steps 24, cfg 3.5' },
    ],
    research: [
      'ControlNet 通过额外的条件输入（如线稿、边缘图）约束生成结构，正适合「先定形再上色」的做法 [1]。',
      'Flux 的 fp8 权重把显存占用降到约一半，配合分块 VAE 解码，12G 显卡可以出 1024 分辨率 [2]。',
      '保持角色一致的其它常见做法还有角色 LoRA 和参考图注入，但前者要训练、后者对服装细节保持较弱 [3]。',
    ],
    conflict: '群里说强度 0.6 最自然，公开教程多推荐 0.5~0.8；线稿越干净，可用的强度越高，建议按自己的线稿实测。',
    refs: [{ title: 'ControlNet 论文：Adding Conditional Control to Text-to-Image Diffusion Models', url: 'https://arxiv.org/abs/2302.05543' },
      { title: 'ComfyUI 官方仓库', url: 'https://github.com/comfyanonymous/ComfyUI' }, { title: '角色一致性方法对比（示例博客）', url: 'https://example.com/blog/character-consistency' }],
    scope: ['适合：连载漫画、绘本、系列插画', '本地：3060 12G 可跑 1024（群友实测）；云端：即梦、Midjourney 同样适用两步法', '数据：连续 12 张五官基本一致（群友自述）'],
    images: ['m0201.png'], kb: { versions: 4 },
  },
  {
    seeds: [2], title: 'Nano Banana 多图融合：提示词里逐张点名用途',
    background: [
      '阿青在 AI 出图研究所分享：多图融合时在提示词里写清「图1 的人物、图2 的衣服、图3 的场景」，10 次能成 8 次；直接说「参考这些图」时，经常把场景图里的路人也融进来。',
      '桃子已经拿它做小红书换装穿搭图。苏苏补充：失败时先减到两张图，排查是哪一张在干扰。',
    ],
    prompts: [{ label: '多图融合点名模板', who: '阿青', group: 'AI 出图研究所', use: '小红书换装穿搭图',
      text: '图1 的人物穿上图2 的服装，站在图3 的场景里。\n保持图1 人物的脸型、发型和肤色不变；服装只取图2 的款式和颜色，不要图2 里的模特。\n光线：右侧窗光，傍晚暖色。镜头：50mm，半身，平视。' }],
    research: [
      '官方文档建议多图输入时在提示词里明确每张图的角色，并说明要保留和要替换的元素 [1]。',
      '逐张减图的排查法能快速定位干扰源：先保留人物 + 服装两张，稳定后再加场景 [2]。',
    ],
    refs: [{ title: 'Gemini 图像生成文档', url: 'https://ai.google.dev/gemini-api/docs/image-generation' }, { title: '多图融合排查清单（示例博客）', url: 'https://example.com/blog/multi-image-fusion' }],
    scope: ['适合：换装、产品图换背景、人物合成', '数据：10 次成 8 次（群友自测）'],
    images: ['m0301.png'], kb: { versions: 1, isNew: true },
  },
  {
    seeds: [5], title: 'TikTok 竖屏短剧：开头 3 秒冲突前置，完播率 18% → 31%',
    background: [
      '短剧出海交流群的短剧老炮把全集冲突最强的「扇耳光」那场戏挪到开头 3 秒，再用一句字幕「三天前」倒叙交代。同一集做 A/B，完播率从 18% 拉到 31%。',
      '数据狗补充了实验条件：两版各投放 48 小时，样本量都过了 2 万。代价是节奏要更紧，第 10 秒内必须回到主线，否则观众会迷失。',
    ],
    prompts: [{ label: '开头重排的剪辑说明', who: '短剧老炮', group: '短剧出海交流', use: '交给剪辑师的改版要求',
      text: '0:00-0:03  全集冲突最强的镜头（不超过 3 秒，保留原声）\n0:03-0:04  黑场 + 字幕「3 days earlier」\n0:04-0:10  回到第一场戏，台词压缩到 2 句\n0:10 起    按原顺序，删掉与主线无关的过场' }],
    research: [
      'TikTok 官方创作者指南把开头几秒的「钩子」列为完播率的首要因素 [1]。',
      '倒叙开头在国内短剧已经是常规手法，出海版本的主要差别在字幕本地化：时间跳转要用目标语言的惯用表达 [2]。',
    ],
    conflict: '群里的 13 个百分点提升来自单集测试；公开案例里同类改版的提升多在 5~10 个百分点，题材差异很大。',
    refs: [{ title: 'TikTok Creator Academy', url: 'https://www.tiktok.com/creator-academy' }, { title: '短剧出海字幕本地化要点（示例博客）', url: 'https://example.com/blog/drama-localization' }],
    scope: ['适合：有明显冲突戏的剧情短剧；慢热的情感向效果待验证', '数据：完播率 18% → 31%，各 48 小时、样本 2 万+（群友自述，非平台口径）'],
    images: ['m0401.png'], kb: { versions: 2 },
  },
  {
    seeds: [4], title: '可灵运镜提示词三段式：镜头 / 节奏 / 主体动作分开写',
    background: [
      '短剧老炮发现，运镜和人物动作写在一句里，模型经常两个都做不好。拆成三句分别写镜头怎么动、多快、主体做什么，镜头就听话多了。',
      'Kevin 拿同一张图各跑 5 次对比，三段式那组的镜头基本都按要求走。',
    ],
    prompts: [{ label: '三段式运镜模板', who: '短剧老炮', group: '短剧出海交流', use: '图生视频的提示词',
      text: '镜头：缓慢推近，从全景推到中景。\n节奏：前 2 秒静止，之后匀速推进，最后 1 秒停住。\n主体：女孩转身看向镜头，头发被风吹起，表情从惊讶到微笑。' }],
    research: [
      '可灵官方提示词指南同样建议把镜头语言和主体动作分开描述，并用「缓慢 / 快速」控制节奏 [1]。',
      '一次只改一句做对比，是社区里公认的调参方法，能定位是哪一句没生效 [2]。',
    ],
    refs: [{ title: '可灵 AI', url: 'https://klingai.com/' }, { title: '图生视频提示词结构（示例博客）', url: 'https://example.com/blog/i2v-prompt' }],
    scope: ['适合：图生视频、短剧分镜预览', '数据：同图 5 次对比，三段式镜头稳定度明显更高（群友实测）'],
    images: ['m0501.png'], kb: { versions: 2 },
  },
  {
    seeds: [24], title: 'Claude Code hooks：改完自动跑 lint 和测试，失败回传给 Agent',
    background: [
      'Leo 给编辑类工具配了执行后 hook：改完代码自动跑 lint 和相关测试，挂了就把错误输出回给 Agent，它会自己去修。',
      '老K 的提醒是：测试慢的项目只跑和改动相关的用例，不然每次编辑都要等很久。',
    ],
    prompts: [{ label: 'PostToolUse hook 配置', who: 'Leo', group: 'Claude Code 实战营', use: '.claude/settings.json',
      text: '{\n  "hooks": {\n    "PostToolUse": [\n      {\n        "matcher": "Edit|Write",\n        "hooks": [{ "type": "command", "command": "npm run lint --silent && npx vitest related --run $CLAUDE_FILE_PATHS" }]\n      }\n    ]\n  }\n}' }],
    research: [
      'PostToolUse hook 在工具调用成功后执行，可以按工具名匹配；命令非零退出时，输出会反馈给 Claude [1]。',
      '按改动筛选测试可以用测试框架自带的 related / changed 模式，避免每次全量运行 [2]。',
    ],
    refs: [{ title: 'Claude Code hooks 文档', url: 'https://docs.anthropic.com/en/docs/claude-code/hooks' }, { title: 'Vitest CLI：related', url: 'https://vitest.dev/guide/cli' }],
    scope: ['适合：有 lint 和单测的项目', '注意：hook 命令在本机执行，只放你信任的命令'],
    kb: { versions: 2 },
  },
]
