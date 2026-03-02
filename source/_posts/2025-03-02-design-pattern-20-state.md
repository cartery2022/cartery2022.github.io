---
title: 设计模式（二十）状态模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 状态
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 状态模式（State）

## 一、模式概述

**状态模式**允许对象在内部状态改变时改变其行为，对象看起来像是修改了类。

**解决的问题**：当对象行为依赖多种状态且不同状态下行为差异大时，若用大量 if-else/switch 会难以维护；把“每种状态”封装成独立类，状态转换时切换当前状态对象，行为随状态对象变化。

**定义**：允许一个对象在其内部状态改变时改变它的行为，对象看起来修改了它的类。

---

## 二、结构与角色

- **Context**：上下文，持有当前 State，客户请求委托给当前 state 处理；可提供 setState() 供状态类切换状态。
- **State**：抽象状态，定义行为接口（如 handle()）。
- **ConcreteState**：具体状态，实现行为，并在适当时机调用 context.setState(nextState) 切换状态。

**示例**：

```java
interface State { void handle(Context ctx); }
class Context {
    private State state;
    public void setState(State s) { this.state = s; }
    public void request() { state.handle(this); }
}
class ConcreteStateA implements State {
    public void handle(Context ctx) {
        // 处理并可能切换
        ctx.setState(new ConcreteStateB());
    }
}
```

---

## 三、在 Spring 中的运用

- **Spring State Machine**：spring-statemachine 库显式支持状态机建模，状态与迁移由配置或代码定义，事件驱动迁移，是状态模式的完整实现；适用于订单、工作流、审批等有明确状态与迁移的场景。
- **Bean 生命周期**：Bean 的创建、初始化、运行、销毁等可视为不同“状态”，容器在不同状态下执行不同逻辑（如 PostProcessor、InitializingBean），可抽象为状态思想。
- **连接/会话状态**：如 TCP 连接、WebSocket 会话的“未连接/已连接/关闭中/已关闭”，用状态对象封装各阶段行为与迁移条件。
- **事务状态**：事务管理器内部有“无事务/活跃/提交中/回滚中”等状态，行为（提交、回滚、挂起）随状态变化。

---

## 四、适用业务场景

- **订单/工单/审批流**：待支付、已支付、发货中、已完成、已取消等，每状态下可执行的操作与下一状态不同，用状态模式（或状态机）清晰建模。
- **游戏/动画**：角色“待机/跑/攻击/受伤”等，每状态对应不同动画与输入响应，切换状态即切换行为。
- **连接/会话管理**：连接建立、认证、传输、关闭等阶段，每阶段允许的操作与错误处理不同。
- **UI 控件**：按钮“正常/禁用/加载中”，不同状态下点击行为、样式不同。
- **协议解析**：解析器处于“读头/读体/读尾”等状态，收到数据时根据当前状态决定如何处理与迁移。

**不适用**：状态很少、行为差异不大时，简单分支即可。

---

## 五、小结

状态模式通过“状态即对象 + 行为委托给当前状态 + 状态间迁移”消除复杂分支；Spring 中 **Spring State Machine**、**Bean 生命周期**、**连接/事务状态** 有体现。业务上适用于**订单/工作流、游戏/动画、连接/会话、UI 状态、协议解析**等场景。
