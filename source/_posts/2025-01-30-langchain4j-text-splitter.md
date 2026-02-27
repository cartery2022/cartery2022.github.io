---
title: LangChain4j TextSplitter 实现说明
date: 2025-01-30
tags:
  - agent
  - java
  - langchain4j
  - 源码解读
categories:
  - agent
  - 源码解读
  - textSplitter
---

# LangChain4j Splitter包 文档分割 源码解读

## 概述

LangChain4j 在包 `dev.langchain4j.data.document.splitter` 下提供文档分割能力：通过 `DocumentSplitter` 接口将 `Document` 切分为多个 `TextSegment`，并支持按字符、行、段落、句子、词、正则等不同粒度。

- 包文档：[dev.langchain4j.data.document.splitter](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/package-summary.html)

## 核心接口

### DocumentSplitter

```java
// 概念上的接口（LangChain4j）
public interface DocumentSplitter {
    List<TextSegment> split(Document document);
    List<TextSegment> splitAll(Document... documents);
    List<TextSegment> splitAll(List<Document> documents);
}
```

- 输入：`Document`
- 输出：`List<TextSegment>`，每个 segment 受 `maxSegmentSize` 限制

## 内置分割器（LangChain4j）

| 类名 | 分隔符 / 行为 | 说明 |
|------|----------------|------|
| `DocumentByParagraphSplitter` | `"\n\n"` | 按段落 |
| `DocumentByLineSplitter` | `"\n"` | 按行 |
| `DocumentBySentenceSplitter` | 句子边界 | 按句子 |
| `DocumentByWordSplitter` | `" "` | 按词 |
| `DocumentByCharacterSplitter` | 字符 | 按字符 |
| `DocumentByRegexSplitter` | 正则 | 按正则 |
| `HierarchicalDocumentSplitter` | - | 层级分割基类 |


## 源码解读：HierarchicalDocumentSplitter 与 SegmentBuilder

### 1. 整体流程（HierarchicalDocumentSplitter.split）

层级分割的核心在 `HierarchicalDocumentSplitter.split(Document)`：

1. 用子类实现的 `split(text)` 按当前粒度得到 `parts`（如段落、行、词等）。
2. 用 **SegmentBuilder** 按 `maxSegmentSize` 把多个 part 拼成一个 segment；拼不下时先刷出当前 segment，再根据 `maxOverlapSize` 取尾部 overlap，作为下一段的开头。
3. 若**单个 part 本身**就超过 `maxSegmentSize`，则交给 **subSplitter** 再切（如段落太长 → 按句子切），子分割结果再按索引挂回原 Document 的 metadata。

支持按字符数或按 token 数：通过 `TokenCountEstimator` 与 `estimateSize(text)` 注入到 SegmentBuilder 的“长度”计算里。

### 2. SegmentBuilder 的职责与结构

`SegmentBuilder`（`dev.langchain4j.data.document.splitter.SegmentBuilder`）是包级工具类（`@Internal`），**没有定义任何私有内部类**，只负责：在不超过 `maxSegmentSize` 的前提下，用指定分隔符拼接多段文本，并支持“从尾部取 overlap”时用 `prepend` 逆序拼。

**私有字段（6 个）**

| 字段 | 类型 | 含义 |
|------|------|------|
| `maxSegmentSize` | `int` | 单段最大长度（字符或 token） |
| `sizeFunction` | `Function<String, Integer>` | 计算文本长度的函数 |
| `joinSeparator` | `String` | 拼接时的分隔符（如 `"\n\n"`） |
| `joinSeparatorSize` | `int` | 分隔符自身长度 |
| `segment` | `String` | 当前正在拼的段内容 |
| `segmentSize` | `int` | 当前段长度（由 sizeFunction 得到） |

**对外 API（均为 public 方法）**

| 方法 | 作用 |
|------|------|
| `getSize()` | 当前段长度 |
| `hasSpaceFor(String text)` / `hasSpaceFor(int size)` | 再拼一段是否仍 ≤ maxSegmentSize |
| `sizeOf(String text)` | 用 sizeFunction 计算 text 长度 |
| `append(String text)` | 末尾用 joinSeparator 拼接（主流程拼段） |
| `prepend(String text)` | 开头拼接（overlap 时从段尾逆序填） |
| `isNotEmpty()` | 当前段是否非空 |
| `toString()` | 返回 `segment.trim()` |
| `reset()` | 清空当前段，开始拼下一段 |

### 3. Overlap 与 subSplitter

- **Overlap**：刷出一个 segment 后，用 `overlapFrom(segmentText)` 从该段**按句子**逆序取最多 `maxOverlapSize` 的内容，作为下一段的开头，保证相邻段有重叠而不割裂语义。
- **subSplitter**：当单个 part 超长时，用子分割器（如 `DocumentBySentenceSplitter`）再切，子类通过 `defaultSubSplitter()` 指定默认实现（如段落 → 句子 → 词 → 字符的链条）。

