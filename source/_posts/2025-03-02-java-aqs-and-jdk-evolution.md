---
title: AbstractQueuedSynchronizer（AQS）详解与 JDK 演进
date: 2025-03-02
tags:
  - java
  - AQS
  - AbstractQueuedSynchronizer
  - 并发
  - JUC
categories:
  - Java
  - 并发
---

# AbstractQueuedSynchronizer（AQS）详解与 JDK 演进

本文说明 **AbstractQueuedSynchronizer（AQS）** 的定位、核心结构、独占/共享模式与条件队列，并梳理 **JDK 各版本** 中与 AQS 相关的重要实现变化与缺陷修复（尤其是 **Java 11 起用 VarHandle 管理状态** 及后续维护性更新）。

---

## 一、AQS 是什么

**AQS** 位于 `java.util.concurrent.locks` 包，由 **Doug Lea** 设计，是 JUC 中 **阻塞锁与同步器** 的公共骨架：

- **ReentrantLock**、**ReentrantReadWriteLock**（内部 Sync）
- **Semaphore**
- **CountDownLatch**
- **ThreadPoolExecutor**（Worker 关闭等场景）

等均通过 **继承 AQS** 并实现 `tryAcquire` / `tryRelease`（独占）或 `tryAcquireShared` / `tryReleaseShared`（共享）等钩子，复用 **FIFO 等待队列** 与 **阻塞/唤醒** 逻辑。

**对外**：应用代码通常只用 `Lock`、`Semaphore` 等 API；**AQS 是 `public` 类**，也可被子类扩展实现自定义同步器，但门槛较高。

---

## 二、核心结构

### 2.1 同步状态 state

- **`volatile int state`**：由子类约定语义。
  - **ReentrantLock**：0 表示无主，>0 表示持有次数（可重入）。
  - **Semaphore**：可用许可数。
  - **CountDownLatch**：还剩多少次 countDown。

通过 **`getState()` / `setState()` / `compareAndSetState()`** 读取与原子更新状态（具体底层实现随 JDK 版本演进，见第四节）。

### 2.2 等待队列（CLH 变体）

- **FIFO 双向链表**，节点 `Node` 含：`waitStatus`、`prev`、`next`、`thread` 等。
- **`head` / `tail`** 指向队列头尾（头结点可视为占位，真正等待从其后继开始很常见）。
- 获取失败时线程被封装成 Node **入队**，经自旋后调用 **`LockSupport.park`** 阻塞；释放时 **`unpark`** 后继。

### 2.3 独占与共享

| 模式 | 典型用途 | 模板入口 |
|------|----------|----------|
| **独占（Exclusive）** | 互斥锁 | `acquire` / `release` |
| **共享（Shared）** | 信号量、读锁（阶段） | `acquireShared` / `releaseShared` |

子类实现对应的 **`tryAcquire` / `tryRelease`**** 或 **`tryAcquireShared` / `tryReleaseShared`**，返回是否成功；AQS 负责排队、阻塞与唤醒传播（共享模式下可能连续唤醒多个后继）。

### 2.4 条件队列：ConditionObject

- **`ConditionObject`** 是 AQS 的**内部类**，实现 `Condition`。
- 每个 `Condition` 维护**独立于锁等待队列**的条件单向链表；**`await`** 释放锁并进入条件队列，**`signal`** 将节点移回锁等待队列。
- **`ReentrantLock.newCondition()`** 即基于同一套 AQS 状态与队列框架。

### 2.5 兄弟类：AbstractQueuedLongSynchronizer

若 `int` 状态不够（如大范围计数），JDK 提供 **`AbstractQueuedLongSynchronizer`**：**`long` 型 state** 与相同队列语义，用法与 AQS 平行。

---

## 三、典型 acquire / release 流程（概念）

**独占 `acquire`：**

1. 调用子类 **`tryAcquire`**；成功则结束。
2. 失败则 **构造 Node、入队**，在队列中自旋或 **`park`**。
3. 被 **`release` 唤unpark** 后继续竞争 `tryAcquire`。

**`release`：**

1. 调用子类 **`tryRelease`**；成功则唤醒后继（`unparkSuccessor`）。

