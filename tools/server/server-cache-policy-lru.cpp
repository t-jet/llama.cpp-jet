#include "server-cache-policy-lru.h"

#include <algorithm>

server_cache_eviction_plan server_cache_policy_lru::plan_evictions(
    size_t current_resident_bytes,
    size_t budget_bytes,
    bool budget_unlimited,
    const std::vector<server_cache_policy_candidate> & candidates) const {
    server_cache_eviction_plan plan;

    if (budget_unlimited || budget_bytes == 0 || current_resident_bytes <= budget_bytes) {
        return plan;
    }

    std::vector<server_cache_policy_candidate> ordered = candidates;
    std::sort(ordered.begin(), ordered.end(), [](const auto & lhs, const auto & rhs) {
        if (lhs.protected_root != rhs.protected_root) {
            return !lhs.protected_root;
        }
        if (lhs.use_sequence != rhs.use_sequence) {
            return lhs.use_sequence < rhs.use_sequence;
        }
        if (lhs.insertion_sequence != rhs.insertion_sequence) {
            return lhs.insertion_sequence < rhs.insertion_sequence;
        }
        return lhs.entry_id < rhs.entry_id;
    });

    const bool has_protected = std::any_of(ordered.begin(), ordered.end(), [](const auto & candidate) {
        return candidate.protected_root;
    });

    size_t remaining = current_resident_bytes;
    bool evicted_unprotected = false;

    for (const auto & candidate : ordered) {
        if (remaining <= budget_bytes) {
            break;
        }

        if (candidate.protected_root && !plan.protected_budget_pressure) {
            plan.protected_budget_pressure = true;
        }

        const auto reason = candidate.protected_root
            ? server_cache_eviction_reason::protected_budget_pressure
            : server_cache_eviction_reason::over_budget;

        plan.evictions.push_back({candidate.entry_id, reason});
        remaining = candidate.resident_payload_bytes >= remaining ? 0 : remaining - candidate.resident_payload_bytes;
        evicted_unprotected = evicted_unprotected || !candidate.protected_root;
    }

    plan.protected_entries_skipped = has_protected && evicted_unprotected && !plan.protected_budget_pressure;
    plan.budget_unsatisfied = remaining > budget_bytes;
    return plan;
}
