---
title: Java 标准库 Serializable 整体实现流程（源码与示例）
date: 2025-03-02
tags:
  - java
  - 序列化
  - ObjectOutputStream
  - ObjectInputStream
  - 源码解读
categories:
  - Java
  - 源码解读
---

# Java 标准库 Serializable 整体实现流程（源码与示例）

本文用 JDK 标准库（`java.io`）里的关键类/方法名 + 伪源码结构（接近 OpenJDK 源码组织方式），配合可运行示例，把 **Serializable 从对象写出到读回** 的整体实现流程讲清楚。

---

## 一、Serializable 是“标记接口”，真正干活的是 OOS/OIS

`Serializable` 本身几乎没有代码：

```java
package java.io;
public interface Serializable { }
```

它的意义：告诉序列化框架——**这个类允许被 Java 默认序列化机制处理**。

真正的入口在：

- **写出**：`java.io.ObjectOutputStream`
- **读回**：`java.io.ObjectInputStream`

---

## 二、写出流程（ObjectOutputStream）：从 writeObject 到字节流

### 2.1 入口：writeObject(Object obj)

典型调用：

```java
try (ObjectOutputStream oos = new ObjectOutputStream(out)) {
    oos.writeObject(obj);
}
```

核心流程（接近源码结构的伪源码）：

```java
public final void writeObject(Object obj) throws IOException {
    writeObject0(obj, false);
}

private void writeObject0(Object obj, boolean unshared) {
    if (obj == null) { writeNull(); return; }

    // 1) 处理循环引用/重复引用：句柄表（HandleTable）
    if (handles.contains(obj)) { writeHandle(handles.lookup(obj)); return; }

    // 2) 写类描述（class descriptor）
    ObjectStreamClass desc = ObjectStreamClass.lookup(obj.getClass());

    // 3) 根据对象类型分派
    if (obj instanceof String) writeString((String)obj);
    else if (obj.getClass().isArray()) writeArray(obj);
    else if (obj instanceof Enum) writeEnum((Enum)obj);
    else writeOrdinaryObject(obj, desc);
}
```

### 2.2 关键：ObjectStreamClass（类的“序列化描述”）

`ObjectStreamClass` 负责：

- 判断类是否 `Serializable`
- 计算/读取 `serialVersionUID`
- 收集可序列化字段（排除 `static`、排除 `transient`）
- 解析是否存在私有钩子方法：`writeObject` / `readObject` / `readResolve` / `writeReplace`

伪源码：

```java
static ObjectStreamClass lookup(Class<?> cl) {
    // cache
    // if implements Serializable => build descriptor:
    //   - serialVersionUID
    //   - fields (ObjectStreamField[])
    //   - hasWriteObjectMethod?
    //   - hasReadObjectMethod?
}
```

### 2.3 写普通对象：writeOrdinaryObject

```java
private void writeOrdinaryObject(Object obj, ObjectStreamClass desc) {
    writeClassDesc(desc);
    handles.assign(obj);           // 先登记，解决循环引用
    desc.writeObject(obj, this);   // 默认字段 or 自定义 writeObject
}
```

### 2.4 两条路线：默认字段序列化 vs 自定义 writeObject

- **默认序列化**（没有定义 `private void writeObject`）：`defaultWriteFields(obj, desc)`，按收集到的字段顺序写出。
- **自定义序列化**（类里定义了 `private void writeObject(ObjectOutputStream out)`）：JDK 用反射调用你的私有方法，你通常会先 `out.defaultWriteObject()`，再写自定义数据。

---

## 三、读回流程（ObjectInputStream）：从 readObject 到对象还原

### 3.1 入口：readObject()

```java
try (ObjectInputStream ois = new ObjectInputStream(in)) {
    Object obj = ois.readObject();
}
```

伪源码结构：

```java
public final Object readObject() {
    return readObject0(false);
}

private Object readObject0(boolean unshared) {
    byte tc = readTC();
    switch (tc) {
        case TC_NULL: return null;
        case TC_REFERENCE: return handles.lookup(readHandle());
        case TC_STRING: return readString();
        case TC_ARRAY: return readArray();
        case TC_ENUM: return readEnum();
        case TC_OBJECT: return readOrdinaryObject(unshared);
        ...
    }
}
```

### 3.2 读普通对象：readOrdinaryObject

关键步骤：读 classDesc → 创建实例（通常不调用你的构造方法）→ 先塞进 handle 表 → 读字段 → 若有 `readObject` 则回调 → 若有 `readResolve` 则替换返回对象。

```java
private Object readOrdinaryObject(boolean unshared) {
    ObjectStreamClass desc = readClassDesc();
    Object obj = desc.newInstance();
    handles.assign(obj);
    desc.readObject(obj, this);
    obj = desc.invokeReadResolve(obj);
    return obj;
}
```

### 3.3 serialVersionUID 校验

