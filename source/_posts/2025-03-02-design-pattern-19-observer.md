---
title: 设计模式（十九）观察者模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 观察者
  - Observer
  - Spring
  - 事件
categories:
  - 设计模式
  - 行为型
---

# 观察者模式（Observer）

## 一、模式概述

**观察者模式**定义对象间的一对多依赖，当一个对象状态改变时，其所有依赖者都会收到通知并自动更新。

**解决的问题**：一个主题（被观察者）状态变化时，需要通知多个订阅者且不与之强耦合；主题只负责发布“我变了”，观察者自行订阅与处理。

**定义**：定义对象间的一种一对多依赖关系，使得每当一个对象状态发生改变时，其相关依赖对象皆得到通知并自动更新。

---

## 二、结构与角色

- **Subject**：主题，维护观察者列表，提供 attach/detach，状态变化时 notify 所有观察者。
- **Observer**：观察者接口，定义 update()（或 onEvent），供主题调用。
- **ConcreteSubject**：具体主题，状态改变时调用 notify。
- **ConcreteObserver**：具体观察者，实现 update() 以响应通知。

**示例**：

```java
interface Observer { void update(String state); }
class Subject {
    private final List<Observer> observers = new ArrayList<>();
    private String state;
    public void attach(Observer o) { observers.add(o); }
    public void setState(String state) {
        this.state = state;
        observers.forEach(o -> o.update(state));
    }
}
```

---

## 三、在 Spring 中的运用

- **Spring 事件机制**：`ApplicationEventPublisher.publishEvent(event)` 发布事件，实现 `ApplicationListener<E>` 或使用 `@EventListener` 的 Bean 作为观察者被自动调用；主题是 ApplicationContext（或事件发布者），观察者是各 Listener。
- **ContextRefreshedEvent、RequestHandledEvent 等**：容器刷新完成、请求处理完毕等生命周期节点发布事件，监听器可做初始化、统计、清理等，与核心逻辑解耦。
- **自定义业务事件**：继承 `ApplicationEvent`，在业务中 publish，多个监听器分别处理（发消息、记日志、更新缓存等），是观察者模式的直接应用。
- **@TransactionalEventListener**：在事务提交后等阶段再触发监听器，仍属“事件 → 观察者”模型。

---

## 四、适用业务场景

- **事件驱动、解耦通知**：如“订单支付成功”后需要更新库存、发短信、送积分、记审计，支付模块只发布“支付成功”事件，各处理方订阅即可，支付模块不依赖具体处理逻辑。
- **配置/数据变更通知**：配置中心推送变更，多个服务订阅并刷新本地配置；缓存失效时通知多个节点。
- **UI 与数据同步**：MVC 中 Model 变化后通知 View 更新；前端也常用观察者/订阅发布（如 Rx、EventBus）。
- **日志、监控、审计**：核心业务发布“关键操作”事件，日志/监控/审计监听器统一处理，业务代码不写这些横切逻辑。
- **生命周期钩子**：容器启动/关闭、请求开始/结束发布事件，便于做统一初始化或清理。

**不适用**：通知方与接收方严格一对一、且逻辑稳定不变时，直接调用即可。

---

## 五、小结

观察者模式通过“主题维护观察者列表 + 状态变化时通知”实现一对多解耦；Spring 中 **ApplicationEvent/ApplicationListener**、**@EventListener**、**@TransactionalEventListener** 是典型实现。业务上适用于**事件驱动、配置/缓存通知、UI 同步、日志/监控/审计、生命周期钩子**等场景。
