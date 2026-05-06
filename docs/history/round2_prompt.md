你是一个 Flutter 界面实现工程师。

项目 /data/projects/wherehouse 的数据层（models, database, daos, services, providers）已经完成。
现在需要补齐所有 UI 层代码。

已有文件（不要修改）：
- lib/main.dart — 入口
- lib/app.dart — 主题 + AppShell（底部导航 + FAB）
- lib/models/thing.dart — Thing, Tag, ThingDraft, FollowUpPrompt
- lib/models/household.dart — Household, WherehouseUser, Tag
- lib/database/database.dart — AppDatabase (drift, raw SQL)
- lib/database/daos/thing_dao.dart — ThingDao (CRUD, search, tag 管理)
- lib/services/llm_service.dart — LlmService (Dashscope VL + fallback)
- lib/services/storage_service.dart — StorageService (本地照片存储)
- lib/services/asr_service.dart — AsrService (Phase 2 placeholder)
- lib/providers/app_providers.dart — Riverpod providers

需要创建以下文件：

## 1. lib/screens/home_screen.dart
- 顶部搜索栏（文字输入，实时搜索）
- 搜索结果用 ThingCard 网格展示
- 无搜索时展示最近录入的物品（recentThingsProvider）
- ConsumerWidget，使用 searchThingsProvider / recentThingsProvider

## 2. lib/screens/add_screen.dart
- 核心录入流程：拍照（image_picker）+ 文字描述 → LLM 提取 → 确认卡片
- 确认卡片用 ConfirmCard widget 展示
- LLM 追问：如果 draft.followUp 不为 null，输入框 placeholder 显示追问文案
- 用户可以回复追问（调用 llmService.refineDraft）或直接确认
- Ghost tag：proposedTags 用虚线框 chip 展示，点击即创建 tag + 分配
- 已有 tag 用实心 chip 展示，可移除
- 确认后调用 thingDao.saveDraft() 保存
- ConsumerStatefulWidget

## 3. lib/screens/browse_screen.dart
- Thing 网格/列表浏览（browseThingsProvider）
- 点击进入 DetailScreen

## 4. lib/screens/detail_screen.dart
- 展示 Thing 详情：照片轮播、名称、位置链（LocationChain）、tags、有效期、备注
- 编辑、删除功能
- 位置链用 locationChainProvider 获取

## 5. lib/widgets/thing_card.dart
- 物品卡片组件：照片缩略图 + 名称 + 位置 + 过期标记
- 点击回调 onTap

## 6. lib/widgets/confirm_card.dart
- LLM 提取确认卡片
- 展示：物品名、位置、有效期、tags（实心 chip）、proposed tags（虚线框 ghost chip）
- ghost chip 用 dotted_border 包裹，点击回调 onGhostTagTap(String tagName)
- 支持字段编辑

## 7. lib/widgets/location_chain.dart
- 位置面包屑：Thing → 容器 → 容器的容器 → ...
- 用 Wrap + Chip 或 Row + 箭头展示

## 技术约束
- 使用 flutter_riverpod (ConsumerWidget / ConsumerStatefulWidget / ref.watch / ref.read)
- 使用 image_picker 拍照
- 使用 dotted_border 包做 ghost tag 虚线框
- 照片用 StorageService.saveImage() 存储
- 中文 UI，温暖色调（已在 app.dart 定义主题）
- 不要创建新的 provider，使用 app_providers.dart 里已有的

每个文件都要完整实现，不要留 TODO 或占位符。
