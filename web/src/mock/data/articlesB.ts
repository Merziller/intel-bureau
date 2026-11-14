/** v2 专题素材（二）：07~12。含 4 篇带风险标签的专题（风险内容照常扩展，只加标注和免责声明） */
import type { ArticleSpec } from './v2types'

export const ARTICLES_B: ArticleSpec[] = [
  {
    seeds: [6], title: '短剧字幕本地化流水线：Whisper 转写 + 大模型翻译，西语版每集约 3 元',
    background: [
      'Kevin 的流水线分三步：Whisper 转写原声导出 SRT，大模型按「口语化、保留人名」翻成西语，人工只校对专有名词和双关语。',
      '阿杰补充：翻译提示词里一定要写「保留人名」，否则每集的人名译法都不一样。',
    ],
    prompts: [{ label: '字幕翻译提示词', who: 'Kevin', group: '短剧出海交流', use: '每 40 行一批交给模型',
      text: '把下面的 SRT 字幕翻译成拉美西班牙语。\n要求：口语化，像真人对白；人名、地名保持原样不翻译；保留时间轴和序号；每行不超过 42 个字符，超过就拆成两行。\n只输出 SRT，不要解释。' }],
    research: [
      'Whisper large-v3 支持多语种转写并可直接输出 SRT 时间轴 [1]。',
      '主流流媒体字幕规范把每行限制在 42 字符左右、每屏两行，翻译时要一并约束 [2]。',
    ],
    conflict: '群里说单集约 3 元；按公开定价估算，40 分钟的剧只算模型费用约 1~3 元，人工校对时间另计。',
    refs: [{ title: 'openai/whisper', url: 'https://github.com/openai/whisper' }, { title: 'Netflix 字幕规范', url: 'https://partnerhelp.netflixstudios.com/hc/en-us/articles/217350977' }],
    scope: ['适合：有原声对白的短剧、口播视频', '成本：西语版每集约 3 元，交付周期从 3 天缩到半天（群友自述）'],
    images: ['m0701.png'], kb: { versions: 1, isNew: true },
  },
  {
    seeds: [16], title: 'n8n「选题 → 脚本 → 配图」流水线：每天自动产出 5 套草稿',
    background: [
      'Ryan 在飞书 · 增长小组展示了自己的 n8n 流水线：每天 7 点触发，抓热点关键词交给大模型出 5 个选题，再为每个选题生成口播脚本和 3 张配图提示词，结果写回飞书多维表格待审核。',
      '橙子的经验是配图提示词单独一个节点，效果比和脚本一起生成好。',
    ],
    prompts: [{ label: '选题节点的提示词', who: 'Ryan', group: '飞书 · 增长小组', use: 'n8n 的大模型节点',
      text: '你是短视频选题编辑。根据下面的热点关键词，给出 5 个选题。\n每个选题包含：标题（不超过 20 字）、目标人群、核心痛点、开头第一句话。\n输出 JSON 数组，字段 title / audience / pain / hook。\n热点关键词：{{ $json.keywords }}' },
      { label: '流水线节点清单（工作流 JSON 摘录）', who: 'Ryan', group: '飞书 · 增长小组', use: '导入 n8n 前对照节点顺序',
        text: '{\n  "name": "daily-content-drafts",\n  "nodes": [\n    { "name": "每天 07:00", "type": "n8n-nodes-base.scheduleTrigger", "parameters": { "rule": { "cronExpression": "0 7 * * *" } } },\n    { "name": "抓热点关键词", "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "{{ $env.HOT_API }}", "method": "GET" } },\n    { "name": "生成 5 个选题", "type": "@n8n/n8n-nodes-langchain.lmChatOpenAi", "parameters": { "model": "deepseek-chat", "temperature": 0.7 } },\n    { "name": "拆成 5 条", "type": "n8n-nodes-base.splitOut", "parameters": { "fieldToSplitOut": "topics" } },\n    { "name": "写口播脚本", "type": "@n8n/n8n-nodes-langchain.lmChatOpenAi", "parameters": { "model": "deepseek-chat", "temperature": 0.6 } },\n    { "name": "配图提示词（单独节点）", "type": "@n8n/n8n-nodes-langchain.lmChatOpenAi", "parameters": { "model": "deepseek-chat", "temperature": 0.8 } },\n    { "name": "调用出图接口", "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "{{ $env.IMAGE_API }}", "method": "POST" } },\n    { "name": "写回多维表格", "type": "n8n-nodes-base.larkBitable", "parameters": { "operation": "create", "table": "选题待审核" } }\n  ],\n  "connections": {\n    "每天 07:00": ["抓热点关键词"],\n    "抓热点关键词": ["生成 5 个选题"],\n    "生成 5 个选题": ["拆成 5 条"],\n    "拆成 5 条": ["写口播脚本", "配图提示词（单独节点）"],\n    "配图提示词（单独节点）": ["调用出图接口"],\n    "调用出图接口": ["写回多维表格"],\n    "写口播脚本": ["写回多维表格"]\n  }\n}' }],
    research: [
      'n8n 的 Schedule Trigger 节点支持 cron 表达式，适合每天固定时间触发 [1]。',
      '飞书多维表格提供开放接口，可以直接新增记录并触发后续自动化 [2]。',
    ],
    refs: [{ title: 'n8n 文档', url: 'https://docs.n8n.io/' }, { title: '飞书多维表格', url: 'https://www.feishu.cn/product/base' }],
    scope: ['适合：日更账号的选题储备', '数据：每天 5 套草稿，人工只做最后挑选（群友自述）'],
    kb: { versions: 1, isNew: true },
  },
  {
    seeds: [7], title: '小红书 AI 绘本号 30 天复盘：固定主角做连载，涨粉 4,200',
    background: [
      '七七在小红书起号营复盘了自己的绘本号：固定主角形象，9 图连载，选题集中在睡前故事和情绪安抚，每篇最后一张留悬念。30 天涨粉 4,200，单篇最高 1.1 万赞。',
      '沐沐的观察是宝妈们认的是那个角色，主角形象一旦换了，互动会明显下降。',
    ],
    prompts: [{ label: '系列主角设定', who: '七七', group: '小红书起号营', use: '每篇笔记复用',
      text: '主角：小熊「团团」，奶油色毛发，圆耳朵，戴一条红色小围巾，眼睛又大又圆。\n画风：水彩绘本风，暖色调，柔和光线，留白多。\n每张图只画一个场景，不画文字，旁白后期加。' }],
    research: [
      '小红书社区规范要求 AI 生成内容主动声明，未声明的可能被限流或下架 [1]。',
      '绘本类账号的常见变现路径是定制绘本、睡前故事音频和母婴品牌合作 [2]。',
    ],
    refs: [{ title: '小红书社区规范', url: 'https://www.xiaohongshu.com/' }, { title: 'AI 绘本账号变现路径（示例博客）', url: 'https://example.com/blog/ai-picture-book' }],
    scope: ['适合：母婴、情绪类内容', '数据：30 天涨粉 4,200，单篇最高 1.1 万赞（群友自述，非平台口径）'],
    riskNote: '平台对 AI 生成内容有声明要求，未声明可能限流；具体规则以平台最新公告为准。',
    images: ['m0901.png'], kb: { versions: 2 },
  },
  {
    seeds: [21], title: 'AI 漫画工作流：大模型拆分镜，图像模型逐格生成',
    background: [
      '画画的阿木的流程：先让大模型把剧本拆成分镜脚本，景别、动作、台词一格一行；角色设定卡全程附带，逐格生成。',
      '小鹿酱提醒对话框别让模型画，后期排版省事很多；桃子的经验是一话控制在 16 格以内，再多读者也看不完。群里还流传了一套分镜模板素材包（网盘）。',
    ],
    prompts: [{ label: '拆分镜提示词', who: '画画的阿木', group: '水彩手绘研习社', use: '把剧本交给大模型拆成分镜表',
      text: '把下面的剧本拆成漫画分镜，一话 12~16 格。\n每格一行，格式：格号 | 景别（远/全/中/近/特写）| 画面动作 | 台词（没有就写 无）\n不要描写镜头以外的心理活动；台词每格不超过 20 字。' }],
    research: [
      '分镜脚本的字段（景别、动作、台词）和影视分镜表一致，可以直接复用影视分镜模板 [1]。',
      '对话框和文字后期排版是商业漫画的通行做法，也能绕开图像模型的中文渲染问题 [2]。',
    ],
    refs: [{ title: '分镜表模板说明（示例博客）', url: 'https://example.com/blog/storyboard-template' }, { title: 'Clip Studio Paint', url: 'https://www.clipstudio.net/' }],
    scope: ['适合：条漫、短篇漫画、绘本', '数据：一话 12~16 格（群友经验）'],
    riskNote: '群里流传的网盘素材包来源不明，商用前请确认授权范围。',
    kb: { versions: 3 },
  },
  {
    seeds: [9], title: '视频号数字人：同模板日更 10 条，第 3 天播放断崖',
    background: [
      '大飞在 AI 副业互助会分享了一次翻车：同一数字人形象、同一模板日更 10 条，第三天起播放量「腰斩再腰斩」。',
      '十三的判断是同质化内容触发了降权。群里给出的调整办法是降频、脚本差异化、每周穿插真人出镜。',
    ],
    research: [
      '视频号运营规范对「批量发布重复、低质内容」有限制推荐的规定 [1]。',
      '数字人内容被识别为同质化，常见原因是开头画面、口播模板和背景音乐高度一致 [2]。',
    ],
    refs: [{ title: '视频号运营规范', url: 'https://channels.weixin.qq.com/' }, { title: '数字人账号同质化排查（示例博客）', url: 'https://example.com/blog/digital-human' }],
    scope: ['适合：用数字人做口播的账号', '数据：日更 10 条，第 3 天播放断崖（群友自述）'],
    riskNote: '高频批量发布可能触发平台限流甚至封号；降频和差异化是群友经验，不保证有效。',
    images: ['m1101.png'], kb: { versions: 2 },
  },
  {
    seeds: [27], title: '「AI 副业训练营」2,980 元退款难：付费课程的识别与维权要点',
    hook: '高收益承诺 + 先交费后上课；群友整理了试听、退款条款和留证的要点',
    background: [
      '大飞在 AI 副业互助会说，自己报了一个 2,980 元的「AI 副业训练营」，宣传「学完月入过万」，上完发现内容是网上公开教程的拼接。',
      '鱼丸也在申请退款，一直被拖着不给。群里有人分享了维权经验，也有人认为「课本身有用，问题在宣传」。以下内容整理群友说法，课程名称已隐去。',
    ],
    steps: ['付费前要求试听，并确认书面退款条款', '警惕承诺具体收入的宣传，截图保存', '保留聊天记录、付款凭证和课程内容截图', '协商不成时向消费者协会或支付平台投诉'],
    research: [
      '消费者权益保护相关规定要求经营者如实宣传，虚假宣传可以要求退款或赔偿 [1]。',
      '通过支付平台付款的，可以在平台内发起投诉或申请交易纠纷处理 [2]。',
    ],
    refs: [{ title: '12315 全国消费者投诉平台', url: 'https://www.12315.cn/' }, { title: '付费课程维权流程（示例博客）', url: 'https://example.com/blog/course-refund' }],
    scope: ['适合：考虑报名付费课程的人', '数据：收费 2,980 元（群友自述，未核实）'],
    riskNote: '群友说法未核实；课程是否值得、能否退款请以合同条款和实际情况为准。',
    kb: { versions: 1, isNew: true },
  },
]