在读 classDesc、把流中的描述映射到本地类时，会比较流里写入的 `serialVersionUID` 与本地类的 `serialVersionUID`，不一致就抛 `InvalidClassException`。

---

## 四、句柄表（HandleTable）：循环引用与重复引用

### 4.1 为什么需要句柄？

- **重复引用**要保持同一性：`a.x == a.y` 指向同一对象时，反序列化后也必须 `==`。
- **对象图可能有环**：若每次遇到对象都“深拷贝写一遍”，有环会无限递归、栈溢出。

所以需要“已见对象登记表”**HandleTable**：给每个**第一次出现**的对象分配递增的整数 id（handle），之后再遇到同一对象就写 **TC_REFERENCE + handle**。

### 4.2 HandleTable 数据结构（源码风格）

```java
private static class HandleTable {
    int[] spine;       // 哈希桶头结点
    int[] next;        // 链表 next
    Object[] objs;     // 对象引用
    int size;          // 已分配句柄数
    int threshold;
    float loadFactor;

    int assign(Object obj) { ... }   // 登记并返回 handle
    int lookup(Object obj) { ... }   // 查 handle，找不到返回 -1
}
```

- 按**对象 identity** 追踪：用 `System.identityHashCode(obj)` 做 hash，用 `==` 做相等判断（不是 `equals()`）。
- 哈希桶 + 链式冲突：`spine[bucket]` 存该桶链表第一个 entry 的下标，`next[i]` 连接链表。

### 4.3 lookup：判断“这个对象以前写过没？”

```java
int lookup(Object obj) {
    int h = System.identityHashCode(obj);
    int bucket = (h & 0x7fffffff) % spine.length;
    for (int i = spine[bucket]; i >= 0; i = next[i]) {
        if (objs[i] == obj)   // identity 比较
            return i;
    }
    return -1;
}
```

### 4.4 assign：第一次见到对象时登记

```java
int assign(Object obj) {
    if (size >= next.length) growEntries();
    if (size >= threshold) growSpine();
    int h = System.identityHashCode(obj);
    int bucket = (h & 0x7fffffff) % spine.length;
    objs[size] = obj;
    next[size] = spine[bucket];
    spine[bucket] = size;
    return size++;
}
```

### 4.5 写入时：何时写 TC_REFERENCE？何时 assign？

- **重复引用**：`lookup(obj) != -1` 时，写 `TC_REFERENCE + (baseWireHandle + handle)`。
- **写对象本体前必须先 assign**：这样在写字段时若再次遇到自己（如 `n.next = n`），`lookup` 会命中，直接写引用，不会无限递归。

### 4.6 identityHashCode 会冲突吗？

会。`System.identityHashCode(obj)` 是 32 位 int，不同对象可能得到相同值。HandleTable **不依赖 hash 唯一性**：用 hash 选桶，用 **`==`** 做最终确认；冲突只会让同一桶内链表变长，不会误判。

---

## 五、desc.writeObject(obj, this) 源码与输出内容

在 `ObjectStreamClass` 里：

```java
void writeObject(Object obj, ObjectOutputStream out) throws IOException {
    if (writeObjectMethod != null) {
        invokeWriteObject(obj, out);   // 反射调用 private writeObject
    } else {
        defaultWriteFields(obj, out);   // 按字段类型逐个写出
    }
}
```

- **defaultWriteFields**：遍历 `ObjectStreamField[]`，用反射取字段值，按类型调用 `out.writeInt()` / `out.writeLong()` / `out.writeObject()` 等。
- **invokeWriteObject**：`writeObjectMethod.invoke(obj, new Object[]{out})`，你在方法里可以 `out.defaultWriteObject()` 再写额外数据。

### 简单示例：默认序列化输出什么？

```java
import java.io.*;

public class SimpleDemo {
    static class Person implements Serializable {
        private static final long serialVersionUID = 1L;
        int age;
        String name;
        Person(int age, String name) { this.age = age; this.name = name; }
    }

    public static void main(String[] args) throws Exception {
        Person p = new Person(18, "Alice");
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        ObjectOutputStream oos = new ObjectOutputStream(bos);
        oos.writeObject(p);
        oos.close();
        byte[] data = bos.toByteArray();
        for (byte b : data) System.out.printf("%02X ", b);
    }
}
```

典型输出（节选）：

- `AC ED 00 05`：STREAM_MAGIC + 版本
- `73`：TC_OBJECT
- `72`：TC_CLASSDESC，后跟类名、serialVersionUID、flags、字段元数据（如 `I age`、`L name`）、TC_ENDBLOCKDATA、父类描述
- 接着是字段数据：`00 00 00 12`（age=18），以及表示 "Alice" 的 TC_STRING 等

若有自定义 `writeObject` 里多写了 `out.writeInt(999)`，流里会多出 `00 00 03 E7`。

---

## 六、完整示例：默认字段 + transient + 自定义 writeObject/readObject

