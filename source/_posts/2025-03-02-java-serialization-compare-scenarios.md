---
title: Java 序列化对比——官方 Serializable 与常见三方库的优缺点与适用场景
date: 2025-03-02
tags:
  - java
  - 序列化
  - Jackson
  - Kryo
  - Protobuf
  - 选型
categories:
  - Java
  - 架构
---

# Java 序列化对比：官方 Serializable 与常见三方库的优缺点与适用场景

本文以 **Java 官方序列化**（`java.io.ObjectOutputStream` / `ObjectInputStream`，即 Serializable 那套）为基准，对比常见三方方案（JSON / 高性能二进制 / 跨语言协议）的**优缺点**、**源码层面差异**，以及**各自适用场景**。

---

## 一、官方 Serializable 的“底层决定了它的优缺点”

### 1.1 核心机制（源码要点）

- **写类元数据**：`ObjectOutputStream.writeClassDesc()` / `writeNonProxyDesc()` 把 `ObjectStreamClass` 的 class descriptor（类名、serialVersionUID、字段列表等）写进流。
- **写对象图 + 循环引用**：`writeObject0()` + **HandleTable**（句柄表）+ `ObjectStreamClass`，实现“同一对象只写一次、后续写引用句柄”。
- **字段写入路径**：默认走 `ObjectStreamClass` 的字段描述写 primitive/object；特殊情况走 `writeObject`/`readObject`、Externalizable、`writeReplace`/`readResolve` 等钩子。
- **反序列化创建对象**：`ObjectInputStream.readObject0()` + `ObjectStreamClass.newInstance()`（内部用 ReflectionFactory 等“绕过构造器”的路径），再把字段灌进去。

### 1.2 由此带来的优缺点

| 优点 | 缺点 |
|------|------|
| 对象图完整，循环引用/共享引用天然支持 | 流里带大量类描述，体积大 |
| 对 Java 对象模型最忠实 | 反射 + 安全检查多，性能一般 |
| 一套 API 覆盖各种对象 | 强绑定 Java 类结构，跨语言差、演进麻烦 |
|  | 历史上反序列化安全风险高（gadget 链） |

**结论**：三方库的优缺点，本质上来自这几件事的差异——**是否写类描述、是否用 schema/字段 tag、是否大量反射、是否保留对象图语义、对象创建方式**。

---

## 二、源码差异归纳：五条因果链

### 2.1 写不写 class descriptor（ObjectStreamClass）

| 做法 | 代表 | 结果 |
|------|------|------|
| **写** | 官方 Serializable | 通用、能完整恢复对象图，但臃肿、强绑定 Java |
| **不写** | 多数三方 | 更小更快，但要靠 schema / 注册 / 约定 |

### 2.2 字段标识方式：字段名 vs 数字 tag vs 顺序

| 方式 | 代表 | 结果 |
|------|------|------|
| **字段名字符串** | JSON | 可读、演进宽松，但体积大、解析慢 |
| **数字 tag** | Protobuf / Avro | 紧凑、快、演进强，但要维护 schema |
| **顺序** | 部分 Kryo / 自定义 | 最快最小，但对字段增删改最敏感 |

### 2.3 对象图语义（引用/循环）是否协议原生支持

| 支持方式 | 代表 | 结果 |
|----------|------|------|
| **协议原生** | 官方 Serializable（HandleTable） | 同一对象只写一次，读回同一引用，环自然还原 |
| **默认不支持** | JSON / Protobuf | 需自己用 ID 引用等方式表达 |
| **可选** | Kryo | 可配置引用跟踪，不一定默认等价 Serializable |

### 2.4 对象创建方式：绕过构造器 vs 正常构造

| 方式 | 代表 | 结果 |
|------|------|------|
| **绕过构造器** | 官方（ReflectionFactory 等） | 能恢复复杂对象图，但反序列化风险高、行为复杂 |
| **构造器/无参 + setter** | JSON 类库 | 行为更可预期，安全面更好 |
| **生成代码控制** | Protobuf | 构建过程可控，性能好 |

### 2.5 反射 vs 字节码生成 vs 代码生成

