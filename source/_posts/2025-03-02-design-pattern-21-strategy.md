---
title: 设计模式（二十一）策略模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 策略
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 策略模式（Strategy）

## 一、模式概述

**策略模式**定义一系列算法，将每个算法封装起来并使它们可互换；策略使算法独立于使用它的客户而变化。

**解决的问题**：同一类问题有多种解法（如多种排序、多种支付、多种校验），若用 if-else 堆砌会难以扩展；把每种解法抽成独立策略类，客户依赖策略接口，运行时注入不同实现即可切换。

**定义**：定义一系列算法，把它们一个个封装起来，并且使它们可以相互替换；策略模式使算法独立于使用它的客户。

---

## 二、结构与角色

- **Strategy**：策略接口，定义算法方法（如 execute(data)）。
- **ConcreteStrategy**：具体策略，实现不同算法。
- **Context**：上下文，持有 Strategy，将客户请求委托给当前策略；可在构造或 setter 中注入策略。

**示例**：

```java
interface Strategy { int compute(int a, int b); }
class Add implements Strategy {
    public int compute(int a, int b) { return a + b; }
}
class Multiply implements Strategy {
    public int compute(int a, int b) { return a * b; }
}
class Context {
    private Strategy strategy;
    public void setStrategy(Strategy s) { this.strategy = s; }
    public int execute(int a, int b) { return strategy.compute(a, b); }
}
```

---

## 三、在 Spring 中的运用

- **ResourceLoader / 资源加载策略**：根据 URL 前缀（file:、classpath:、http:）选择不同 Resource 实现，可视为“按前缀选择加载策略”；Spring 内置多种 Resource 实现，由 ResourceLoader 路由。
- **AOP 代理策略**：JdkDynamicAopProxy 与 Cglib2AopProxy 是两种“生成代理”的策略，根据目标是否实现接口选择其一。
- **PlatformTransactionManager 与具体实现**：事务管理是抽象，DataSourceTransactionManager、HibernateTransactionManager 等是不同策略，由配置或自动装配决定使用哪种。
- **MessageConverter**：HTTP 消息的序列化/反序列化有多种策略（JSON、XML 等），根据 Content-Type 或配置选择不同 Converter。
- **CacheManager**：缓存抽象，Redis、Caffeine、Simple 等是不同策略，通过配置切换。

---

## 四、适用业务场景

- **多种算法/规则可替换**：如支付（微信/支付宝/银联）、运费计算（按重量/按体积/固定）、折扣（满减/会员价/券），每种一种策略，便于新增与测试。
- **多数据源/多协议**：根据配置或路由键选择不同数据源、不同 RPC 协议，客户只依赖“获取连接/发请求”的接口。
- **多格式解析/序列化**：同一业务数据支持 JSON/XML/二进制等多种格式，每种格式一个策略。
- **多验证规则**：校验逻辑有多种（格式、黑名单、风控），可组合或按场景选不同策略。
- **多通知渠道**：发送通知支持短信/邮件/站内信/推送，每种渠道一个策略，由配置或业务选择。

**不适用**：算法唯一或很少变化时，直接实现即可。

---

## 五、小结

策略模式通过“策略接口 + 多种实现 + 上下文委托”使算法可替换、易扩展；Spring 中 **ResourceLoader**、**AOP 代理选择**、**事务管理器**、**MessageConverter**、**CacheManager** 都是策略思想的体现。业务上适用于**多种支付/计算/校验、多数据源/多协议、多格式、多通知渠道**等场景。