## 推荐用法：DocumentSplitters.recursive()

LangChain4j 推荐对通用文本使用 **recursive** 方式，即按层级尝试：段落 → 行 → 句子 → 词 → 字符，直到满足 `maxSegmentSize`。

```java
// LangChain4j 用法示例
DocumentSplitter splitter = DocumentSplitters.recursive(
    1000,  // maxSegmentSize
    200    // maxOverlap
);
List<TextSegment> segments = splitter.split(document);
```

支持按字符数或按 token 数控制大小。

## Spring AI 中的对应实现

本仓库在 `org.springframework.ai.transformer.splitter` 下实现了与 LangChain4j 对齐的 API，并**默认递归行为与 Python RecursiveCharacterTextSplitter 一致**。

### 工厂类：DocumentSplitters

| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `recursive()` | `RecursiveCharacterTextSplitter` | 默认递归（同 Python），chunk 1000，overlap 200 |
| `recursive(chunkSize, chunkOverlap)` | `RecursiveCharacterTextSplitter` | 自定义大小与重叠 |
| `byParagraph()` | `DocumentByParagraphSplitter` | 按段落 `"\n\n"` |
| `byParagraph(maxSegmentSize, chunkOverlap)` | `DocumentByParagraphSplitter` | 自定义参数 |
| `byLine()` | `DocumentByLineSplitter` | 按行 `"\n"` |
| `byLine(maxSegmentSize, chunkOverlap)` | `DocumentByLineSplitter` | 自定义参数 |
| `byWord()` | `DocumentByWordSplitter` | 按词 `" "` |
| `byWord(maxSegmentSize, chunkOverlap)` | `DocumentByWordSplitter` | 自定义参数 |
| `byCharacter()` | `DocumentByCharacterSplitter` | 按字符 |
| `byCharacter(maxSegmentSize, chunkOverlap)` | `DocumentByCharacterSplitter` | 自定义参数 |

### 使用示例

#### 1. 默认递归（推荐，等同 Python RecursiveCharacterTextSplitter）

```java
import org.springframework.ai.document.Document;
import org.springframework.ai.transformer.splitter.DocumentSplitters;
import org.springframework.ai.transformer.splitter.TextSplitter;

TextSplitter splitter = DocumentSplitters.recursive();
List<Document> chunks = splitter.split(List.of(document));
// 或
List<Document> chunks = splitter.apply(List.of(doc1, doc2));
```

#### 2. 自定义 chunk 大小与重叠

```java
TextSplitter splitter = DocumentSplitters.recursive(500, 100);
List<Document> chunks = splitter.split(documents);
```

#### 3. 仅按段落 / 行 / 词 / 字符

```java
// 按段落
TextSplitter byParagraph = DocumentSplitters.byParagraph();
List<Document> chunks = byParagraph.split(documents);

// 按行
TextSplitter byLine = DocumentSplitters.byLine(1000, 200);

// 按词
TextSplitter byWord = DocumentSplitters.byWord();

// 按字符
TextSplitter byChar = DocumentSplitters.byCharacter(1000, 200);
```

#### 4. Builder 方式（RecursiveCharacterTextSplitter）

```java
RecursiveCharacterTextSplitter splitter = RecursiveCharacterTextSplitter.builder()
    .chunkSize(1000)
    .chunkOverlap(200)
    .keepSeparator(true)
    .separators(List.of("\n\n", "\n", " ", ""))
    .build();
List<Document> chunks = splitter.split(documents);
```

### 输出与元数据

所有分割器继承 `TextSplitter`，实现 `DocumentTransformer`，因此：

- 输入：`List<Document>`
- 输出：`List<Document>`，每个块带有：
  - `parent_document_id`：来源文档 ID
  - `chunk_index`：块在该文档中的下标
  - `total_chunks`：该文档被分成的总块数
  - 以及从原 Document 继承的其他 metadata

## 与 LangChain4j 的差异

| 项目 | LangChain4j | Spring AI（本仓库） |
|------|-------------|----------------------|
| 输出类型 | `TextSegment` | `Document` |
| 接口 | `DocumentSplitter` | `TextSplitter`（实现 `DocumentTransformer`） |
| 默认推荐 | `DocumentSplitters.recursive()` | `DocumentSplitters.recursive()`，且默认参数与 Python 一致 |
| 按 token 分割 | recursive 支持 token 模式 | 使用独立类 `TokenTextSplitter`（jtokkit） |

## 依赖

Spring AI 相关分割器位于模块 `spring-ai-commons`，使用前确保已引入：

```xml
<dependency>
    <groupId>org.springframework.ai</groupId>
    <artifactId>spring-ai-commons</artifactId>
    <version>${spring-ai.version}</version>
</dependency>
```

## 参考链接

- [LangChain4j DocumentSplitters](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/DocumentSplitters.html)
- [LangChain4j DocumentByParagraphSplitter](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/DocumentByParagraphSplitter.html)
- [LangChain4j 包文档](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/package-summary.html)
