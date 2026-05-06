# ADR-001: Wherehouse MVP — 家庭物品定位 APP

## Status: PROPOSED

## Context

家庭场景下，东西找不到是高频痛点：
- 药品：「家里有布洛芬吗？在哪？过期没？」
- 衣物：洗完不知道放在哪了
- 日用品：明明买过但翻遍了也找不到

关键约束：**录入摩擦必须趋近于零**，否则用户不会坚持用。

之前考虑过微信小程序，但拍照存储受限，已决定做原生 APP。

## Decision

### 1. 核心交互：拍照 + 一句话

录入流程（< 10 秒 + 可选追问）：
1. 打开 APP → 点「放」按钮
2. 拍一张照片（或从相册选）
3. 说一句话 / 打一行字：「这个放厨房了」
4. LLM 解析 → 展示确认卡片：
   ```
   📦 盐酸氨溴索口服液        （照片识别）
   📍 厨房
   📂 药品
   ⏰ 有效期：未知
   ✅ 确认  ✏️ 修改
   ```
5. **写入时治理——LLM 追问**（输入框 placeholder）：
   ```
   💬 「厨房具体哪个位置？有看到有效期吗？」
   ```
6. 用户可以：
   - **直接 ✅ 确认**（信息不全也能存，追问不阻塞）
   - **回复追问**（补充信息后卡片实时更新）
   - **✏️ 手动修改**卡片字段

#### 追问策略（Write-time Governance）

LLM 不是自由聊天，而是按规则判断是否追问、如何追问：

| 场景 | 追问级别 | 呈现方式 |
|------|---------|----------|
| 药品缺有效期 | 重要 | 输入框 placeholder 明确提问 |
| 位置模糊（只说「厨房」没说具体） | 轻度 | placeholder 温柔引导 |
| 信息充分 | 无 | 不追问，直接确认 |
| 容器内可能有其他物品值得录入 | 建议 | 确认后弹出软提示「药箱里还有别的要录吗？」 |

原则：**追问是服务，不是审批。用户永远可以跳过。**

查询流程（< 3 秒）：
1. 打开 APP → 搜索栏 / 语音按钮
2. 「布洛芬在哪」或「药箱里有什么」
3. 结果卡片 + 照片缩略图 + 位置链（布洛芬 → 客厅药箱 → 电视柜）

### 2. 数据模型：一切皆 Thing

统一模型，位置也是物品，物品也可以是位置：

```
Thing {
  id:            UUID
  household_id:  UUID          // 所属家庭
  name:          String        // "布洛芬"
  photo_urls:    [String]      // 本地路径 + 云端 URL
  tags:          [UUID]        // -> Tag IDs，受控词表，LLM 分配 + 用户确认新增
  contained_in:  UUID?         // -> 另一个 Thing（"客厅药箱"）
  expiry:        Date?         // 有效期（药品、食品）
  notes:         String?       // 自由备注
  created_by:    UUID          // 哪个家庭成员录入的
  created_at:    DateTime
  updated_at:    DateTime
}

Household {
  id:            UUID
  name:          String        // "我家"
  invite_code:   String        // 6位邀请码，家人加入用
  members:       [UUID]        // -> User IDs
}

User {
  id:            UUID
  name:          String
  household_ids: [UUID]
}

Tag {
  id:            UUID
  household_id:  UUID          // 每个家庭独立词表
  name:          String        // "感冒常备"、"出差必带"、"换季穿的"
  usage_count:   Int           // 被多少 Thing 引用
  status:        String        // active | archived
  created_at:    DateTime
  last_used_at:  DateTime
}
```

查询能力：
- `WHERE name LIKE '%布洛芬%'` → 模糊搜索
- `WHERE tags CONTAINS <tagID>` → 按 tag 筛选（「感冒常备的药」）
- `WHERE contained_in = <药箱ID>` → 「药箱里有什么」
- 递归上溯 contained_in → 「布洛芬 → 客厅药箱 → 电视柜 → 客厅」
- `WHERE metadata.expiry < NOW() + 30d` → 即将过期提醒

### 3. 技术栈

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Mobile** | Flutter | 跨平台，相机/本地存储支持好 |
| **ASR** | Dashscope Qwen3-ASR-Flash | 用户已验证，流式中文效果好 |
| **LLM** | Dashscope Qwen（通义千问） | 结构化信息提取、tag 生成、自然语言查询理解 |
| **Backend** | Supabase (PostgreSQL + Auth + Storage) | 家庭共享、照片云存储、实时同步，免运维 |
| **Local DB** | SQLite (drift) | 离线可用，拍照先存本地 |
| **State** | Riverpod | Flutter 状态管理 |

### 4. LLM 提取 Prompt（核心）

