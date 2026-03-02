---
title: 设计模式（十八）备忘录模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 备忘录
  - Memento
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 备忘录模式（Memento）

## 一、模式概述

**备忘录模式**在不破坏封装的前提下捕获对象的内部状态，并在对象之外保存该状态，以便之后恢复。

**解决的问题**：需要保存/恢复对象某一时刻的状态（如撤销、快照、回放），又不希望把内部状态直接暴露给外部；通过“备忘录”对象保存状态，由原发者自己写入与读出。

**定义**：在不破坏封装性的前提下捕获对象的内部状态，并在对象之外保存这个状态，以便之后恢复。

---

## 二、结构与角色

- **Originator**：原发者，产生需要保存的状态，可 createMemento() 生成备忘录，也可 restore(memento) 从备忘录恢复。
- **Memento**：备忘录，存放 Originator 的内部状态；通常只由 Originator 读写，对外可只暴露给 Caretaker 存储而不暴露内容。
- **Caretaker**：负责人，持有 Memento，不操作其内容，只负责“保存”和“交给 Originator 恢复”。

**示例**：

```java
class Memento {
    private final String state;
    Memento(String state) { this.state = state; }
    String getState() { return state; }
}
class Originator {
    private String state;
    public Memento save() { return new Memento(state); }
    public void restore(Memento m) { this.state = m.getState(); }
}
class Caretaker {
    private Memento memento;
    public void save(Memento m) { this.memento = m; }
    public Memento get() { return memento; }
}
```

---

## 三、在 Spring 中的运用

- **Spring Web Flow 状态管理**：流程状态（如 conversation、flow 的 snapshot）被保存以便恢复、回退，可视为“流程的备忘录”；状态存储在 session 或存储中，由框架管理。
- **会话/请求级状态**：如“草稿”“多步表单的已填数据”，保存为某种 Memento 结构（如 Map、DTO），在提交前可恢复或重填。
- **事务的 savepoint**：数据库 savepoint 相当于“事务状态的备忘录”，可回滚到某一点。
- **快照/版本**：实体保存历史版本（如文档版本、配置版本），需要时恢复到某一版本，本质是“状态的备忘录 + 恢复”。

---

## 四、适用业务场景

- **撤销/重做**：编辑器中每步操作前保存 Memento，撤销时 restore；命令模式常与备忘录结合（命令里保存执行前状态以便 undo）。
- **草稿/自动保存**：表单或文档定期把当前状态保存为 Memento，崩溃或关闭后可恢复。
- **多步 wizard 的回退**：每步完成后保存当前步骤与数据，用户可回到上一步并恢复当时状态。
- **快照与回滚**：配置、脚本、虚拟机等做快照，出问题后回滚到某快照。
- **游戏存档**：把角色/场景状态序列化为 Memento 存盘，读档时 restore。

**不适用**：状态简单、无需恢复或只需简单“重算”即可得到历史状态时，不必引入 Memento。

---

## 五、小结

备忘录模式通过“原发者生成/恢复 Memento + Caretaker 只负责存储”实现状态保存与恢复且不破坏封装；Spring 中 **Web Flow 状态**、**会话/草稿**、**savepoint** 有体现。业务上适用于**撤销重做、草稿/自动保存、wizard 回退、快照/回滚、存档**等场景。
