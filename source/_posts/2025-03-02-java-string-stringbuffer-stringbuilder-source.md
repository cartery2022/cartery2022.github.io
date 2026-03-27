---
title: String、StringBuffer、StringBuilder 源码解读与 Java 9+ 改动
date: 2025-03-02
tags:
  - java
  - String
  - StringBuilder
  - StringBuffer
  - 源码解读
categories:
  - Java
  - 源码解读
---

# String、StringBuffer、StringBuilder 源码解读与 Java 9+ 改动

本文从 JDK 源码出发，说明 **String**、**StringBuffer**、**StringBuilder** 三者的实现结构、核心逻辑与使用场景，并单独梳理 **Java 9 及以后版本** 对这三类的改动（紧凑字符串、byte[] 存储、字符串拼接编译方式等）。

---

## 一、三者关系与定位

| 类 | 可变性 | 线程安全 | 典型场景 |
|----|--------|----------|----------|
| **String** | 不可变 | 天然线程安全 | 常量、键、单次赋值 |
| **StringBuffer** | 可变 | 同步（synchronized） | 多线程下可变的字符序列 |
| **StringBuilder** | 可变 | 非线程安全 | 单线程下大量拼接、构造字符串 |

**继承关系**：`StringBuffer` 与 `StringBuilder` 都继承 **AbstractStringBuilder**，没有继承关系；`String` 独立实现，与后两者无继承关系。

---

## 二、String 源码解读

### 2.1 内部存储（Java 8 vs Java 9+）

**Java 8 及以前**：

```java
public final class String implements java.io.Serializable, Comparable<String>, CharSequence {
    private final char[] value;   // UTF-16，每字符 2 字节
    private int hash;            // 缓存 hashCode
    // ...
}
```

- 用 **char[]** 存字符，每个 char 为 UTF-16 码元，占 **2 字节**。
- **value 为 final**，引用不变，且对外不暴露可变接口，因此 **String 不可变**。

**Java 9 及以后（JEP 254 Compact Strings）**：

```java
public final class String implements java.io.Serializable, Comparable<String>, CharSequence {
    private final byte[] value;  // 按编码可能是 1 字节/字符 或 2 字节/字符
    private final byte coder;     // 0 = LATIN1，1 = UTF16
    private int hash;
    // ...
}
```

- 改为 **byte[] + coder**：
  - **LATIN1（coder=0）**：仅含 Latin-1 范围内字符时，每字符 **1 字节**，节省约一半内存。
  - **UTF16（coder=1）**：含其它 Unicode 时，每字符 **2 字节**，与原来语义一致。
- 仍为 **final byte[]**，String 依然 **不可变**。
- 可通过 JVM 参数 `-XX:-CompactStrings` 关闭紧凑字符串（部分版本）。
- 内部常量化：`static final byte LATIN1 = 0;`、`static final byte UTF16 = 1;`，与 `StringLatin1`/`StringUTF16` 工具类配合实现 indexOf、concat 等。

### 2.2 常用构造与 length/codePoint

- **length()**：返回的是 **字符个数**（对 UTF-16 即 code unit 个数），在 Java 9+ 内部按 coder 从 byte[] 计算。
- **codePointCount 等**：按 Unicode 码点处理，与 length 可能不同（存在代理对时）。

构造时若传入 `char[]`，在 Java 9+ 会按内容选择 LATIN1 或 UTF16 编码再存入 byte[]。

### 2.3 不可变与常量池

- 所有“修改”操作（concat、replace、trim 等）都 **返回新 String**，不修改原对象。
- **字面量** 和 **intern()** 进入 **字符串常量池**，相同内容的 intern 可共享实例，减少重复对象。

### 2.4 String 的 hashCode 是干什么用的

源码里 String 有一个字段 **`private int hash`**（默认 0），用来**缓存** `hashCode()` 的返回值。

**作用一：满足“基于哈希的容器”的约定**

- 和 `equals` 一起用：若 `a.equals(b)` 为 true，则必须 `a.hashCode() == b.hashCode()`。
- 这样 **HashMap、HashSet、Hashtable** 等才能按“先算 hash → 再按桶找 → 再 equals”正确找到同一个逻辑对象。

**作用二：实际用在哪**

- **HashMap / HashSet**：用 `key.hashCode()` 算桶下标，减少逐个 `equals` 比较。
- 字符串做 key 时（如 `Map<String, User>`、`Set<String>`）都依赖 String 的 hashCode 做快速查找、去重。
- 任何用“对象做 key”或“按对象去重”的哈希结构都会用到该对象的 hashCode，String 是最常用的一种。

**为什么要缓存 `hash`？**

- String **不可变**，算过一次 hashCode 后结果永远不变。
- 把结果存进 `hash`（0 表示“还没算过”），下次再调 `hashCode()` 直接返回缓存，**避免重复计算**。
- 同一个 String 常会多次参与 HashMap 的 put/get，缓存能明显减少重复计算。

**一句话**：String 的 hashCode 用于在 HashMap、HashSet 等容器里**快速定位和比较**“是不是同一个字符串”；`hash` 字段用来**缓存**这个值，因为字符串不可变，算一次即可。

---

## 三、AbstractStringBuilder 源码解读

`StringBuffer` 和 `StringBuilder` 的公共逻辑都在 **AbstractStringBuilder** 中。

### 3.1 内部存储（Java 8 vs Java 9+）

**Java 8**：

```java
abstract class AbstractStringBuilder {
    char[] value;   // 可扩容，非 final
    int count;      // 已用字符数（逻辑长度）
    // 容量即 value.length
}
```

**Java 9+**：与 String 对齐，改为 **byte[] + coder**：

