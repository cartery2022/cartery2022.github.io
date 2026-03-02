---
title: 设计模式（七）桥接模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 桥接
  - Bridge
  - Spring
categories:
  - 设计模式
  - 结构型
---

# 桥接模式（Bridge）

## 一、模式概述

**桥接模式**将抽象部分与实现部分分离，使它们可以独立变化；通过组合而非继承建立抽象与实现的连接。

**解决的问题**：若用继承扩展“抽象 × 实现”的多种组合，类会爆炸；桥接把“抽象”和“实现”拆成两个维度，用组合组合在一起，各自独立扩展。

**定义**：将抽象与实现解耦，使两者可以独立变化。

---

## 二、结构与角色

- **Abstraction**：抽象部分，持有 Implementor 的引用，业务方法中委托给 implementor。
- **RefinedAbstraction**：对 Abstraction 的扩展。
- **Implementor**：实现部分接口。
- **ConcreteImplementor**：具体实现。

**示例**：

```java
interface Implementor { void operationImpl(); }
class ImplA implements Implementor { public void operationImpl() {} }
class ImplB implements Implementor { public void operationImpl() {} }

abstract class Abstraction {
    protected Implementor impl;
    Abstraction(Implementor impl) { this.impl = impl; }
    abstract void operation();
}
class RefinedAbstraction extends Abstraction {
    RefinedAbstraction(Implementor impl) { super(impl); }
    void operation() { impl.operationImpl(); }
}
// 使用: new RefinedAbstraction(new ImplA()).operation();
```

---

## 三、在 Spring 中的运用

- **JDBC 的 Driver 与 Connection**：`Driver` 是“实现”，`Connection` 是“抽象”；应用代码依赖 `Connection` 接口，不同 Driver 提供不同实现，二者通过 DriverManager/DataSource 桥接，而不是为每种数据库写一个 Connection 子类。
- **数据源与事务管理器**：抽象是“事务界定（声明式事务）”，实现是“具体数据源 + 事务资源管理”；Spring 通过 PlatformTransactionManager 与不同 DataSource 组合，可视为桥接思想。
- **消息抽象与具体 MQ**：JmsTemplate / KafkaTemplate 等是抽象，背后不同 MQ 客户端是实现，可独立替换。

---

## 四、适用业务场景

- **多维度变化**：如“消息类型 × 传输方式”“报表格式 × 数据源”，用继承会导致组合爆炸，用桥接拆成“抽象 + 实现”两维分别扩展。
- **运行时切换实现**：如同一套业务逻辑（抽象）在不同环境用不同数据源或不同协议（实现），通过注入不同 Implementor 完成。
- **跨平台/多驱动**：同一套业务 API，底层是不同驱动或平台实现（如日志 API 对多种日志库、连接 API 对多种数据库）。
- **避免多层继承**：当“抽象子类 × 实现子类”的乘积很大时，用组合桥接替代多重继承。

**不适用**：抽象或实现只有一种或很少变化时，不需要拆成两个维度。

---

## 五、小结

桥接模式通过“抽象持有一个实现接口”把抽象与实现解耦，各自独立扩展；Spring 中 **JDBC Driver/Connection**、**事务管理器与数据源** 体现了这一思想。业务上适用于**多维度变化、运行时切换实现、多驱动/多平台**等场景。
