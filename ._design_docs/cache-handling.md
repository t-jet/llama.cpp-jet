# Cache Handling in `llama-server`

This note documents the cache-elimination and cache-invalidation rules that are implemented today in the server.

The server has three related but distinct mechanisms:

1. The prompt cache, which stores full serialized prompt state in host RAM.
2. Context checkpoints, which store partial rollback state attached to a live prompt or a cached prompt.
3. Live slot state, which may be cleared, saved, or purged independently of prompt-cache eviction.

## Contents

This document is split into smaller part files. Read the parts in order when you need the full content.

- [Part 1: Current Implementation](./cache-handling/part-01-current-implementation.md)
- [Part 2: Where the current design works against controller patterns](./cache-handling/part-02-where-the-current-design-works-against-controlle.md)
- [Part 3: Recommended Implementation Shape](./cache-handling/part-03-recommended-implementation-shape.md)
