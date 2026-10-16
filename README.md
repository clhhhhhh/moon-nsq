# moon-nsq

使用 MoonBit 编写的 NSQ TCP V2 客户端实验性实现，作为 MoonBit 开源生态比赛项目持续开发。

**当前状态：开发中。** 已实现基础协议、异步 TCP API 和部分辅助组件，并有单元测试及模拟 TCP 服务测试。尚未完成真实 `nsqd` / `nsqlookupd` 联调，不能承诺生产环境可用性。截至 2026-10-16，尚未确认发布到 Mooncakes，请从源码使用。

## 已实现的功能

| 范围 | 当前实现 |
| --- | --- |
| 协议 | NSQ V2 握手、帧编解码、消息解析、增量帧解析 |
| 发布 | `PUB`、延迟发布 `DPUB`、批量发布 `MPUB`、绑定 Topic 的 `Producer` |
| 消费 | `SUB`、`RDY`、`FIN`、`REQ`、`TOUCH`，以及 `Consumer` 启动、暂停、恢复和单条处理 |
| 连接 | 明文 TCP、基础 IDENTIFY、读取帧时回复心跳、CLS 关闭请求 |
| 发现 | nsqlookupd 查询、端点轮询、健康状态和冷却路由 |
| 辅助组件 | 批量缓冲、重试决策、计数器、延迟直方图、投递窗口、拓扑配置数据模型 |
| 管理操作 | 操作描述、参数检查及 URL 构造；没有管理 HTTP 请求执行 API |

`ConnectionPool` 是有容量限制的**端点租约管理器**，不建立、持有或复用 TCP 连接。重试策略、健康度和指标是独立组件，尚未组成自动重连或自动故障转移流程。死信组件仅提供决策和统计，不会自动发布到死信 Topic。

## 从源码开始

需要安装 MoonBit 工具链和 Git。本地验证使用 `moonc v0.10.14`；GitHub Actions 在 Ubuntu 上验证 `wasm` 目标。

```sh
git clone https://github.com/clhhhhhh/moon-nsq.git
cd moon-nsq
moon update
moon check --target wasm --deny-warn
moon build --target wasm --deny-warn
moon test --target wasm --deny-warn
```

默认目标为 `wasm`，直接依赖 `moonbitlang/async@0.22.1`。网络功能使用 MoonBit 运行器提供的能力，不是可直接用于浏览器的客户端。Native 目标曾通过本地检查，但本机缺少 C 编译器，未完成 Native 构建和测试；其他目标未验证。

包名为 `clhhhhhh/moon-nsq`。由于尚未确认发布，不应把 `moon add clhhhhhh/moon-nsq` 当作已经验证可用的安装方式。

## 命令行发布示例

仓库中的 `cmd/main` 使用低层 `Connection` 发布一条 UTF-8 消息，固定连接目标主机的 **4150 TCP 端口**。需要自行安装 NSQ 并启动服务：

```sh
nsqd --tcp-address=127.0.0.1:4150 --http-address=127.0.0.1:4151
```

在项目目录的另一终端运行：

```sh
moon run cmd/main --target wasm -- 127.0.0.1 orders.created "hello"
```

收到 broker 的 `OK` 后输出 `published to orders.created`，表示发布请求得到确认，不表示消费者已经处理消息。以上是真实服务的预期运行步骤，本项目尚未完成该端到端验证。

不提供参数可查看用法，不需要 NSQ 服务：

```sh
moon run cmd/main --target wasm
```

## API 使用顺序

包导入配置可参考 `cmd/main/moon.pkg`，公开接口见 `pkg.generated.mbti`。

- 发布：`Producer::connect(host, port, topic)` 完成连接和 IDENTIFY，随后调用 `publish` 或 `publish_deferred`，最后 `close`。
- 批量发布：创建 `new_batch`，逐条 `push` 并处理 `Added`、`Full`、`TooLarge` 结果，再调用 `publish_batch`。成功确认后清空批次，失败保留数据；网络断开时 broker 是否已接收可能无法判断，重试可能产生重复消息。
- 消费：`Consumer::connect` 后调用 `start`，再 `receive`，并以 `finish`、`requeue` 或 `discard` 结算消息；长任务可手动 `touch`。`discard` 实际发送 FIN，不会转发到死信队列。
- 回调消费：`process_one` 每次只处理一条消息，由调用者循环并处理异常。达到 `max_attempts` 后的重投递决策会转为丢弃确认。
- 服务发现：创建 `Lookupd`，调用 `lookup(topic)` 获取端点，再由调用者建立连接。发现刷新和重新连接需要自行调度。

目前仓库仅提供发布 CLI，没有独立的消费者命令行示例。

## 测试和 CI

截至 2026-10-16，最近一次验证为 **54 个测试通过**。覆盖协议编解码、命令、参数校验、批次、路由、租约等组件；部分连接流程使用本地模拟 TCP 服务验证，包括心跳应答、NOP 无响应和发布失败时保留批次。

这些测试不依赖真实 NSQ 服务，不能替代真实 broker 兼容性和可靠性验证。目前没有真实 NSQ 端到端测试、压力测试或性能基准结果。

[GitHub Actions](https://github.com/clhhhhhh/moon-nsq/actions) 在 Ubuntu 上执行依赖更新及 WASM 目标的检查、构建、测试。最近已确认成功的代码提交为 `48b20db`。

维护接口与格式：

```sh
moon info --target wasm
moon fmt
git diff --check
```

## 来源和许可证

项目采用根目录 [LICENSE](LICENSE) 中的 Apache-2.0 许可证。协议实现参考 [NSQ TCP 协议规范](https://nsq.io/clients/tcp_protocol_spec.html)，管理操作定义参考 [NSQ HTTP API 文档](https://nsq.io/components/nsqd.html)。本仓库为 MoonBit 实现，包含 AI 辅助开发与审查工作，不宣称移植了完整的官方客户端。

NSQ 项目采用 MIT 许可证，是协议和服务端参考项目，不随本库源码分发。使用本库及其依赖时还应遵守依赖自身的许可证。
