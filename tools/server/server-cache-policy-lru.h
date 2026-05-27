#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

enum class server_cache_eviction_reason {
    over_budget,
    admission_retry,
    protected_budget_pressure,
};

struct server_cache_policy_candidate {
    uint64_t entry_id = 0;
    std::string namespace_id;
    size_t resident_payload_bytes = 0;
    int token_count = 0;
    uint64_t use_sequence = 0;
    uint64_t insertion_sequence = 0;
    bool protected_root = false;
    bool has_target_payload = false;
    bool has_draft_payload = false;
};

struct server_cache_policy_eviction {
    uint64_t entry_id = 0;
    server_cache_eviction_reason reason = server_cache_eviction_reason::over_budget;
};

struct server_cache_eviction_plan {
    std::vector<server_cache_policy_eviction> evictions;
    bool protected_entries_skipped = false;
    bool protected_budget_pressure = false;
    bool budget_unsatisfied = false;
};

class server_cache_policy_lru {
public:
    server_cache_eviction_plan plan_evictions(
        size_t current_resident_bytes,
        size_t budget_bytes,
        bool budget_unlimited,
        const std::vector<server_cache_policy_candidate> & candidates) const;
};