| 手段 | 代表 | 结果 |
|------|------|------|
| **反射 + 复杂元数据** | 官方 Serializable | 灵活但慢、安全检查多 |
| **反射 + 缓存 + 可选 bytecode** | Jackson | 平衡可读与性能 |
| **生成代码 + 紧凑二进制** | Protobuf | 通常最快、最稳定、跨语言 |

---

## 三、各方案对比：优缺点与源码差异

### 3.1 JSON 类：Jackson / Fastjson2 / Gson

**与官方的核心差异**：不走 `ObjectStreamClass` / `writeClassDesc` 的二进制协议，而是：

- 字符/UTF-8 的 token 流（字段名、数值、数组/对象边界）
- 映射层把“字段名/注解/策略”绑定到 POJO

**Jackson 典型源码点**：

- 写：`ObjectMapper#writeValue` → `JsonFactory` → `JsonGenerator`，`BeanSerializer` / `BeanPropertyWriter` 遍历属性输出 JSON
- 读：`ObjectMapper#readValue` → `JsonParser` 读 token，`BeanDeserializer` / `SettableBeanProperty` 把值 set 进对象

**Fastjson2**：入口类似 `JSON#toJSONString` / `parseObject`，更多快速路径、按类型走专用 reader/writer，性能更激进。

**Gson**：`TypeAdapter` + 反射读写字段，结构简单，配置与优化路径相对少。

| 优点 | 缺点 |
|------|------|
| 跨语言（JSON 通用） | 不天然保留对象图（循环/共享引用默认丢，需额外机制如 Jackson object identity） |
| 可读、可调试 | 类型信息缺失，多态/接口需显式 type info |
| schema 变更相对宽松（新增字段对旧端友好） | 性能/体积一般不如高效二进制（字段名重复、文本解析） |
| 安全面通常好于 Serializable（不会自动走 gadget 链那套） | Fastjson 历史安全包袱需谨慎配置 |

---

### 3.2 高性能 Java 二进制：Kryo / Protostuff

**与官方的核心差异**：一般不把“完整 class descriptor”写在每个对象旁，而是 **type id + 字段序列化** 的紧凑模型。

**Kryo 典型源码点**：

- 入口：`Kryo#writeObject` / `readObject`
- `Serializer` 体系（如 `FieldSerializer`），`Output`/`Input` 做紧凑二进制（varint、无字段名）
- 引用跟踪是**可配置特性**，不是协议必带

| 优点 | 缺点 |
|------|------|
| 体积小、速度快（无大段 writeClassDesc） | 跨语言差（Java 内部协议） |
| 注册类 → 小整数 id，进一步缩小体积 | 类演进敏感，字段顺序/增删改需控制 serializer 或兼容策略 |
| 可选引用跟踪 | 对象图语义依赖配置，不一定默认等价 Serializable |

**Protostuff**：思路类似“Protobuf 编码 + POJO 友好”，无类描述字符串、字段用 tag、二进制紧凑，在性能/紧凑与演进/跨语言之间取平衡。

---

### 3.3 跨语言协议：Protobuf / Avro / MessagePack

**共同点**：不写 Java 类描述（`ObjectStreamClass`），用 **schema + 字段 tag/编号** 编码，生成代码或按 schema 驱动解析，减少反射。

**Protobuf**：

- Java 侧：`CodedOutputStream` / `CodedInputStream` 做 varint、tag 编码，字段用**数字 tag** 而非字段名
- 大量场景用**代码生成**的 `MessageLite` 子类读写

| 优点 | 缺点 |
|------|------|
| 超紧凑、快、跨语言 | 需维护 .proto（或等价 schema） |
| schema 演进能力强（tag 不变，新增字段对旧端安全） | 对复杂“任意对象图”不友好，引用/循环需自己设计 ID |

**Avro**：schema 驱动（常为 JSON schema），reader/writer schema 可不同，靠 schema resolution 做兼容，适合数据管道/Kafka；对象图语义同样不是目标。

**MessagePack**：二进制 JSON，比 JSON 更紧凑、解析更快，跨语言；若不用 schema，类型与演进需自行约定，对象图也不天然保留。

---

## 四、适用场景（按框架）

### 4.1 官方 Serializable