**共享模式**还会在释放后做 **传播（propagate）**，使多个等待线程在许可充足时依次通过。

（具体源码分支、中断、取消 `CANCELLED` 节点清理等细节较长，本文不展开到每一行。）

---

## 四、JDK 演进：AQS「之后的变化」

对外 API（`acquire` / `release` / `Condition` 等）**长期保持稳定**；变化主要集中在 **状态的原子实现**、**队列/中断/取消** 的健壮性与微优化。

### 4.1 Java 8 及更早

- 使用 **Unsafe** 或底层原子原语对 **`state` 字段**做 CAS（`compareAndSwapInt` 等）。
- AQS 框架形态已是：**state + CLH 风格队列 + `LockSupport`**。

### 4.2 Java 11：**VarHandle 重写状态访问（重要）**

- **`compareAndSetState` / `getState` / `setState`** 等改为通过 **`java.lang.invoke.VarHandle`** 访问 **`state`**，取代对 **`sun.misc.Unsafe`** 的直接依赖（与 **JDK-8149644** 等变更相关）。
- **语义不变**：仍满足 JMM 对同步器的要求；**子类与 `ReentrantLock` 等公共 API 无需修改**。
- **动机**：更安全、更规范的原子访问 API，便于维护与 JVM 优化；与 **JEP 193（VarHandle）** 路线一致。

### 4.3 Java 12～15 附近：修复与“刷新”

OpenJDK 变更记录中可见多例仅针对 AQS 或其子类交互的缺陷修复，例如：

- **中断与 `tryAcquire` 抛异常** 时的处理（8191937）。
- **cancel 节点** 相关的竞态与队列一致性（8191483）。
- 未持锁就 **await** 导致队列损坏等问题（8187408）。
- **8229442**：对 AQS 与相关 lock 类的一批刷新/整理（实现层，非破坏性 API）。

这些版本**不增加新的 AQS 抽象模式**，而是提高 **正确性与边界行为**。

### 4.4 Java 17～21 及以后

- AQS 作为稳定核心，随 **LTS** 继续接受小修复与性能相关微调（以各版本 **Release Notes / JDK Issue** 为准）。
- **虚拟线程（Java 21）**：阻塞在 `LockSupport.park` 上的锁等待路径与虚拟线程调度模型配合；**`synchronized`** 在早期虚拟线程上易产生 **pin**，而 **基于 AQS 的 `ReentrantLock`** 常作为替代讨论对象——这是**使用侧**的架构选择，不一定改变 AQS 类签名，但说明了 AQS 在运行时仍承担大量阻塞同步。

### 4.5 小结表

| 阶段 | AQS 相关变化要点 |
|------|------------------|
| **≤ JDK 10** | `state` 多通过 Unsafe 类原子操作 |
| **JDK 11** | **`state` 通过 VarHandle** 更新；对齐标准 JMM API |
| **JDK 12+** | 以 **bugfix、队列/中断一致性、微调** 为主 |
| **JDK 21+** | 与 **虚拟线程** 生态协同；AQS 仍是 JUC 锁/同步器底座 |

---

## 五、学习与实践建议

1. 读源码时抓住 **`acquire` / `release`** 与 **`Node.waitStatus`** 两条线，再看 **条件队列** `ConditionObject`。
2. 自定义同步器优先评估是否可用 **`Semaphore` / `ReentrantLock`** 组合替代，**直接继承 AQS** 需严谨处理 **`tryRelease` 的返回值与 state 含义**。
3. 关注 **JDK 发行说明** 与 **JDK Bug System** 中带 `AbstractQueuedSynchronizer` 的条目，可获知具体版本行为修复。

---

## 六、小结

**AbstractQueuedSynchronizer** 用 **`volatile int state` + FIFO 等待队列 + LockSupport** 统一实现阻塞式同步；**独占/共享**与 **Condition** 覆盖大部分 JUC 锁与门闩类。**JDK 11** 起用 **VarHandle** 管理 **`state`**，是 **Java 8 之后最明显的实现层变化**；其后版本以**正确性修复与细节优化**为主，公共模板 API 保持稳定。理解 AQS 有助于深入掌握 **Java 并发与锁实现**。
