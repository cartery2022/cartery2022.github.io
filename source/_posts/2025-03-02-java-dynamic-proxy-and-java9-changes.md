---
title: Java 动态代理原理与 Java 9+ 改动
date: 2025-03-02
tags:
  - java
  - 动态代理
  - 源码解读
categories:
  - Java
  - 源码解读
---

# Java 动态代理原理与 Java 9+ 改动

本文说明 **JDK 动态代理**（`java.lang.reflect.Proxy` + `InvocationHandler`）的原理、用法与限制，并单独梳理 **Java 9 及以后版本** 对动态代理的改动（模块化、代理类包与可见性、ProxyGenerator 位置等）。

---

## 一、什么是动态代理

**动态代理**：在运行时动态生成“代理类”的字节码并加载，由代理类把方法调用统一转交给一个 **InvocationHandler** 处理，从而在不改业务类的前提下做增强（日志、事务、权限等）。

JDK 自带的动态代理基于 **接口**：只能为“实现了若干接口”的目标生成代理，代理对象实现相同接口，方法调用最终进入 `InvocationHandler.invoke()`。

---

## 二、核心 API

### 2.1 Proxy

- **Proxy.newProxyInstance(ClassLoader loader, Class<?>[] interfaces, InvocationHandler h)**  
  在运行时生成并加载代理类，返回实现 `interfaces` 的代理实例，该实例上所有接口方法调用都会交给 `h` 处理。

### 2.2 InvocationHandler

- **Object invoke(Object proxy, Method method, Object[] args)**  
  代理实例上“对接口方法的调用”都会转发到这里。  
  - `proxy`：代理对象本身（不要用它在 handler 里再调接口方法，否则会递归进 handler）。  
  - `method`：被调用的方法。  
  - `args`：方法参数。  
  返回值作为该次方法调用的结果。

---

## 三、使用示例

```java
import java.lang.reflect.*;

interface Hello {
    String say(String name);
}

class HelloImpl implements Hello {
    @Override
    public String say(String name) {
        return "Hello, " + name;
    }
}

public class ProxyDemo {
    public static void main(String[] args) {
        Hello target = new HelloImpl();
        InvocationHandler handler = (proxy, method, args) -> {
            System.out.println("Before: " + method.getName());
            Object result = method.invoke(target, args);
            System.out.println("After: " + method.getName());
            return result;
        };

        Hello proxy = (Hello) Proxy.newProxyInstance(
            Hello.class.getClassLoader(),
            new Class<?>[]{Hello.class},
            handler
        );

        System.out.println(proxy.say("World"));
        // Before: say
        // After: say
        // Hello, World
    }
}
```

- 目标类必须 **实现接口**，代理的是“接口类型”，实际调用仍转发到 `target`。
- 若要对“没有接口的类”做代理，需用 **CGLIB** 等基于子类的方案，见后文对比。

---

## 四、工作原理（源码层面）

### 4.1 newProxyInstance 流程概要

1. 校验：`loader`、`interfaces` 非空，接口均为接口类型且由同一 loader 加载等。
2. **查找或生成代理类**：以 `(loader, interfaces)` 为 key 查缓存；若无则用 **ProxyGenerator**（或内部等价实现）生成代理类字节码，再通过 `Unsafe.defineClass` 或 `ClassLoader.defineClass` 加载。
3. **实例化**：取代理类的唯一构造器，参数类型为 `InvocationHandler`，传入 `h`，`newInstance(h)` 得到代理实例。
4. 返回该实例。

### 4.2 生成的代理类长什么样

- 类名：通常为 **com.sun.proxy.$ProxyN**（N 为递增数字），Java 9+ 在模块化下可能处于“动态模块”，见第五节。
- **继承**：`extends java.lang.reflect.Proxy`（因此代理类也实现 `Serializable`）。
- **实现**：你传入的 `interfaces`。
- **字段**：从 Proxy 继承的 `protected InvocationHandler h`。
- **方法**：每个接口方法（以及从 Object 转发的 `equals`、`hashCode`、`toString`）内部都类似：

```java
public final String say(String name) {
    try {
        return (String) super.h.invoke(this, m_say, new Object[]{name});
    } catch (RuntimeException | Error e) {
        throw e;
    } catch (Throwable t) {
        throw new UndeclaredThrowableException(t);
    }
}
```

