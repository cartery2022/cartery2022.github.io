---
title: 设计模式（二十三）访问者模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 访问者
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 访问者模式（Visitor）

## 一、模式概述

**访问者模式**将作用于某对象结构中的各元素的操作封装成访问者，可在不改变各元素类的前提下定义作用于这些元素的新操作。

**解决的问题**：对象结构（如 AST、组合结构）稳定，但需要经常增加“对结构中元素的新操作”；若把操作写在每个元素里会导致元素类不断修改；访问者把“操作”从元素中抽离，每种操作一个 Visitor，元素只负责 accept(visitor) 并委托 visitor.visit(this)。

**定义**：表示一个作用于某对象结构中的各元素的操作；可以在不改变各元素类的前提下定义作用于这些元素的新操作。

---

## 二、结构与角色

- **Visitor**：访问者接口，为结构中每个具体元素声明 visit(ConcreteElement) 方法。
- **ConcreteVisitor**：具体访问者，实现每个 visit 方法，即“对某类元素做某种操作”的具体逻辑。
- **Element**：元素接口，声明 accept(Visitor)。
- **ConcreteElement**：具体元素，accept 中调用 visitor.visit(this)，把自身交给访问者处理。
- **ObjectStructure**：对象结构，持有一组 Element，可提供“遍历并 accept 某 visitor”的入口。

**示例**：

```java
interface Element { void accept(Visitor v); }
interface Visitor {
    void visit(ElementA a);
    void visit(ElementB b);
}
class ElementA implements Element {
    public void accept(Visitor v) { v.visit(this); }
}
class ElementB implements Element {
    public void accept(Visitor v) { v.visit(this); }
}
class ConcreteVisitor implements Visitor {
    public void visit(ElementA a) { /* 对 A 的操作 */ }
    public void visit(ElementB b) { /* 对 B 的操作 */ }
}
```

---

## 三、在 Spring 中的运用

- **BeanDefinitionVisitor**：遍历 BeanDefinition 中的属性、构造参数等“元素”，对其中引用的字符串、值做访问（如解析占位符、计算），可视为“对 BeanDefinition 结构的访问者”。
- **元数据访问**：对类、方法、字段上的注解做“扫描”“校验”“生成配置”等不同操作时，每种操作可对应一个访问者，遍历元数据并 accept。
- **AST / 表达式树**：若用树表示表达式或 DSL，对树的“求值”“打印”“优化”等不同操作可用不同 Visitor 实现，Spring 的 SpEL 等内部有类似结构。
- **序列化/反序列化**：对对象图的“遍历并序列化”可抽象为访问者，不同格式（JSON/XML）对应不同 Visitor。

---

## 四、适用业务场景

- **稳定结构 + 多变操作**：如语法树、DOM、组合树，结构稳定，但需要“类型检查”“格式化”“求值”“翻译”等多种操作，每种操作一个 Visitor，便于新增操作而不改节点类。
- **报表/统计**：对同一批数据做“汇总”“导出 Excel”“导出 PDF”等，数据视为元素，每种导出方式一个 Visitor。
- **编译器/解释器**：AST 的语义分析、代码生成、优化等，各阶段可视为不同访问者遍历同一棵 AST。
- **差异/合并**：比较两棵结构（如配置树、文档树），可对其中一棵用“比较访问者”（另一棵作为参数）实现 diff/merge。
- **序列化/遍历对象图**：按固定顺序遍历对象图并做不同处理（序列化、拷贝、校验），可用访问者封装“处理逻辑”。

**不适用**：结构经常变化（增删节点类型）时，每增加节点类型就要改所有 Visitor，反而麻烦；此时考虑其他方式（如策略+类型分发）。

---

## 五、小结

访问者模式通过“元素 accept(visitor) + visitor.visit(具体元素)”把“对结构的操作”从元素中分离；Spring 中 **BeanDefinitionVisitor**、**元数据扫描/处理**、**AST/表达式处理** 有体现。业务上适用于**稳定结构上的多种操作、报表/导出、编译器/解释器、diff/merge、对象图遍历**等场景。
