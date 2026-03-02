---
title: 设计模式（八）组合模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 组合
  - Spring
categories:
  - 设计模式
  - 结构型
---

# 组合模式（Composite）

## 一、模式概述

**组合模式**将对象组合成树形结构以表示“部分-整体”的层次结构，使客户对单个对象和组合对象的使用具有一致性。

**解决的问题**：树形结构中的节点有的是“叶子”有的是“容器”，希望客户代码不用区分，统一用同一接口（如 `operation()`）处理。

**定义**：将对象组合成树形结构表示“部分-整体”层次，使得客户对单个对象和组合对象的使用具有一致性。

---

## 二、结构与角色

- **Component**：抽象组件，定义叶子与组合的公共接口（如 `operation()`），可选地定义管理子节点的接口（add/remove/getChild）。
- **Leaf**：叶子节点，无子节点。
- **Composite**：组合节点，持有子 Component 集合，实现 `operation()` 时通常遍历子节点并调用其 `operation()`。

**示例**：

```java
interface Component {
    void operation();
}
class Leaf implements Component {
    public void operation() { System.out.println("Leaf"); }
}
class Composite implements Component {
    private final List<Component> children = new ArrayList<>();
    public void add(Component c) { children.add(c); }
    public void operation() {
        for (Component c : children) c.operation();
    }
}
```

---

## 三、在 Spring 中的运用

- **CompositeCacheManager**：将多个 `CacheManager` 组合成一个，按名称路由到不同 CacheManager，对外表现为一个 CacheManager，是典型的“组合对象”。
- **Bean 定义中的嵌套**：如父子 Bean 定义、嵌套的 `<list>`/`<map>` 配置，结构上是树形，解析时用组合思想处理。
- **MyBatis 动态 SQL**：`<if>/<choose>/<foreach>` 等组合成一棵 SQL 节点树，统一通过 `apply()` 或类似方法求值，可视为组合模式。
- **组织架构、菜单树**：若在业务中建模“部门-子部门”“菜单-子菜单”，用组合模式可统一对单节点和子树的操作。

---

## 四、适用业务场景

- **树形结构且需统一操作**：如菜单、权限树、组织架构、目录-文件，对“节点”和“子树”执行同一类操作（渲染、权限检查、汇总）。
- **多级配置/规则**：如配置有“全局 → 应用 → 模块”的覆盖关系，用组合表示层级，统一按层级解析。
- **表达式或 AST**：如简单表达式解析成树，叶子是常量/变量，组合节点是运算符，统一 `evaluate()`。
- **多 CacheManager / 多数据源的路由**：对外一个入口，内部按 key 或规则分发到多个子组件，对外表现为一个整体。

**不适用**：结构不是树形、或叶子与容器行为差异很大无需统一接口时。

---

## 五、小结

组合模式通过“叶子与组合实现同一接口 + 组合内部委托子节点”统一处理树形结构；Spring 中 **CompositeCacheManager**、**Bean 定义嵌套**、**动态 SQL 节点树** 有体现。业务上适用于**菜单/权限/组织树、多级配置、表达式/AST、多子组件路由**等场景。