即：把调用转给 `InvocationHandler.invoke(proxy, method, args)`，检查异常后返回或包装为 `UndeclaredThrowableException`。

### 4.3 重要限制

- **只支持接口**：不能指定“代理某个类”，只能指定若干接口，代理类实现这些接口。
- **Object 方法**：`equals`、`hashCode`、`toString` 也会转发到 handler；其他 Object 方法（如 `getClass()`）不转发，由代理类自身实现。

---

## 五、Java 9 及以后对动态代理的改动

### 5.1 模块系统与代理类的包、可见性

Java 9 引入模块后，代理类的 **包与可见性** 受“代理接口所在包是否被当前模块导出/打开”影响：

| 情况 | 代理类所在位置/可见性 |
|------|------------------------|
| 所有代理接口都在**已导出或已打开**的包中 | 代理类在“未命名包”或实现定义的包中（如 com.sun.proxy），公共接口时一般为 public |
| 至少一个代理接口在**未导出且未打开**的包中 | 代理类在 **动态模块** 中；若通过 `Constructor.newInstance()` 在代理类上反射创建实例，可能抛 `IllegalAccessException`，应使用 **Proxy.newProxyInstance()** 创建 |

要点：当接口来自未导出包时，代理类被放在“动态模块”里，与普通模块的访问规则一致，不能随意反射实例化，必须走 `Proxy.newProxyInstance()`。

### 5.2 ProxyGenerator 位置与保存代理类字节码

| 项目 | Java 8 | Java 9+ |
|------|--------|---------|
| **ProxyGenerator 所在包** | `sun.misc.ProxyGenerator`（不推荐依赖） | 移至 **jdk.internal**（如 `jdk.internal.reflect`），非导出 API |
| **保存生成的 .class 文件** | `-Dsun.misc.ProxyGenerator.saveGeneratedFiles=true` | **`-Djdk.proxy.ProxyGenerator.saveGeneratedFiles=true`** |

调试时若要把运行时生成的代理类 dump 到磁盘，Java 9+ 需使用新系统属性 **`jdk.proxy.ProxyGenerator.saveGeneratedFiles=true`**；不要依赖 `sun.misc.ProxyGenerator`，内部实现可能随时调整。

### 5.3 核心 API 保持不变

- **Proxy.newProxyInstance(ClassLoader, Class<?>[], InvocationHandler)** 的签名与语义未变。
- **InvocationHandler.invoke** 的约定未变。
- 代理类仍继承 `Proxy`、实现指定接口，方法转发到 handler。  
因此“怎么用”在 8 与 9+ 一致，变化主要在“代理类放在哪个模块/包、如何生成与加载”以及调试/内部实现细节。

---

## 六、与 CGLIB 的简要对比

| 对比项 | JDK 动态代理 | CGLIB |
|--------|--------------|--------|
| **代理对象** | 实现指定接口 | 继承目标类（子类） |
| **前提** | 必须有接口 | 无接口也可，目标类/方法不能为 final |
| **实现方式** | 反射 + 运行时生成实现接口的类 | ASM 等字节码生成子类 |
| **典型用法** | Spring 中“Bean 实现了接口”时的默认代理 | Spring 中“Bean 无接口”或 `proxy-target-class=true` |

需要代理“没有接口的类”或“类上的方法”时，只能用 CGLIB（或类似字节码方案），不能用 JDK Proxy。

---

## 七、小结

- **JDK 动态代理**：通过 **Proxy.newProxyInstance** 传入类加载器、接口数组和 **InvocationHandler**，在运行时生成实现这些接口的代理类，所有接口方法（以及 equals/hashCode/toString）调用都转到 **handler.invoke**，常用于 AOP、RPC 客户端等。
- **限制**：只能基于接口；代理类继承 `Proxy`，由内部 ProxyGenerator 生成字节码并加载。
- **Java 9+**：模块化下代理类可能位于“动态模块”，未导出包中的接口会影响代理类的可访问性；ProxyGenerator 移入 jdk.internal，保存生成文件改用 **`jdk.proxy.ProxyGenerator.saveGeneratedFiles=true`**；对外 API 不变，现有基于 Proxy + InvocationHandler 的代码可继续使用。
