# XStreaming macOS Native

XStreaming 桌面客户端的 macOS 原生重建项目。

## 当前状态

这个仓库是 macOS 原生版本的独立工作区。它和原来的 Electron/Nextron 项目分离，目的是让原生架构、工具链和发布流程可以独立演进，而不会影响当前桌面版主线。

当前重点：

- 建立原生架构基线
- 把 Electron 行为映射到原生模块
- 按阶段执行迁移计划

## 仓库文档

- 架构基线文档：[docs/architecture/native-macos.md](./docs/architecture/native-macos.md)
- Electron 到原生的映射文档：[docs/migration/electron-to-native-mapping.md](./docs/migration/electron-to-native-mapping.md)
- 执行计划：[docs/plans/2026-04-14-xstreaming-macos-native-refactor.md](./docs/plans/2026-04-14-xstreaming-macos-native-refactor.md)

## 本地构建与运行

```bash
swift build --package-path native-macos
swift test --package-path native-macos
swift run --package-path native-macos XStreamingMacApp
```

当前阶段运行后可以看到：

- 原生 shell 主界面
- Home、Cloud、Settings、Stream 路由
- live 模式下的真实登录、真实主机列表和 xhome session 建立
- 通过 `WebViewStreamingEngine` 承载 `xstreaming-player` 的兼容 WebRTC 播放面
- 串流页中的 SDP/ICE 协商状态、WebRTC 播放状态和 Nexus 控制输入桥

## CI

GitHub Actions 工作流：

- `.github/workflows/native-macos.yml`
- 执行 `swift build --package-path native-macos`
- 执行 `swift test --package-path native-macos`
- 通过 `IntegrationTests` 执行 app launch smoke test

## 与原项目的关系

- 原桌面项目：当前发布路径和行为参考实现
- 当前仓库：基于 SwiftUI、Swift Package Manager、类型化模块和自动化测试的 macOS 原生重建

## 近期里程碑

1. 搭建原生 macOS 工作区骨架。
2. 定义共享领域模型和持久化层。
3. 建立认证、主机、目录和串流服务边界。
4. 接上 live 登录、主机发现、xhome 会话和兼容 WebRTC 播放面。
5. 为原生 app 补齐 CI、集成测试和打包前置骨架。
