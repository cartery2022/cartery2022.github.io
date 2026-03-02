---
title: 设计模式（十七）中介者模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 中介者
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 中介者模式（Mediator）

## 一、模式概述

**中介者模式**用一个中介对象封装一系列对象交互，使各对象不需要显式相互引用，从而降低耦合。

**解决的问题**：多个对象之间两两通信会导致关系网状化、难以维护；引入中介者后，对象只与中介者通信，由中介者协调多方，结构变为星形。

**定义**：用一个中介对象封装一系列对象交互；中介者使各对象不需要显式相互引用，从而使其耦合松散。

---

## 二、结构与角色

- **Mediator**：中介者接口，定义与各 Colleague 通信的方法（如 send(message, from)）。
- **ConcreteMediator**：具体中介者，持有所有 Colleague 的引用，实现协调逻辑，负责把消息路由到目标 Colleague。
- **Colleague**：同事类，各 Colleague 只依赖 Mediator，不直接引用其他 Colleague；需要通知他人时调用 mediator.send()。

**示例**：

```java
interface Mediator {
    void send(String msg, Colleague from);
}
class ConcreteMediator implements Mediator {
    private Colleague a, b;
    public void setColleagues(Colleague a, Colleague b) { this.a = a; this.b = b; }
    public void send(String msg, Colleague from) {
        if (from == a) b.receive(msg); else a.receive(msg);
    }
}
abstract class Colleague {
    protected Mediator mediator;
    Colleague(Mediator m) { this.mediator = m; }
    abstract void receive(String msg);
}
```

---

## 三、在 Spring 中的运用

- **MVC 中的 Controller**：Controller 作为“中介”，接收请求后协调 Model（服务/数据）与 View（渲染）；不直接让 View 与 Model 互相引用，降低耦合。
- **事件与 ApplicationEventMulticaster**：多个监听器与事件发布者不直接引用，通过 ApplicationContext（或 Multicaster）作为中介广播事件，监听器只订阅“某类事件”。
- **消息中间件**：MQ 作为中介，生产者与消费者不直接引用，通过 Topic/Queue 通信，可视为“消息中介者”。
- **网关/API 网关**：网关作为中介，协调认证、路由、限流与后端服务，各服务不直接互调。

---

## 四、适用业务场景

- **多对象需协调**：如“订单创建”涉及库存、支付、消息、积分等多模块，由“订单服务”或“领域协调器”作为中介，统一调用各模块，模块之间不直接依赖。
- **聊天室/协作**：多个用户/组件只与“房间”或“会话”通信，由中介者把消息分发给其他人。
- **表单/UI 组件联动**：多个输入框、下拉框相互联动（如省市区、品类与规格），由表单中介者统一处理变更并更新其他组件。
- **工作流/审批流**：节点之间不直接引用，由流程引擎作为中介推进流程、分配任务。

**不适用**：对象之间关系简单、只有一对一或少量交互时，不必引入中介者。

---

## 五、小结

中介者模式通过“中介者集中协调、同事只依赖中介者”将网状交互变为星形；Spring 中 **MVC Controller**、**事件广播**、**消息/网关** 体现了中介思想。业务上适用于**多对象协调、聊天/协作、表单联动、工作流**等场景。
