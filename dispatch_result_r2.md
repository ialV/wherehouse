已按 ADR 把这 7 个 UI 文件补齐了：

- [home_screen.dart](/data/projects/wherehouse/lib/screens/home_screen.dart) 实现了顶部实时搜索，空搜索展示最近录入，结果用 `ThingCard` 网格展示。
- [add_screen.dart](/data/projects/wherehouse/lib/screens/add_screen.dart) 实现了拍照、图片本地保存、LLM 提取、追问补充、`ConfirmCard` 确认、ghost tag 转正和最终 `saveDraft()` 保存。
- [browse_screen.dart](/data/projects/wherehouse/lib/screens/browse_screen.dart) 实现了网格/列表浏览并跳转详情。
- [detail_screen.dart](/data/projects/wherehouse/lib/screens/detail_screen.dart) 实现了照片轮播、位置链、标签、有效期、备注，以及编辑和删除。
- [thing_card.dart](/data/projects/wherehouse/lib/widgets/thing_card.dart)、[confirm_card.dart](/data/projects/wherehouse/lib/widgets/confirm_card.dart)、[location_chain.dart](/data/projects/wherehouse/lib/widgets/location_chain.dart) 都已完成并接入现有 model/provider。

校验方面，`git diff --check` 已通过。`dart format` 和 `flutter analyze` 这次没法跑，因为当前环境里 `dart` / `flutter` 都不在 PATH，所以我只能做代码级自检，不能做 SDK 级静态验证。