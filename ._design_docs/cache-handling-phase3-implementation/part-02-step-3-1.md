## Step 3.1: Helper Methods and Data Structures

**Status**: Completed  
**Objective**: Establish foundation for save/load implementation

### Changes Made

#### Files Modified

1. **tools/server/server-task.h**
   - Added `boundaries_native` flag to `prepared_prompt_metadata` structure
   - This flag indicates whether boundaries were captured natively (true) or inferred from rendered text (false)

2. **tools/server/server-cache-hybrid.h**
   - Added declaration for `find_exact_match()` helper method
   - Method signature: `std::list<hybrid_cache_entry>::iterator find_exact_match(const server_tokens &, const std::string &)`

3. **tools/server/server-cache-hybrid.cpp**
   - Implemented `find_exact_match()` method for deduplication
   - Uses prefix index for O(m) lookup where m = number of candidates
   - Returns iterator to exact match or entries.end() if not found

4. **tools/server/server-context.cpp**
   - Added deduplication logic to `save_slot()` method
   - Checks for existing entry before expensive state serialization
   - Updates existing entry's usage metadata if duplicate found
   - Modified `cache_metadata_from_chat_messages()` to mark boundaries as non-native
   - Set `boundaries_native = false` since using rendered-text inference
   - Set `degraded_reason` to indicate fallback boundary capture method

### Implementation Details

#### find_exact_match() Logic

The helper uses a two-stage matching process:
1. Fast prefix index lookup to find candidates (O(1) hash lookup)
2. Exact token-by-token comparison for candidates in same namespace

This avoids expensive linear search through all cache entries.

#### Deduplication in save_slot()

Before serializing state (expensive operation), the method now:
1. Computes namespace ID for the new entry
2. Calls `find_exact_match()` to check if identical entry exists
3. If found: updates existing entry's LRU metadata and returns
4. If not found: proceeds with state serialization and adds new entry

This prevents duplicate cache entries and saves memory/CPU time.

#### Degraded Metadata Marking

Current boundary extraction uses rendered-text search (fallback mode):
- `boundaries_native` flag set to `false`
- `degraded_reason` explicitly documents inference method
- Future native capture can replace this without breaking Phase 3

### Test Coverage

Will be verified in Step 3.6 after building and running tests.

### Evidence

**File Changes:**
- [server-task.h](../tools/server/server-task.h#L169-L177) - Added boundaries_native field
- [server-cache-hybrid.h](../tools/server/server-cache-hybrid.h#L146-L151) - Added find_exact_match declaration
- [server-cache-hybrid.cpp](../tools/server/server-cache-hybrid.cpp#L175-L202) - Implemented find_exact_match
- [server-context.cpp](../tools/server/server-context.cpp#L3871-L3886) - Marked degraded metadata
- [server-context.cpp](../tools/server/server-context.cpp#L5230-L5243) - Added deduplication to save_slot

### Exit Criteria

- [x] `boundaries_native` field added to prepared_prompt_metadata
- [x] `find_exact_match()` helper implemented
- [x] Deduplication logic added to save_slot()
- [x] Degraded metadata explicitly marked
- [x] Code compiles without errors
- [ ] Unit tests pass (will verify in build step)
- [ ] No behavioral changes to existing code paths
