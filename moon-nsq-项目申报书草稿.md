# moon-nsq 项目申报书草稿
> 供参赛者核对并用自己的表述定稿；当地章程要求申报书人工撰写。姓名和联系方式在报名表填写。

**基本信息**
- 项目名称：moon-nsq：MoonBit NSQ 异步客户端
- 申报方向：新生态项目建设／消息系统客户端与协议库
- GitHub：https://github.com/clhhhhhh/moon-nsq
- Mooncakes 包：`clhhhhhh/moon-nsq@0.1.0`，项目许可证：Apache-2.0

**项目简介与价值**
为 MoonBit 程序提供连接 NSQ、发布二进制消息和订阅消费的基础库。NSQ 在其他语言中已有成熟客户端，消息格式和通信协议明确，适合按协议实现及验证。MoonBit 服务若要接入已有 NSQ 系统，需要可复用的命令编码、帧解析和异步连接组件，而不是每个业务重复处理 TCP 字节流。近期 Mooncakes 的 `nsq` 检索仅发现本项目；这是一项检索结果，不代表对整个生态的穷尽判断。

**三个预期使用场景**
1. 异步任务分发：MoonBit 服务将通知、文件处理等任务发布到指定 Topic，工作进程从 Channel 消费；处理成功发送 FIN，失败按策略发送 REQ，减少请求链路中的同步等待。
2. 事件多路处理：应用发布订单或设备事件，归档、统计等任务分别订阅不同 Channel；各处理流程维护自己的确认与重试，复用同一套消息收发接口。
3. 定时与批量投递：后台任务使用 DPUB 延迟发送提醒，使用 MPUB 批量写入积累的事件；通过批次容量限制控制内存和请求大小，并检查 broker 返回的确认结果。

**核心范围与实现路径**
使用 MoonBit 和 `moonbitlang/async` 直接实现 NSQ TCP V2：按长度字段读取帧，区分响应、错误和消息；封装 IDENTIFY、PUB/DPUB/MPUB、SUB/RDY、FIN/REQ/TOUCH，并在读取时处理心跳。对外提供 Producer、Consumer 和基础 nsqlookupd 查询接口。先验证协议边界与错误处理，再完善基础调用示例和文档；测试采用确定性断言及模拟 TCP 服务。交付定位为基础客户端，不承诺 TLS、压缩、自动重连、多 broker 自动调度或生产级运维平台。

**当前成果与预计交付**
已有协议实现、发布与消费 API、发布 CLI、README 和 Apache-2.0 许可证；54 个测试通过，GitHub Actions 已覆盖检查、构建、测试，`0.1.0` 已发布到 Mooncakes。真实 NSQ 服务联调尚未完成，不将模拟测试作为真实联调结果。后续交付以当前基础功能及其说明、测试和必要缺陷修复为边界，不新增大型框架。提交记录中早期模块提交为事后整理，后续修复保留实际提交记录，不以提交次数代替质量证明。

**原创与参考说明**
项目为 MoonBit 实现，含 AI 辅助开发，不是完整移植其他语言客户端。协议参考 NSQ TCP 规范：https://nsq.io/clients/tcp_protocol_spec.html；管理操作参考 NSQ HTTP 文档：https://nsq.io/components/nsqd.html。参考项目 NSQ：https://github.com/nsqio/nsq，许可证 MIT；本项目以 Apache-2.0 发布。
