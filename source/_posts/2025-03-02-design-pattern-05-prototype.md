---
title: 设计模式（五）原型模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 原型
  - Prototype
  - Spring
categories:
  - 设计模式
  - 创建型
---

# 原型模式（Prototype）

## 一、模式概述

**原型模式**用原型实例指定创建对象的种类，并通过复制该原型创建新对象。

**解决的问题**：当直接 new 成本高（如构造需大量计算或 I/O），或希望基于已有对象“复制一份再改”时，通过克隆避免重复初始化。

**定义**：用原型实例指定创建对象的种类，并且通过拷贝这些原型创建新的对象。

---

## 二、结构与实现

- **Prototype**：声明克隆方法的接口（Java 中常用 `Cloneable` + `clone()`）。
- **ConcretePrototype**：实现克隆逻辑；浅拷贝直接复制字段，深拷贝需递归复制引用类型。

**示例（浅拷贝）**：

```java
public class Document implements Cloneable {
    private String title;
    private List<String> paragraphs;
    @Override
    public Document clone() {
        try {
            return (Document) super.clone(); // 浅拷贝，paragraphs 仍共享引用
        } catch (CloneNotSupportedException e) {
            throw new RuntimeException(e);
        }
    }
}
```

深拷贝可重写 `clone()` 中对 `paragraphs` 等集合做 new 并复制元素，或使用序列化/拷贝构造器等方式。

---

## 三、在 Spring 中的运用

- **Bean 的 scope="prototype"**：每次 `getBean()` 或注入时，容器都会**新建一个实例**，相当于“根据 Bean 定义这一‘原型’复制出新对象”；与单例的“只一份”相对。
- **ObjectFactory / Provider 注入**：获取 prototype Bean 时，通过 `ObjectFactory<T>` 或 `Provider<T>` 延迟获取，每次 `getObject()` 得到新实例，避免单例 Bean 持有 prototype 导致只拿到同一实例的问题。
- **Bean 的创建过程**：容器内部根据 BeanDefinition 创建实例，可视为“按定义原型创建”，但一般不直接实现 `Cloneable`，而是反射/构造器创建。

---

## 四、适用业务场景

- **创建成本高、状态可复制**：如大对象初始化慢，或从模板复制后只改少量字段（如合同、工单从模板生成）。
- **需要隔离实例状态**：如每次请求/会话需要独立对象，避免线程或请求间共享导致并发问题，Spring 中对应 **prototype 作用域**。
- **撤销/重做、快照**：保存当前状态的一份拷贝，后续可恢复或对比（需深拷贝以保证一致性）。
- **缓存与模板**：从缓存中的“模板对象”克隆出一份再填充数据，避免污染模板。

**不适用**：对象无状态或创建成本很低时，用 new 或工厂即可；深拷贝成本高或引用关系复杂时需权衡。

---

## 五、小结

原型模式通过“克隆已有对象”创建新对象，避免重复昂贵初始化；Spring 中 **prototype 作用域** 与 **ObjectFactory/Provider** 体现了“按需创建新实例”的思想。业务上适用于**高创建成本、需实例隔离、模板复制、快照/撤销**等场景。
