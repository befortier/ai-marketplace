---
name: Join Async Streams
description: This skill should be used when the user asks to "join async streams", "combine async streams", "merge two streams", "map data from two streams", "combine latest streams", "join repository streams", or when implementing a pattern that combines multiple AsyncStream sources into a single mapped output stream.
---

# Join Async Streams

Combine multiple `AsyncStream` sources into a single mapped output stream using the `combineLatest` pattern. This is the standard approach for joining data from two or more async sources (e.g., a repository stream and a store stream) and producing a unified, transformed stream.

## When to Use

- Joining data from two async sources (e.g., a repository and a store) into a single stream
- Mapping or enriching models by combining streams of related data
- Producing a reactive stream that updates whenever either source emits a new value

**When not to use:** to correlate two sources whose producers you own — first check the write order (see [Don't Join What You Can Order](#dont-join-what-you-can-order)).

## Don't Join What You Can Order

Before joining (or polling) to correlate a signal stream with the record it announces, check the producers. If the signal is emitted before the record is written, fix the write order at the producer — record first, then signal — and the join collapses to a single read on the signal. A poll/sleep/deadline loop in a consumer waiting for the second source to catch up is the smell that the producers' write order is wrong; fix it there, not in the join.

## Pattern

```swift
let sourceStreamA = await repositoryA.stream(replayCurrentValue: true)
let sourceStreamB = await storeB.stream()
let (stream, continuation) = AsyncStream<[MappedModel]>.makeStream()
let task = Task {
    for await (itemsA, itemsB) in combineLatest(sourceStreamA, sourceStreamB) {
        continuation.yield(
            itemsA.map { item in
                MappedModel(
                    source: item,
                    derivedValue: itemsB.contains(item.id)
                )
            }
        )
    }
    continuation.finish()
}
continuation.onTermination = { _ in task.cancel() }
return stream
```

## Key Implementation Details

1. **Create the output stream** using `AsyncStream<T>.makeStream()` to get a `(stream, continuation)` pair.
2. **Wrap the `for await` loop in a `Task`** so the combination runs concurrently.
3. **Use `combineLatest`** to receive the latest values from both streams whenever either emits.
4. **Call `continuation.yield(...)`** inside the loop to push each mapped result downstream.
5. **Call `continuation.finish()`** after the loop to signal stream completion.
6. **Set `continuation.onTermination`** to cancel the task when the consumer stops listening — this prevents leaked tasks.
7. **Return the stream**, not the continuation.

## Replay Behavior

When calling `.stream(replayCurrentValue: true)` on a source, the stream immediately emits the current cached value. This ensures the combined stream produces an initial value without waiting for a live update. Use this on sources where the current state matters at subscription time (e.g., a repository with cached data).

## Checklist

- [ ] Both source streams are `await`-ed before use
- [ ] `AsyncStream<T>.makeStream()` is used to create the output
- [ ] `combineLatest` is used inside a `Task { ... }` block
- [ ] `continuation.finish()` is called after the `for await` loop
- [ ] `continuation.onTermination` cancels the task
- [ ] The returned type is `AsyncStream<T>`, not the continuation
