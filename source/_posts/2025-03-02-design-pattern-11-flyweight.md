---
title: 设计模式（十一）享元模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 享元
  - Flyweight
  - Spring
categories:
  - 设计模式
  - 结构型
---

# 享元模式（Flyweight）

## 一、模式概述

**享元模式**运用共享技术有效支持大量细粒度对象的复用，减少内存与对象数量。

**解决的问题**：存在大量相似对象（如相同字符、相同图标、相同配置），若每个都单独实例会占用大量内存；把“可共享的内在状态”与“不可共享的外在状态”分离，共享内在状态，外在状态由调用方传入。

**定义**：运用共享技术有效地支持大量细粒度的对象。

---

## 二、结构与角色

- **Flyweight**：享元接口，定义对外方法，方法参数中常包含“外在状态”。
- **ConcreteFlyweight**：具体享元，存储内在状态（可共享），方法中结合传入的外在状态完成行为。
- **FlyweightFactory**：享元工厂，维护享元池，根据 key 返回共享实例；无则创建并缓存。
- **Client**：使用享元时传入外在状态。

**示例**：

```java
interface Flyweight { void operation(String extrinsicState); }
class ConcreteFlyweight implements Flyweight {
    private final String intrinsicState;
    ConcreteFlyweight(String intrinsicState) { this.intrinsicState = intrinsicState; }
    public void operation(String extrinsicState) {
        System.out.println(intrinsicState + ", " + extrinsicState);
    }
}
class FlyweightFactory {
    private final Map<String, Flyweight> pool = new HashMap<>();
    Flyweight get(String key) {
        return pool.computeIfAbsent(key, ConcreteFlyweight::new);
    }
}
```

---

## 三、在 Spring 中的运用

- **String 常量池、Integer 缓存**：JVM/JDK 层面的“享元”，相同内容的 String、小范围 Integer 共享实例；Spring 未单独实现，但业务中大量用 String 作为 key、缓存 key 时天然受益。
- **Bean 单例**：单例 Bean 在容器内共享，可视为“按 Bean 定义共享的实例”，与享元“按 key 共享”思想一致。
- **元数据、配置的缓存**：如反射得到的 Method、Annotation 等元数据，Spring 会缓存复用，避免重复解析；可视为“按类/方法等 key 的享元”。
- **线程池、连接池**：池中的线程、连接是“可复用对象”，与享元“复用对象”的目标一致，只是通常不叫 Flyweight 名字。

---

## 四、适用业务场景

- **大量相似对象且可区分内在/外在**：如棋牌游戏中“牌面”可共享（内在），每张牌的“位置、归属”由外部传入（外在）；文档编辑器中“字符样式”共享，“位置”外在。
- **缓存、池化**：按 key 缓存对象（如按配置 key 缓存解析结果），无则创建并放入池，有则直接返回，本质是享元工厂。
- **减少重复解析/编译**：如模板引擎中相同模板只编译一次；规则引擎中相同规则只编译一次，运行时只传不同参数。
- **枚举、常量类**：有限个实例对应有限个“内在状态”，全应用共享，是享元的简化形式。

**不适用**：对象之间几乎没有可共享状态、或对象数量很少时，享元收益不大。

---

## 五、小结

享元模式通过“内在状态共享 + 外在状态参数化”减少对象数量与内存；Spring 中 **单例 Bean**、**元数据缓存**、**池化** 体现了共享复用思想。业务上适用于**大量相似对象、缓存/池化、减少重复解析/编译、枚举/常量**等场景。