```java
abstract class AbstractStringBuilder {
    byte[] value;
    byte coder;
    int count;      // 字符数（按 code unit 计）
    // 容量为 value.length >> coder 或按字节语义
}
```

- **value 非 final**，可扩容，因此是 **可变** 字符序列。
- 扩容、append、getChars 等都会根据 **coder** 走对应实现（如 StringLatin1 / StringUTF16 的静态方法），保证与 String 的 Compact Strings 一致。

### 3.2 初始容量与扩容

- **无参构造**：初始容量一般为 **16**（字符数）。
- **带初始字符串/容量构造**：容量 = 字符串长度 + 16 或指定值。

**扩容逻辑**（概念一致，Java 9+ 中按 byte 容量换算）：

1. 若 `count + 待追加长度 > value 容量`，则扩容。
2. 新容量通常为 **旧容量 * 2 + 2**（`(capacity << 1) + 2`）。
3. 若仍不足，则新容量 = 所需最小容量。
4. 上限约为 **Integer.MAX_VALUE - 8**（或实现定义上限），否则抛 `OutOfMemoryError`。
5. 使用 **Arrays.copyOf** 复制到新数组。

```java
// 扩容逻辑（伪代码，Java 8 风格便于理解）
void ensureCapacityInternal(int minimumCapacity) {
    if (minimumCapacity - value.length > 0) {
        int newCapacity = (value.length << 1) + 2;
        if (newCapacity - minimumCapacity < 0) newCapacity = minimumCapacity;
        if (newCapacity < 0) throw new OutOfMemoryError();
        value = Arrays.copyOf(value, newCapacity);
    }
}
```

### 3.3 append / insert / delete

- **append(String str)**：先 **ensureCapacity(count + str.length())**，再把 str 的字符（通过 getChars 或等价逻辑）拷贝到 value，更新 count，返回 this。
- **insert / delete**：同样先保证容量，再移动区间内元素，更新 count。
- 若传入 null，通常当作 `"null"` 字符串处理（appendNull）。

---

## 四、StringBuffer 与 StringBuilder 的差异

两者都继承 AbstractStringBuilder，**API 完全一致**，区别只有 **线程安全**：

- **StringBuffer**：对外方法（append、insert、delete、replace 等）都加 **synchronized**，多线程下安全，但存在锁开销。
- **StringBuilder**：无同步，单线程下更快，**推荐在单线程场景使用**。

```java
// StringBuffer 典型方法（简化）
@Override
public synchronized StringBuffer append(String str) {
    super.append(str);
    return this;
}

// StringBuilder 典型方法（简化）
@Override
public StringBuilder append(String str) {
    super.append(str);
    return this;
}
```

---

## 五、Java 9 及以后对三者的改动汇总

### 5.1 紧凑字符串（JEP 254）—— String、AbstractStringBuilder 均受益

| 项目 | Java 8 | Java 9+ |
|------|--------|---------|
| **String** | `char[] value`，2 字节/字符 | `byte[] value` + `byte coder`，LATIN1 时 1 字节/字符 |
| **AbstractStringBuilder**（及 StringBuffer/StringBuilder） | `char[] value` | `byte[] value` + `byte coder` |

- **动机**：大量字符串只含 Latin-1 字符，堆上 String 占比高，改为按需 1 字节/字符可显著 **降低内存与 GC 压力**。
- **对 StringBuffer/StringBuilder**：内部存储与 String 统一，转换与拷贝时无需再在 char[] 与 byte[] 间多做转换，实现更一致。

### 5.2 字符串拼接编译方式（JEP 280 Indify String Concatenation）

- **Java 8 及以前**：`"a" + b + "c"` 编译为 **显式 StringBuilder**：new StringBuilder → 多次 append → toString()。
- **Java 9+**：改为 **invokedynamic**（如 `makeConcatWithConstants`），由 JVM 在运行时选择拼接策略（可优化为直接使用 byte[]、避免中间 StringBuilder 等），**字节码更简洁**，且未来可继续优化而无需重新编译应用。
- **注意**：早期版本（如 Java 11–18）存在“先求值再转字符串”的顺序与旧行为不一致的 bug，**Java 19 已修复**。

这主要影响 **编译期** 对 `+` 拼接的翻译，不改变 String/StringBuilder 的公开 API，但运行时生成的实现会随 JDK 版本演进。

### 5.3 后续版本中的小补充

- **Java 11**：String 增加 **isBlank()、strip()、repeat()、lines()** 等，内部实现基于 byte[]+coder。
- **Java 17**：**String.format()** 等实现有优化，性能有提升。
- **Java 21**：**字符串模板**（JEP 430 预览）提供新的字符串构建方式；String 构造器在处理 **可变数组参数** 时的拷贝与健壮性增强，避免调用方在构造后修改数组影响 String 内容。

---

## 六、使用建议与小结

| 场景 | 推荐 |
|------|------|
| 常量、键、单次赋值、不需要修改 | **String** |
| 单线程下多次拼接、构造大字符串 | **StringBuilder** |
| 多线程下共享可变字符序列 | **StringBuffer** |
| 简单少量拼接（如 `"a"+b`） | 直接 `+`，Java 9+ 由 invokedynamic 优化 |

**源码层面的要点**：

- **String**：不可变，Java 9+ 用 byte[]+coder 做紧凑存储；所有“修改”都是新对象。
- **AbstractStringBuilder**：可变，Java 9+ 同样 byte[]+coder，扩容规则 *2+2，与 String 编码一致。
- **StringBuffer** = AbstractStringBuilder + synchronized；**StringBuilder** = AbstractStringBuilder，无同步。
- **Java 9+**：三者存储统一为 byte[]+coder（Compact Strings），字符串 `+` 的编译从 StringBuilder 链式调用改为 invokedynamic，后续版本继续在 format、构造器、模板等方面做增强。
