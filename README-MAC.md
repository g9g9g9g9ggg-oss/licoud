# README — 在 Mac 上跑起来并上真机（第一期骨架）

> 本文件夹是在 Windows 上生成的完整源码骨架（零第三方依赖，iOS 17+）。
> Xcode 工程文件（.xcodeproj）必须在 Mac 上生成，然后把这些源码装进去。全程约 15–20 分钟。

## 0. 前置（没做过的先做）

- Mac 已装正式版 Xcode（`xcodebuild -version` 有输出）
- Xcode → Settings → Accounts 已登录免费 Apple 账号（Personal Team）
- iPhone 已按《操作步骤》A4 准备：iOS 17+、连过 Mac、开发者模式已开
- 详细操作见《操作步骤-星链iOS-V1.0.md》A 章

## 1. 新建工程（生成 .xcodeproj）

1. Xcode → File → New → Project → iOS → App → Next
2. 参数：
   - Product Name：`StarLink`
   - Team：选你的 **Personal Team**
   - Organization Identifier：`com.<公司缩写>`（负责人确认的值）
   - Interface：SwiftUI；Language：Swift；Storage：None；**Include Tests 勾选**
   - 注意：**Organization Identifier 一旦定了别再改，Bundle ID 全程不动**（免费账号名额，见操作步骤 B2）
3. 位置选 `~/dev/` → Create

## 2. 装入源码

1. 在 Xcode 左侧工程里**删除**（Move to Trash）：
   - `StarLink/ContentView.swift`
   - `StarLinkTests/StarLinkTests.swift`
   - `StarLinkUITests` 整个组（不需要 UI 测试）
2. Finder 打开本文件夹：
   - 把 `StarLink/` 里**所有 .swift 文件**拖进 Xcode 的 `StarLink` 组
     → 弹窗勾 **Copy items if needed**，Added Folders 选 **Create groups**，Targets 只勾 `StarLink`
   - 把 `StarLinkTests/` 里所有 .swift 拖进 `StarLinkTests` 组
     → 同样勾 Copy，Targets 只勾 `StarLinkTests`

## 3. 工程设置

1. 选中最外层项目 → TARGETS → StarLink → General：
   - Minimum Deployments → **iOS 17.0**
2. Signing & Capabilities：Team = Personal Team，下方无红色报错
3. TARGETS → StarLink → Info → Custom iOS Target Properties → 点 `+`：
   - 新增键 `UILaunchScreen`，类型 Dictionary，**留空即可**（系统启动屏，防黑边）

## 4. 冒烟（模拟器）

1. 顶部设备选任一 iPhone 模拟器 → ⌘R
2. 应看到登录页：星链标题 / 账号密码框 / 登录按钮
3. 跑单元测试：⌘U，应全绿（8 个测试类 36 个用例）

## 5. 上真机（3 台）

按《操作步骤》D 章，每台：

1. 数据线连 Mac，Xcode 顶部选该 iPhone
2. ⌘R；首次报 `Untrusted Developer` → 手机：设置 → 通用 → VPN与设备管理 → 信任开发者证书 → 再 ⌘R
3. 手机桌面出现「星链」App → 当天设 7 天续期提醒（操作步骤 A5）

## 6. Mock 账号表（当前 `useMockServices = true`）

| 账号 | 密码 | 结果 |
|---|---|---|
| `TEST_1001` / `TEST_1002` / `TEST_1003` | `123456` | 登录成功（800ms 延迟，可观察 loading 态） |
| `TEST_1001` | 其他任意 | 内联红字「账号或密码错误」 |
| `TEST_offline` | 任意 | 「网络不可用，请检查网络」（模拟断网） |
| 非 `TEST_` 前缀 | 任意 | 「账号或密码错误」 |

三台设备分别登 `TEST_1001 / 1002 / 1003` 做交叉验证（E9）。

## 7. 真机测试清单

对照《操作步骤》E 章 E1–E9 逐项过：登录成功/失败、杀进程保持登录、四 Tab 切换、退出不可返回、深色模式、键盘避让、三台交叉。录屏命名 `P1-E1-登录成功-设备1.mov`。

## 8. 接真实后台（等负责人提供测试环境后）

1. `Core/AppConfig.swift`：`apiBaseURL` 换成测试环境地址，`useMockServices` 改 `false`
2. 对照设计书 5.1 校验登录接口字段；不一致改 `User.swift / APIEndpoint.swift` 的映射
3. 缺字段（如 `expiresIn`、`user.role`）→ 提「接口变更申请」，**不要改后台**

## 9. 红线提醒

- Bundle ID 全程不改；Archive 只做本地验证，**禁止 Upload/Validate 到任何苹果服务器**
- 本工程零第三方依赖，不装任何 SPM 包
- 品牌色当前为系统蓝占位（`DesignSystem/StarLinkColors.swift`），负责人给色值后替换

## 10. 单机聊天 Demo（第二期 UI 层预写）

> 已按附录 B 批准范围变更（对话留痕）。全部预写代码包在 `#if DEBUG`，**Release 正式构建不含**，消息 Tab 在 Release 下仍是占位页。

装完源码后 Debug 构建的「消息」Tab 即为聊天 Demo：

- 会话列表自动种子：`TEST_张三` / `TEST_李四`（李四带 2 条未读红点），支持滑动「标记已读 / 删除」
- 点进会话发消息：气泡依次 **sending（转圈）→ sent（✓）→ read（✓○）**，随后对方约 2 秒自动回一句
- 发送文本含 `#fail`（大小写不限）→ 立即变**失败**，点红色感叹号可重发
- 右上角联系人入口：mock 员工按部门 Section 分组、在线状态圆点，点任意人**一步开聊**（张三/李四直达已有会话，王五/赵六自动建会话）
- 输入栏左侧相册按钮：系统 PhotosPicker 选图 → 压缩（最长边 1280 / JPEG 0.8）→ 图片气泡 → 点开大图（下拉关闭 / 双击缩放 / 捏合 1–4x）
- 触感：发送成功（中）/ 前台新消息（轻），只在这两处，不滥用
- 留桩说明：`MessageTransport` 协议之外的真实接口、WebSocket/轮询、历史分页、图片上传、发送前预览确认页全部 TODO——第二期三问确认后**只补桩不返工**

新增单元测试 4 类 15 用例（MockTransport / ChatDemoEngine / ChatTimeFormatter / ImageResizer），⌘U 应共 **8 个测试类 36 个用例全绿**。

单机可先验的手感项（非第一期验收项，给第二期热身）：
1. 聊天窗键盘升降跟手（`.safeAreaInset`）
2. 气泡比例对照微信/系统 Messages
3. 长列表滚动流畅（往一个会话连发 50 条试）
4. 未读红点与列表预览一致性
5. 联系人开聊 → 发消息 → 返回列表看未读与预览联动
6. 图片发送与查看转场手感（对照系统照片）