```
你是一个家庭物品录入助手。用户会给你一张照片和一句描述。

任务一：提取结构化信息（JSON）：
{
  "item_name": "物品名称",
  "location": "放置位置（另一个物品或地点名称）",
  "expiry": "有效期（ISO date，仅当提到或照片可见时）",
  "tags_existing": ["从已有词表中选择的 tag 名"],
  "tags_proposed": ["词表里没有、但建议新增的 tag 名"],
  "notes": "任何额外信息"
}

任务二：判断是否需要追问。输出：
{
  "follow_up": "追问文案，null 表示不追问",
  "follow_up_reason": "追问原因（用于调试）",
  "importance": "important|gentle|none"
}

追问规则：
- 药品/食品缺有效期 → important，明确询问
- 位置过于模糊（只有房间没有具体容器） → gentle，温柔引导
- 信息充分 → none
- 追问文案要口语化、简短（< 20字），像家人随口问一句
- 永远不要连续追问两次，用户跳过就跳过

提取规则：
- 如果用户没提到有效期，尝试从照片中识别
- location 如果用户没说，返回 null
- 尽量用简短常用的中文名称

Tag 分配规则：
- 系统会在 prompt 中注入当前词表（如 ["感冒常备","止痛","儿童用药",...]）
- 优先从已有词表中选择（tags_existing），可多选
- 仅当确实没有合适的已有 tag 时，才在 tags_proposed 中提议新 tag
- 提议的 tag 应简短（2-4字）、有复用潜力，不要过于具体
```

### 4.1 TAG 治理策略

Tag 是用户心智模型的映射（「感冒常备」「出差必带」「换季穿的」），比固定 category 更贴近真实找东西的思路。但 tag 膨胀 = tag 无用，所以需要全生命周期治理：

#### 写入时：LLM 优先复用

1. 每次 LLM 调用时，系统在 prompt 中注入当前 tag 词表
2. LLM **优先从词表中选择**已有 tag → 静默分配，不打扰用户
3. LLM 认为需要新 tag → 放入 `tags_proposed`，**不直接创建**

#### 新 tag 确认：Ghost Tag（幽灵标签）

确认卡片中，已有 tag 显示为**实心 chip**，proposed tag 显示为**虚线框 chip**：

```
📦 布洛芬
📍 客厅药箱
⏰ 有效期 2027-08

🏷️ [止痛] [感冒常备]  ┊  ╌╌[退烧]╌╌ ╌╌[家庭急救]╌╌
     已有 tag（已分配）       ghost tag（点击即创建+分配）
```

交互：
- **实心 chip**：已从词表分配，点击可移除
- **虚线 chip（ghost tag）**：LLM 提议的新 tag，**点一下 → 创建 tag + 分配给当前物品**，chip 变实心
- 不点 = 不创建，零打扰
- Ghost tag 的提议记录保留，如果同一个 ghost tag 在多次录入中反复出现，下次攒批提醒时优先展示

#### 攒批复盘（补充路径）

对于用户忽略的 ghost tags，如果 LLM 在后续录入中反复提议同一个 tag，则攒批提示：

```
最近几次录入中，「退烧」这个标签被建议了 3 次：
  适用于：布洛芬、对乙酰氨基酚、美林
  🏷️ 加入标签词表？  ✅ 加入  ⏭️ 不了
```

#### Tag 健康度维护

| 信号 | 动作 |
|------|------|
| 两个 tag 经常共现于相同物品 | 提示合并（「止痛」+「止痛药」→ 合并？） |
| tag 仅被 1 个物品使用且超过 60 天 | 提示归档 |
| tag 总数超过阈值（如 30） | 提示用户 review 清理 |
| tag 0 引用 | 自动 archived |

### 5. MVP Scope（Phase 1）

**IN：**
- [ ] Flutter APP 骨架（iOS + Android）
- [ ] 拍照 + 文字录入 → LLM 提取 → 确认卡片（含追问）→ 本地保存
- [ ] 文字搜索 + 结果展示（含照片、位置链）
- [ ] Thing 列表/网格浏览
- [ ] Thing 详情页（编辑、删除、移动位置）
- [ ] SQLite 本地存储

**OUT（Phase 2+）：**
- [ ] 语音录入（Dashscope ASR 集成）
- [ ] Supabase 后端 + 云同步
- [ ] 家庭共享（Household + 邀请码）
- [ ] 有效期到期推送通知
- [ ] 照片 OCR 自动识别有效期
- [ ] 自然语言查询（「快过期的药」→ LLM 转 SQL）

### 6. 项目结构

```
wherehouse/
  lib/
    main.dart
    app.dart
    models/
      thing.dart          // Thing 数据模型 + freezed
      household.dart
    services/
      llm_service.dart    // Dashscope LLM 调用
      asr_service.dart    // Dashscope ASR（Phase 2）
      storage_service.dart // 照片本地存储
    database/
      database.dart       // drift SQLite schema
      daos/
        thing_dao.dart
    screens/
      home_screen.dart    // 搜索 + 最近物品
      add_screen.dart     // 拍照 + 描述 → 确认
      detail_screen.dart  // Thing 详情
      browse_screen.dart  // 按位置/分类浏览
    widgets/
      thing_card.dart     // 物品卡片组件
      confirm_card.dart   // LLM 提取确认卡片
      location_chain.dart // 位置面包屑
  test/
  pubspec.yaml
  .env.example            // DASHSCOPE_API_KEY=sk-xxx
```

### 7. 环境变量

项目通过 `.env` 管理密钥，**不硬编码 API key**：

```
DASHSCOPE_API_KEY=       # 百炼 API Key
SUPABASE_URL=            # Phase 2
SUPABASE_ANON_KEY=       # Phase 2
```

## Consequences

- 拍照 + 文字的录入方式摩擦极低，核心假设需验证
- Thing 统一模型避免了 location vs item 的二元对立，查询自然
- MVP 纯本地，无后端依赖，可快速验证核心体验
- Phase 2 加云同步 + 家庭共享时，数据模型无需改动
- LLM 成本极低（家庭使用量级，每月几毛钱）
