---
title: LangChain4j TextSplitter — Implementation Notes
date: 2025-01-30
tags:
  - agent
  - java
  - langchain4j
  - source-reading
categories:
  - agent
  - source-reading
  - textSplitter
---

# LangChain4j Splitter Package — Document Splitting Source Walkthrough

## Overview

LangChain4j provides document splitting in the package `dev.langchain4j.data.document.splitter`: the `DocumentSplitter` interface turns a `Document` into multiple `TextSegment`s, with support for character, line, paragraph, sentence, word, and regex-based splitting.

- Package docs: [dev.langchain4j.data.document.splitter](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/package-summary.html)

## Core interface

### DocumentSplitter

```java
// Conceptual interface (LangChain4j)
public interface DocumentSplitter {
    List<TextSegment> split(Document document);
    List<TextSegment> splitAll(Document... documents);
    List<TextSegment> splitAll(List<Document> documents);
}
```

- Input: `Document`
- Output: `List<TextSegment>`, each segment bounded by `maxSegmentSize`

## Built-in splitters (LangChain4j)

| Class | Separator / behavior | Description |
|-------|----------------------|-------------|
| `DocumentByParagraphSplitter` | `"\n\n"` | By paragraph |
| `DocumentByLineSplitter` | `"\n"` | By line |
| `DocumentBySentenceSplitter` | Sentence boundary | By sentence |
| `DocumentByWordSplitter` | `" "` | By word |
| `DocumentByCharacterSplitter` | Character | By character |
| `DocumentByRegexSplitter` | Regex | By regex |
| `HierarchicalDocumentSplitter` | - | Base for hierarchical splitting |

## Source: HierarchicalDocumentSplitter and SegmentBuilder

### 1. Overall flow (HierarchicalDocumentSplitter.split)

The core of hierarchical splitting is `HierarchicalDocumentSplitter.split(Document)`:

1. Use the subclass’s `split(text)` to get `parts` at the current granularity (e.g. paragraph, line, word).
2. Use **SegmentBuilder** to combine parts into segments of at most `maxSegmentSize`; when a part doesn’t fit, flush the current segment, then take a tail overlap of size `maxOverlapSize` as the start of the next segment.
3. If a **single part** exceeds `maxSegmentSize`, hand it to **subSplitter** (e.g. long paragraph → split by sentence); sub-split results are reattached to the original Document’s metadata by index.

Size can be character count or token count via `TokenCountEstimator` and `estimateSize(text)` in SegmentBuilder.

### 2. SegmentBuilder role and structure

`SegmentBuilder` (`dev.langchain4j.data.document.splitter.SegmentBuilder`) is a package-level utility (`@Internal`). It has **no private inner classes** and only: concatenates text parts with a given separator without exceeding `maxSegmentSize`, and supports “overlap from end” by prepending in reverse order.

**Private fields (6)**

| Field | Type | Meaning |
|-------|------|---------|
| `maxSegmentSize` | `int` | Max length per segment (chars or tokens) |
| `sizeFunction` | `Function<String, Integer>` | Text length function |
| `joinSeparator` | `String` | Separator when joining (e.g. `"\n\n"`) |
| `joinSeparatorSize` | `int` | Length of the separator |
| `segment` | `String` | Current segment content |
| `segmentSize` | `int` | Current segment length (from sizeFunction) |

**Public API**

| Method | Purpose |
|--------|---------|
| `getSize()` | Current segment length |
| `hasSpaceFor(String text)` / `hasSpaceFor(int size)` | Whether adding one more part still keeps size ≤ maxSegmentSize |
| `sizeOf(String text)` | Compute text length via sizeFunction |
| `append(String text)` | Append with joinSeparator (main flow) |
| `prepend(String text)` | Prepend (for overlap from segment end) |
| `isNotEmpty()` | Whether current segment is non-empty |
| `toString()` | Returns `segment.trim()` |
| `reset()` | Clear current segment for next one |

### 3. Overlap and subSplitter

- **Overlap**: After flushing a segment, `overlapFrom(segmentText)` takes up to `maxOverlapSize` from the **end by sentence** (in reverse order) as the start of the next segment, so adjacent segments overlap without breaking semantics.
- **subSplitter**: When a single part is too long, a sub-splitter (e.g. `DocumentBySentenceSplitter`) is used; the default chain is provided by `defaultSubSplitter()` (e.g. paragraph → sentence → word → character).

## Recommended usage: DocumentSplitters.recursive()

LangChain4j recommends **recursive** splitting for general text: try paragraph → line → sentence → word → character until `maxSegmentSize` is satisfied.

```java
// LangChain4j example
DocumentSplitter splitter = DocumentSplitters.recursive(
    1000,  // maxSegmentSize
    200    // maxOverlap
);
List<TextSegment> segments = splitter.split(document);
```

Supports both character count and token count for size.

## References

- [LangChain4j DocumentSplitters](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/DocumentSplitters.html)
- [LangChain4j DocumentByParagraphSplitter](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/DocumentByParagraphSplitter.html)
- [LangChain4j package summary](https://docs.langchain4j.dev/apidocs/dev/langchain4j/data/document/splitter/package-summary.html)
