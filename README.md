'''
# 📱 全能系统管家 (AIO-KSU-Toolbox)

这是一个基于 KernelSU / APatch WebUI 机制打造的 **All-In-One (AIO) 极客聚合模块**。

本项目致力于打造一个零耗电、零卡顿、极具交互美学的“全能底座”。彻底抛弃了传统的“终端黑框框”和“物理音量键盲操”，为你带来原生、直观的可视化系统控制台。

* **项目主页**: [https://github.com/Zgt00086/Gemini-Aggregator](https://github.com/Zgt00086/Gemini-Aggregator)

## ✨ 核心特性

* **🛡️ 系统更新屏蔽器**：通过底层物理挂载空文件彻底冻结系统更新组件，支持防误触 Toast 提示与重启持久化状态明示。
* **⚡ Smart DexOpt 引擎**：采用原生 V4 引擎深度扫描。纯 Native C++ 底层排查，无死角掌控应用编译状态。
* **🧩 模块跳转中心**：一键聚合本机所有 KSU 模块，直达 MT 管理器对应目录。
* **👻 后台静默守护中心**：内置零耗电开机脚本，如 **Gemini 唤醒自动修复**，在 WebUI 底部静默展示。

---

## 👨‍💻 开发者/AI 协作指南：如何无缝融合新模块？

如果你想让 AI 帮你写新功能并融合进本模块，请直接复制以下“咒语”发送给 AI：

> **【AIO 聚合管家 - 插件注入请求】**
> 我正在维护一个基于 KernelSU / APatch WebUI 的 AIO 模块（V10 架构）。
> 
> **底层开发排版规则：**
> 1. **交互功能**：以 MIUIX 折叠卡片 `<details class="miuix-card">` 格式，按时间顺序插入在 `index.html` 的上方。
> 2. **异步不阻塞**：必须使用 `nohup` + `Base64` 转码注入的方法将耗时 Shell 放入底层运行。
> 3. **强反馈原则**：所有执行动作必须包含人工视觉延迟、震动反馈以及 Toast 提示。
> 4. **静默功能**：不需要卡片，固定排在 `index.html` 最下方。相关代码写入 `service.sh` 并挂入后台。
> 
> **本次我要新增的功能是：** [此处填写你的需求]
> 
> **请直接给我：**
> 1. 需要追加到 `service.sh` 的代码。
> 2. 需要插入 `index.html` 的 HTML/CSS/JS 代码，并明确说明插入位置。

---

### 目录结构
A-gemini/
[span_0](start_span)├── module.prop         # 模块基本信息[span_0](end_span)
├── service.sh          # 开机守护脚本 (含 Gemini 修复等后台任务)
├── README.md           # 你现在看到的这个文档
└── webroot/
    └── index.html      # AIO 可视化控制台核心代码
'''
