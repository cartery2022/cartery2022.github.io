---
title: 设计模式（十二）代理模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 代理
  - Proxy
  - Spring
  - AOP
categories:
  - 设计模式
  - 结构型
---

# 代理模式（Proxy）

## 一、模式概述

**代理模式**为对象提供代理，由代理控制对原对象的访问；客户通过代理间接访问目标，代理可在访问前后增加逻辑（权限、日志、事务等）。

**解决的问题**：不修改目标类的前提下，增加访问控制、延迟加载、增强逻辑等。

**常见实现**：静态代理（手写代理类）、JDK 动态代理（基于接口）、CGLIB 动态代理（基于子类）。Spring AOP 默认“有接口用 JDK 动态代理，无接口用 CGLIB”。

---

## 二、结构与角色

- **Subject**：抽象主题，目标与代理的共同接口。
- **RealSubject**：真实主题，被代理对象。
- **Proxy**：代理，实现 Subject，持有 RealSubject（或通过工厂/延迟创建），在请求前后执行附加逻辑后转发给 RealSubject。

**示例（静态代理）**：

```java
interface Subject { void request(); }
class RealSubject implements Subject {
    public void request() { System.out.println("real"); }
}
class Proxy implements Subject {
    private final RealSubject target = new RealSubject();
    public void request() {
        System.out.println("before");
        target.request();
        System.out.println("after");
    }
}
```

---

## 三、在 Spring 中的运用

- **AOP 与 @Transactional**：对 Bean 方法做事务、日志、权限等增强时，Spring 为 Bean 创建代理（JDK 或 CGLIB），调用方拿到的是代理对象，方法调用经代理再落到目标方法，是代理模式的直接应用。
- **ProxyFactoryBean**：显式配置 AOP 代理时，通过 ProxyFactoryBean 指定目标与切面，由它生成代理 Bean。
- **远程调用 / RPC**：客户端拿到的“服务接口”实现实为代理，代理将调用序列化后发到服务端，结果反序列化返回，对调用方透明。
- **懒加载 / Lazy**：部分场景下注入的是“懒代理”，首次使用时才初始化真实对象。

---

## 四、适用业务场景

- **横切关注点**：事务、日志、权限、限流、异常转换等，用代理统一加在方法调用前后，不改业务类。
- **远程/跨进程调用**：本地接口的“实现”是代理，负责序列化、网络调用、反序列化。
- **访问控制**：只允许通过代理访问敏感资源，代理中做鉴权、审计。
- **延迟加载**：大对象或昂贵资源，首次使用时通过代理触发加载。
- **缓存**：代理在调用前查缓存，命中则返回，未命中再调目标并回填缓存。

**不适用**：无增强需求、无访问控制或远程需求时，直接依赖真实对象即可。

---

## 五、小结

代理模式通过“代理与目标同一接口 + 代理控制访问并增强”在不改目标的前提下扩展行为；Spring 中 **AOP/@Transactional**、**ProxyFactoryBean**、**远程代理** 是典型应用。业务上适用于**横切关注点、远程调用、访问控制、延迟加载、缓存**等场景。