下面可直接运行，体现“默认字段块 + 额外数据 + transient 手动处理”：

```java
import java.io.*;
import java.util.Arrays;

public class SerializableDemo {

    public static class User implements Serializable {
        private static final long serialVersionUID = 1L;

        private String name;
        private int age;
        private transient String password;
        private transient int checksum;

        public User(String name, int age, String password) {
            this.name = name;
            this.age = age;
            this.password = password;
            this.checksum = calcChecksum();
        }

        private int calcChecksum() {
            return (name == null ? 0 : name.hashCode()) ^ age;
        }

        private void writeObject(ObjectOutputStream out) throws IOException {
            out.defaultWriteObject();
            out.writeObject(password);
            out.writeInt(calcChecksum());
        }

        private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
            in.defaultReadObject();
            this.password = (String) in.readObject();
            int cs = in.readInt();
            this.checksum = cs;
            if (cs != calcChecksum()) {
                throw new InvalidObjectException("checksum mismatch!");
            }
        }

        @Override
        public String toString() {
            return "User{name='" + name + "', age=" + age + ", password='" + password + "', checksum=" + checksum + "}";
        }
    }

    public static void main(String[] args) throws Exception {
        User u1 = new User("Alice", 20, "p@ss");
        byte[] data;
        try (ByteArrayOutputStream bos = new ByteArrayOutputStream();
             ObjectOutputStream oos = new ObjectOutputStream(bos)) {
            oos.writeObject(u1);
            oos.flush();
            data = bos.toByteArray();
        }
        System.out.println("serialized bytes len=" + data.length);

        User u2;
        try (ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data))) {
            u2 = (User) ois.readObject();
        }
        System.out.println("u1=" + u1);
        System.out.println("u2=" + u2);
    }
}
```

可看到：transient 的 `password` 通过自定义 write/read 补回；校验失败在 `readObject` 里抛 `InvalidObjectException`。

---

## 七、验证句柄表：重复引用与循环引用

```java
import java.io.*;

public class HandleTableProof {
    static class Node implements Serializable {
        String name;
        Node next;
        Node(String name) { this.name = name; }
    }

    public static void main(String[] args) throws Exception {
        Node a = new Node("A");
        Node b = new Node("B");
        a.next = b;
        b.next = a;   // A <-> B 形成环

        Node root = new Node("ROOT");
        root.next = a;

        byte[] data;
        try (ByteArrayOutputStream bos = new ByteArrayOutputStream();
             ObjectOutputStream oos = new ObjectOutputStream(bos)) {
            oos.writeObject(root);
            data = bos.toByteArray();
        }

        Node root2;
        try (ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data))) {
            root2 = (Node) ois.readObject();
        }
        Node a2 = root2.next;
        Node b2 = a2.next;
        System.out.println("b2.next == a2 ? " + (b2.next == a2));  // true，环被还原
    }
}
```

没有“先 assign 再写/读字段”的策略，写时会无限递归，或读回来环断掉（`b2.next != a2`）。

---

## 八、四个钩子点（Serializable 的威力）

| 钩子 | 作用 |
|------|------|
| `private void writeObject(ObjectOutputStream out)` | 自定义写出流程 |
| `private void readObject(ObjectInputStream in)` | 自定义读回流程 |
| `private Object writeReplace()` | 写出前用另一对象替代（代理、单例、版本迁移） |
| `private Object readResolve()` | 读回后用另一对象替代（单例常用） |

单例防反序列化破坏示例：

```java
private Object readResolve() {
    return INSTANCE;
}
```

另外，**serialVersionUID** 建议显式声明，避免改字段后 JDK 自动计算的 UID 变化导致旧数据读不回。

---

## 九、Serializable vs Externalizable（简要）

- **Serializable**：默认字段序列化 + 可选钩子（更常用）。
- **Externalizable**：必须实现 `writeExternal`/`readExternal`，完全自己控制格式；反序列化时会调用**无参构造**。

若需要跨版本稳定、可控二进制格式，实践中常用自定义协议（Kryo/Protobuf/JSON）或 Externalizable / 手写 DataOutput/DataInput。

---

## 十、调用链小结

**写出**：`writeObject(obj)` → `writeObject0` → `writeOrdinaryObject` → `writeClassDesc` → `handles.assign(obj)` → `desc.writeObject(obj, this)` → `defaultWriteFields` 或 `invokeWriteObject`。

**读回**：`readObject()` → `readObject0` → 根据 TC 分派 → `readOrdinaryObject` → `readClassDesc` → `desc.newInstance()` → `handles.assign(obj)` → `desc.readObject(obj, this)` → `invokeReadResolve`。

读 OpenJDK 时可重点看：`writeObject0` 的重复引用分支、`writeOrdinaryObject` 里 assign 的时机、HandleTable 的 lookup/assign、以及 OIS 里 TC_REFERENCE 与 readOrdinaryObject 的顺序。
