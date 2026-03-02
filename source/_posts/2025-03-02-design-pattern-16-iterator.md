---
title: 设计模式（十六）迭代器模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 迭代器
  - Iterator
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 迭代器模式（Iterator）

## 一、模式概述

**迭代器模式**提供一种顺序访问聚合对象元素的方法，且不暴露其内部表示。

**解决的问题**：聚合结构（列表、树、图）的遍历方式多样（顺序、逆序、过滤等），若在聚合内部写死会违反单一职责；把遍历逻辑抽到迭代器中，聚合只负责存储，迭代器负责“如何遍历”。

**定义**：提供一种方法顺序访问聚合对象中的元素，而又不暴露其内部表示。

---

## 二、结构与角色

- **Iterator**：迭代器接口，定义 hasNext()、next() 等。
- **ConcreteIterator**：具体迭代器，持有聚合的引用或内部状态，实现遍历逻辑。
- **Aggregate**：聚合接口，定义 createIterator()。
- **ConcreteAggregate**：具体聚合，实现 createIterator() 返回对应迭代器。

**示例**：

```java
interface Iterator<T> {
    boolean hasNext();
    T next();
}
interface Aggregate<T> {
    Iterator<T> iterator();
}
class ListAggregate<T> implements Aggregate<T> {
    private final List<T> list = new ArrayList<>();
    public Iterator<T> iterator() {
        return new ListIterator<>(list);
    }
}
```

Java 的 `java.util.Iterator` 与 `Iterable` 已是语言级支持。

---

## 三、在 Spring 中的运用

- **集合的迭代**：Spring 大量使用 `Collection`、`Iterable`、`Iterator` 遍历 Bean 列表、Resource 列表等；与 JDK 一致，不单独实现迭代器接口，但“通过迭代器访问聚合”的思想一致。
- **Resource 的 getInputStream / 遍历**：如 `Resource[]`、多位置资源时，通过迭代或 Stream 顺序访问，不暴露底层存储结构。
- **Bean 定义、属性等的遍历**：BeanDefinition 的 property、constructor-arg 等，通过迭代方式访问，内部结构可变化。
- **Spring Data 的 Page/Slice**：分页结果实现 `Iterable`，可用 for-each 或 Iterator 遍历，隐藏分页拉取细节。

---

## 四、适用业务场景

- **统一遍历多种集合**：列表、树、图用同一“迭代器”接口遍历，调用方不关心底层是数组还是链表。
- **惰性遍历/流式**：迭代器按需取下一个元素，适合大集合或“无限”序列，不必一次性加载到内存。
- **多种遍历方式**：同一聚合提供“正序迭代器”“逆序迭代器”“过滤迭代器”等，满足不同遍历需求。
- **封装内部结构**：聚合内部从数组改为链表，只要迭代器接口不变，调用方无需修改。

**不适用**：简单数组/列表一次性遍历、且无多种遍历方式需求时，直接 for/forEach 即可。

---

## 五、小结

迭代器模式通过“迭代器接口 + 聚合提供迭代器”解耦遍历与存储；Java 与 Spring 中 **Iterator/Iterable**、**集合与 Resource 的遍历**、**Spring Data 分页** 都体现了该思想。业务上适用于**统一遍历多种结构、惰性/流式遍历、多种遍历方式、封装内部结构**等场景。