| 适用 | 不适用 |
|------|--------|
| 纯 Java 内部短期持久化（如 HttpSession、本地临时缓存） | 微服务、跨语言、高性能系统 |
| Java RMI（历史项目） | 公网输入反序列化（安全风险） |
| 原型 / Demo |  |

**原因**：写完整类描述、强绑 serialVersionUID、HandleTable 维护对象图、反序列化可绕过构造器 → 适合“完整恢复 Java 对象图”，不适合高性能与跨语言。

---

### 4.2 Jackson（企业 REST 标准）

| 适用 | 不适用 |
|------|--------|
| REST API（Spring Boot 默认） | 超高 QPS 内部 RPC |
| 配置文件（YAML、JSON config） | 需要极致压缩 |
| ES / OpenSearch 文档映射 |  |
| 中等规模缓存（如 Redis JSON） |  |

**原因**：基于字段名、JsonGenerator/JsonParser、反射+缓存 BeanSerializer → 可读、跨语言、兼容性好，但字段名重复、体积较大。

---

### 4.3 Fastjson2

| 适用 | 不适用 |
|------|--------|
| 高 QPS JSON 服务 | 安全要求极高的公网反序列化（需谨慎配置） |
| 内部系统接口、Redis JSON 序列化 |  |

**原因**：高性能 Reader/Writer、优化路径多，比 Jackson 快，但生态标准仍是 Jackson，安全历史需注意。

---

### 4.4 Kryo（高性能 Java 内部二进制）

| 适用 | 不适用 |
|------|--------|
| Redis 高性能缓存（对象 → byte[]） | 跨语言 |
| Spark / Flink 等分布式计算对象传输 | 长期存储（类结构变动风险大） |
| 内部 Java RPC、本地内存持久化 |  |

**原因**：不写 class descriptor、可注册类→小整数 ID、Output/Input 紧凑、可选引用跟踪 → 小、快，但强依赖类定义。

---

### 4.5 Protobuf（微服务 / RPC 首选）

| 适用 | 不适用 |
|------|--------|
| 微服务 RPC（gRPC 标准） | 直接存复杂对象图 |
| 跨语言系统（Java / Go / Python / C++） | 无 schema 管理能力的团队 |
| 高性能网关、移动端 API |  |

**原因**：tag 编码、CodedOutputStream、生成代码、不存字段名 → 小、快、强 schema 版本兼容。

---

### 4.6 Avro（数据管道 / Kafka）

| 适用 | 不适用 |
|------|--------|
| Kafka 消息、大数据平台 | 复杂对象模型 |
| 需要 Schema 演进的场景 | 实时高并发 RPC（通常不如 Protobuf） |

**原因**：reader/writer schema 机制专门解决版本演进 → 数据平台常用。

---

### 4.7 MessagePack

| 适用 | 不适用 |
|------|--------|
| 替代 JSON、WebSocket 二进制传输 | 强 schema 系统 |
| 游戏服务器等 |  |

**原因**：JSON 二进制化、无字段名重复、无强 schema → 比 JSON 小、快、跨语言。

---

## 五、工程选型速查

| 场景 | 推荐 |
|------|------|
| Spring Boot REST | Jackson |
| Redis 缓存 | Kryo / JSON |
| 内部 Java RPC | Kryo |
| 微服务跨语言 | Protobuf |
| Kafka | Avro |
| WebSocket 二进制 | MessagePack |
| 本地 Java 持久化 | Kryo |

---

## 六、一句话总结

| 方案 | 定位 |
|------|------|
| **Serializable** | 恢复 Java 对象图 |
| **JSON（Jackson/Fastjson/Gson）** | 交换数据、可读、跨语言 |
| **Kryo** | 快速 Java 内部二进制 |
| **Protobuf** | 跨语言高性能协议 |
| **Avro** | 数据平台 schema 管理 |
| **MessagePack** | 二进制 JSON |

**源码层面的本质区别**：是否写 class descriptor、字段用名字还是 tag 还是顺序、是否原生支持对象图、对象创建方式（反射/构造/生成代码），共同决定了体积、性能、演进能力和适用场景。选型时按“是否跨语言、是否要对象图、是否要极致性能、是否有 schema 管理”对号入座即可。
