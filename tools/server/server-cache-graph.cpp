#include "server-cache-graph.h"

#include <algorithm>
#include <queue>
#include <sstream>
#include <unordered_set>

static uint64_t branch_hash_append(uint64_t hash, uint64_t value) {
    hash ^= value;
    hash *= 1099511628211ull;
    return hash;
}

static std::vector<uint64_t> build_prefix_checksums(const std::vector<llama_token> & tokens) {
    std::vector<uint64_t> checksums;
    checksums.reserve(tokens.size());
    uint64_t hash = 1469598103934665603ull;
    for (llama_token token : tokens) {
        hash = branch_hash_append(hash, static_cast<uint64_t>(static_cast<int64_t>(token)));
        checksums.push_back(hash);
    }
    return checksums;
}

branch_node::branch_node(const branch_node & other) {
    *this = other;
}

branch_node & branch_node::operator=(const branch_node & other) {
    if (this == &other) {
        return *this;
    }
    node_id = other.node_id;
    namespace_id = other.namespace_id;
    parent_id = other.parent_id;
    n_tokens = other.n_tokens;
    pos_min = other.pos_min;
    pos_max = other.pos_max;
    token_span = other.token_span;
    token_checksum = other.token_checksum;
    prefix_checksums = other.prefix_checksums;
    use_sequence = other.use_sequence;
    use_count = other.use_count;
    insertion_sequence = other.insertion_sequence;
    residency_state = other.residency_state;
    protected_root = other.protected_root;
    is_metadata_only = other.is_metadata_only;
    absent_reason = other.absent_reason;
    exact_blob_payload_id = other.exact_blob_payload_id;
    checkpoint_payload_id = other.checkpoint_payload_id;
    resident_payload_bytes = other.resident_payload_bytes;
    has_target_payload = other.has_target_payload;
    has_draft_payload = other.has_draft_payload;
    slot_ref_count.store(other.slot_ref_count.load(std::memory_order_relaxed), std::memory_order_relaxed);
    return *this;
}

branch_node::branch_node(branch_node && other) noexcept {
    *this = other;
}

branch_node & branch_node::operator=(branch_node && other) noexcept {
    *this = other;
    return *this;
}

size_t branch_node::metadata_ram_bytes() const {
    size_t sz = sizeof(branch_node);
    sz += namespace_id.size();
    sz += token_span.capacity() * sizeof(llama_token);
    sz += prefix_checksums.capacity() * sizeof(uint64_t);
    return sz;
}

std::string namespace_key::compute() const {
    std::stringstream ss;
    ss << "namespace-v1";
    ss << "|model.path=" << model_path_hash;
    ss << "|model.params=" << model_params_hash;
    ss << "|draft.mode=" << draft_context_mode;
    ss << "|draft=" << draft_model_hash;
    ss << "|tokenizer=" << tokenizer_id;
    ss << "|template=" << template_id;
    ss << "|lora=";
    for (const auto & item : lora_adapters) {
        ss << item << ',';
    }
    ss << "|control=";
    for (const auto & item : control_vectors) {
        ss << item << ',';
    }
    ss << "|mm.projector=" << mm_projector_id;
    ss << "|mm.patch=" << mm_patch_size;
    ss << "|mm.dynamic=" << (mm_use_dynamic_tokens ? 1 : 0);
    ss << "|n_ctx=" << n_ctx;
    ss << "|n_batch=" << n_batch;
    ss << "|kv_unified=" << (kv_unified ? 1 : 0);
    ss << "|workload=" << workload_profile;
    return std::to_string(std::hash<std::string>{}(ss.str()));
}

bool namespace_key::is_compatible(const std::string & ns_a, const std::string & ns_b) {
    return ns_a == ns_b;
}

bool validate_namespace_compatibility(
        const std::string & slot_namespace,
        const std::string & branch_namespace) {
    return namespace_key::is_compatible(slot_namespace, branch_namespace);
}

branch_forest_index::branch_forest_index() = default;

uint64_t branch_forest_index::create_node(
        const std::string & namespace_id,
        uint64_t parent_id,
        const std::vector<llama_token> & tokens,
        int64_t pos_min,
        int64_t pos_max,
        uint64_t token_checksum,
        bool protected_root) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (parent_id != 0 && nodes_.find(parent_id) == nodes_.end()) {
        return 0;
    }

    const uint64_t node_id = next_node_id_.fetch_add(1, std::memory_order_relaxed);
    branch_node node;
    node.node_id = node_id;
    node.namespace_id = namespace_id;
    node.parent_id = parent_id;
    node.n_tokens = static_cast<int64_t>(tokens.size());
    node.pos_min = pos_min;
    node.pos_max = pos_max;
    node.token_span = tokens;
    node.prefix_checksums = build_prefix_checksums(tokens);
    node.token_checksum = token_checksum != 0 ? token_checksum :
        (node.prefix_checksums.empty() ? 0 : node.prefix_checksums.back());
    node.protected_root = protected_root;
    node.insertion_sequence = node_id;

    nodes_.emplace(node_id, std::move(node));
    if (parent_id == 0) {
        namespace_roots_[namespace_id].push_back(node_id);
    } else {
        children_[parent_id].push_back(node_id);
    }
    return node_id;
}

bool branch_forest_index::remove_node(uint64_t node_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        return false;
    }
    if (it->second.slot_ref_count.load(std::memory_order_relaxed) > 0 || it->second.protected_root) {
        return false;
    }
    auto child_it = children_.find(node_id);
    if (child_it != children_.end() && !child_it->second.empty()) {
        return false;
    }

    const uint64_t parent_id = it->second.parent_id;
    if (parent_id == 0) {
        auto root_it = namespace_roots_.find(it->second.namespace_id);
        if (root_it != namespace_roots_.end()) {
            auto & roots = root_it->second;
            roots.erase(std::remove(roots.begin(), roots.end(), node_id), roots.end());
            if (roots.empty()) {
                namespace_roots_.erase(root_it);
            }
        }
    } else {
        auto parent_children = children_.find(parent_id);
        if (parent_children != children_.end()) {
            auto & children = parent_children->second;
            children.erase(std::remove(children.begin(), children.end(), node_id), children.end());
        }
    }
    children_.erase(node_id);
    nodes_.erase(it);
    return true;
}

branch_node * branch_forest_index::get_node(uint64_t node_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    return it == nodes_.end() ? nullptr : &it->second;
}

const branch_node * branch_forest_index::get_node(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    return it == nodes_.end() ? nullptr : &it->second;
}

std::vector<uint64_t> branch_forest_index::find_nodes_by_token_span(
        const std::string & namespace_id,
        const std::vector<llama_token> & prefix,
        size_t min_match_tokens) const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<uint64_t> matches;
    if (prefix.size() < min_match_tokens) {
        return matches;
    }
    for (const auto & item : nodes_) {
        const branch_node & node = item.second;
        if (node.namespace_id != namespace_id || node.token_span.size() < prefix.size()) {
            continue;
        }
        if (std::equal(prefix.begin(), prefix.end(), node.token_span.begin())) {
            matches.push_back(node.node_id);
        }
    }
    std::sort(matches.begin(), matches.end());
    return matches;
}

std::vector<uint64_t> branch_forest_index::find_nodes_by_checksum_span(
        const std::string & namespace_id,
        uint64_t checksum,
        size_t match_tokens) const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<uint64_t> matches;
    if (match_tokens == 0) {
        return matches;
    }
    for (const auto & item : nodes_) {
        const branch_node & node = item.second;
        if (node.namespace_id != namespace_id || node.prefix_checksums.size() < match_tokens) {
            continue;
        }
        if (node.prefix_checksums[match_tokens - 1] == checksum) {
            matches.push_back(node.node_id);
        }
    }
    std::sort(matches.begin(), matches.end());
    return matches;
}

std::vector<uint64_t> branch_forest_index::get_children(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    traversal_counts_.children++;
    auto it = children_.find(node_id);
    return it == children_.end() ? std::vector<uint64_t>{} : it->second;
}

uint64_t branch_forest_index::get_parent(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    return it == nodes_.end() ? 0 : it->second.parent_id;
}

std::vector<uint64_t> branch_forest_index::get_path_to_root(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    traversal_counts_.path_to_root++;
    std::vector<uint64_t> path;
    std::unordered_set<uint64_t> seen;
    uint64_t current = node_id;
    while (current != 0 && seen.insert(current).second) {
        auto it = nodes_.find(current);
        if (it == nodes_.end()) {
            break;
        }
        path.push_back(current);
        current = it->second.parent_id;
    }
    return path;
}

std::vector<uint64_t> branch_forest_index::get_descendants(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    traversal_counts_.descendants++;
    std::vector<uint64_t> descendants;
    std::queue<uint64_t> queue;
    queue.push(node_id);
    while (!queue.empty()) {
        const uint64_t current = queue.front();
        queue.pop();
        auto it = children_.find(current);
        if (it == children_.end()) {
            continue;
        }
        for (uint64_t child : it->second) {
            descendants.push_back(child);
            queue.push(child);
        }
    }
    return descendants;
}

std::vector<std::string> branch_forest_index::get_namespaces() const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::unordered_set<std::string> seen;
    for (const auto & item : nodes_) {
        seen.insert(item.second.namespace_id);
    }
    std::vector<std::string> namespaces(seen.begin(), seen.end());
    std::sort(namespaces.begin(), namespaces.end());
    return namespaces;
}

size_t branch_forest_index::namespace_node_count(const std::string & namespace_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    size_t count = 0;
    for (const auto & item : nodes_) {
        if (item.second.namespace_id == namespace_id) {
            count++;
        }
    }
    return count;
}

std::vector<uint64_t> branch_forest_index::namespace_roots(const std::string & namespace_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = namespace_roots_.find(namespace_id);
    return it == namespace_roots_.end() ? std::vector<uint64_t>{} : it->second;
}

size_t branch_forest_index::total_metadata_ram_bytes() const {
    std::lock_guard<std::mutex> lock(mutex_);
    size_t total = 0;
    for (const auto & item : nodes_) {
        total += item.second.metadata_ram_bytes();
    }
    return total;
}

size_t branch_forest_index::namespace_metadata_ram_bytes(const std::string & namespace_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    size_t total = 0;
    for (const auto & item : nodes_) {
        if (item.second.namespace_id == namespace_id) {
            total += item.second.metadata_ram_bytes();
        }
    }
    return total;
}

bool branch_forest_index::acquire_slot_ref(uint64_t node_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        return false;
    }
    const uint32_t count = it->second.slot_ref_count.fetch_add(1, std::memory_order_relaxed) + 1;
    uint32_t peak = peak_slot_refs_.load(std::memory_order_relaxed);
    while (count > peak && !peak_slot_refs_.compare_exchange_weak(peak, count, std::memory_order_relaxed)) {}
    return true;
}

bool branch_forest_index::release_slot_ref(uint64_t node_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        return false;
    }
    uint32_t current = it->second.slot_ref_count.load(std::memory_order_relaxed);
    while (current > 0) {
        if (it->second.slot_ref_count.compare_exchange_weak(current, current - 1, std::memory_order_relaxed)) {
            return true;
        }
    }
    return false;
}

uint32_t branch_forest_index::slot_ref_count(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    return it == nodes_.end() ? 0 : it->second.slot_ref_count.load(std::memory_order_relaxed);
}

std::vector<uint64_t> branch_forest_index::payload_eviction_candidates(size_t max_count) const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<const branch_node *> unprotected;
    std::vector<const branch_node *> protected_roots;
    for (const auto & item : nodes_) {
        const branch_node & node = item.second;
        if (node.slot_ref_count.load(std::memory_order_relaxed) > 0 || node.exact_blob_payload_id == 0 ||
            node.resident_payload_bytes == 0 || (!node.has_target_payload && !node.has_draft_payload)) {
            continue;
        }
        (node.protected_root ? protected_roots : unprotected).push_back(&node);
    }

    const auto by_lru = [](const branch_node * a, const branch_node * b) {
        if (a->use_sequence != b->use_sequence) {
            return a->use_sequence < b->use_sequence;
        }
        return a->insertion_sequence < b->insertion_sequence;
    };
    std::sort(unprotected.begin(), unprotected.end(), by_lru);
    std::sort(protected_roots.begin(), protected_roots.end(), by_lru);

    std::vector<uint64_t> candidates;
    candidates.reserve(unprotected.size() + protected_roots.size());
    for (const branch_node * node : unprotected) {
        candidates.push_back(node->node_id);
        if (max_count > 0 && candidates.size() >= max_count) {
            return candidates;
        }
    }
    for (const branch_node * node : protected_roots) {
        candidates.push_back(node->node_id);
        if (max_count > 0 && candidates.size() >= max_count) {
            return candidates;
        }
    }
    return candidates;
}

bool branch_forest_index::evict_payload(uint64_t node_id, bool pair_evict) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        return false;
    }
    branch_node & node = it->second;

    if (node.slot_ref_count.load(std::memory_order_relaxed) > 0) {
        return false;
    }

    // Paired payloads share this node descriptor, so clearing the node clears
    // target and draft residency together.
    GGML_UNUSED(pair_evict);

    node.exact_blob_payload_id = 0;
    node.checkpoint_payload_id = 0;
    node.resident_payload_bytes = 0;
    node.has_target_payload = false;
    node.has_draft_payload = false;
    node.is_metadata_only = true;
    node.absent_reason = branch_node::payload_absent_reason::evicted_hot;

    return true;
}

bool branch_forest_index::is_metadata_only_node(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    return it != nodes_.end() && it->second.is_metadata_only;
}

branch_node::payload_absent_reason branch_forest_index::get_payload_absent_reason(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        return branch_node::payload_absent_reason::none;
    }
    return it->second.absent_reason;
}

bool branch_forest_index::prune_node(uint64_t node_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    if (it == nodes_.end()) {
        return false;
    }
    const branch_node & node = it->second;

    // Reject if active slot references
    if (node.slot_ref_count.load(std::memory_order_relaxed) > 0) {
        return false;
    }

    // Reject if protected root
    if (node.protected_root) {
        return false;
    }

    // Reject if has retained descendants
    auto child_it = children_.find(node_id);
    if (child_it != children_.end() && !child_it->second.empty()) {
        return false;
    }

    // Remove from parent's children list
    const uint64_t parent_id = node.parent_id;
    if (parent_id == 0) {
        auto root_it = namespace_roots_.find(node.namespace_id);
        if (root_it != namespace_roots_.end()) {
            auto & roots = root_it->second;
            roots.erase(std::remove(roots.begin(), roots.end(), node_id), roots.end());
            if (roots.empty()) {
                namespace_roots_.erase(root_it);
            }
        }
    } else {
        auto parent_children = children_.find(parent_id);
        if (parent_children != children_.end()) {
            auto & children = parent_children->second;
            children.erase(std::remove(children.begin(), children.end(), node_id), children.end());
        }
    }

    // Remove from children index
    children_.erase(node_id);

    // Remove the node
    nodes_.erase(it);
    return true;
}

std::vector<uint64_t> branch_forest_index::find_equivalent_nodes(
        const std::string & namespace_id,
        const std::vector<llama_token> & token_path,
        int64_t pos_min,
        int64_t pos_max) const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<uint64_t> result;
    for (const auto & item : nodes_) {
        const branch_node & node = item.second;
        if (node.namespace_id != namespace_id) {
            continue;
        }
        if (node.n_tokens != static_cast<int64_t>(token_path.size())) {
            continue;
        }
        if (node.pos_min != pos_min || node.pos_max != pos_max) {
            continue;
        }
        if (node.token_span.size() != token_path.size()) {
            continue;
        }
        if (!std::equal(token_path.begin(), token_path.end(), node.token_span.begin())) {
            continue;
        }
        result.push_back(node.node_id);
    }
    return result;
}

uint64_t branch_forest_index::canonical_node_id(
        const std::string & namespace_id,
        const std::vector<llama_token> & token_path,
        int64_t pos_min,
        int64_t pos_max) const {
    auto equiv = find_equivalent_nodes(namespace_id, token_path, pos_min, pos_max);
    if (equiv.empty()) {
        return 0;
    }

    // Deterministic ordering:
    // 1. Payload-bearing before metadata-only
    // 2. More descendants before fewer
    // 3. Protected-root ancestry before unprotected
    // 4. Newer use_sequence
    // 5. Lower insertion_sequence
    // 6. Lower node_id
    uint64_t best = equiv[0];
    for (size_t i = 1; i < equiv.size(); i++) {
        const uint64_t candidate = equiv[i];
        const branch_node * best_node = nullptr;
        const branch_node * cand_node = nullptr;
        {
            auto it = nodes_.find(best);
            if (it != nodes_.end()) best_node = &it->second;
        }
        {
            auto it = nodes_.find(candidate);
            if (it != nodes_.end()) cand_node = &it->second;
        }
        if (!best_node || !cand_node) continue;

        // 1. Payload-bearing before metadata-only
        if (best_node->is_metadata_only != cand_node->is_metadata_only) {
            if (!cand_node->is_metadata_only) {
                best = candidate;
            }
            continue;
        }

        // 2. More descendants before fewer
        auto best_desc = children_.find(best);
        auto cand_desc = children_.find(candidate);
        const size_t best_desc_count = (best_desc != children_.end()) ? best_desc->second.size() : 0;
        const size_t cand_desc_count = (cand_desc != children_.end()) ? cand_desc->second.size() : 0;
        if (best_desc_count != cand_desc_count) {
            if (cand_desc_count > best_desc_count) {
                best = candidate;
            }
            continue;
        }

        // 3. Protected-root ancestry
        if (best_node->protected_root != cand_node->protected_root) {
            if (cand_node->protected_root) {
                best = candidate;
            }
            continue;
        }

        // 4. Newer use_sequence
        if (best_node->use_sequence != cand_node->use_sequence) {
            if (cand_node->use_sequence > best_node->use_sequence) {
                best = candidate;
            }
            continue;
        }

        // 5. Lower insertion_sequence
        if (best_node->insertion_sequence != cand_node->insertion_sequence) {
            if (cand_node->insertion_sequence < best_node->insertion_sequence) {
                best = candidate;
            }
            continue;
        }

        // 6. Lower node_id
        if (cand_node->node_id < best_node->node_id) {
            best = candidate;
        }
    }
    return best;
}

std::vector<uint64_t> branch_forest_index::rank_candidates(
        const std::string & namespace_id,
        const std::vector<uint64_t> & candidate_ids,
        const std::vector<llama_token> & request_tokens) const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<uint64_t> result = candidate_ids;

    // Sort by 8-tier tie-breaking:
    // 1. Same namespace only (already filtered)
    // 2. Longest token match
    // 3. Highest checksum confidence for same token length
    // 4. Payload-bearing before metadata-only
    // 5. Higher protected-root ancestry score
    // 6. Newer use_sequence
    // 7. Lower insertion_sequence
    // 8. Lower node_id
    std::sort(result.begin(), result.end(),
        [&](uint64_t a, uint64_t b) {
            const branch_node * node_a = nullptr;
            const branch_node * node_b = nullptr;
            {
                auto it = nodes_.find(a);
                if (it != nodes_.end()) node_a = &it->second;
            }
            {
                auto it = nodes_.find(b);
                if (it != nodes_.end()) node_b = &it->second;
            }
            if (!node_a || !node_b) return node_a != nullptr;

            // 2. Longest token match
            size_t match_a = 0;
            size_t match_b = 0;
            for (size_t i = 0; i < node_a->token_span.size() && i < request_tokens.size(); i++) {
                if (node_a->token_span[i] == request_tokens[i]) match_a++; else break;
            }
            for (size_t i = 0; i < node_b->token_span.size() && i < request_tokens.size(); i++) {
                if (node_b->token_span[i] == request_tokens[i]) match_b++; else break;
            }
            if (match_a != match_b) return match_a > match_b;

            // 3. Checksum confidence (prefix checksum match at match length)
            if (match_a > 0 && match_a <= node_a->prefix_checksums.size() &&
                match_b > 0 && match_b <= node_b->prefix_checksums.size()) {
                // Both have checksums at match length, prefer higher confidence
                // (For now, checksum confidence is binary: match or no match)
                const bool checksum_a_ok = (match_a <= node_a->prefix_checksums.size());
                const bool checksum_b_ok = (match_b <= node_b->prefix_checksums.size());
                if (checksum_a_ok != checksum_b_ok) return checksum_a_ok;
            }

            // 4. Payload-bearing before metadata-only
            if (node_a->is_metadata_only != node_b->is_metadata_only) {
                return !node_a->is_metadata_only;
            }

            // 5. Higher protected-root ancestry score
            if (node_a->protected_root != node_b->protected_root) {
                return node_a->protected_root;
            }

            // 6. Newer use_sequence
            if (node_a->use_sequence != node_b->use_sequence) {
                return node_a->use_sequence > node_b->use_sequence;
            }

            // 7. Lower insertion_sequence
            if (node_a->insertion_sequence != node_b->insertion_sequence) {
                return node_a->insertion_sequence < node_b->insertion_sequence;
            }

            // 8. Lower node_id
            return node_a->node_id < node_b->node_id;
        });

    return result;
}

uint64_t branch_forest_index::select_mismatch_parent(
        const std::string & namespace_id,
        const std::vector<llama_token> & request_tokens,
        const std::vector<uint64_t> & candidate_ids) const {
    auto ranked = rank_candidates(namespace_id, candidate_ids, request_tokens);
    if (ranked.empty()) {
        return 0;
    }

    // Find the deepest validated ancestor among ranked candidates
    uint64_t best_parent = 0;
    size_t best_match = 0;

    for (uint64_t id : ranked) {
        const branch_node * node = nullptr;
        {
            auto it = nodes_.find(id);
            if (it != nodes_.end()) node = &it->second;
        }
        if (!node) continue;

        // Walk path to root, find deepest node whose tokens match
        std::vector<uint64_t> path;
        uint64_t current = id;
        std::unordered_set<uint64_t> seen;
        while (current != 0 && seen.insert(current).second) {
            auto it = nodes_.find(current);
            if (it == nodes_.end()) break;
            path.push_back(current);
            current = it->second.parent_id;
        }

        for (auto it = path.rbegin(); it != path.rend(); ++it) {
            const branch_node * path_node = nullptr;
            {
                auto pit = nodes_.find(*it);
                if (pit != nodes_.end()) path_node = &pit->second;
            }
            if (!path_node) continue;

            size_t match = 0;
            for (size_t i = 0; i < path_node->token_span.size() && i < request_tokens.size(); i++) {
                if (path_node->token_span[i] == request_tokens[i]) match++; else break;
            }
            if (match > best_match) {
                best_match = match;
                best_parent = *it;
            }
        }
    }

    return best_parent;
}

rematerialization_plan branch_forest_index::plan_rematerialization(
        const std::string & namespace_id,
        const std::vector<llama_token> & request_tokens,
        uint64_t selected_node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    rematerialization_plan plan;
    plan.selected_node_id = selected_node_id;

    auto sel_it = nodes_.find(selected_node_id);
    if (sel_it == nodes_.end()) {
        plan.fallback_reason = cache_fallback_reason::no_payload_ancestor;
        return plan;
    }

    // Build path from selected node to root
    std::vector<uint64_t> path;
    uint64_t current = selected_node_id;
    std::unordered_set<uint64_t> seen;
    while (current != 0 && seen.insert(current).second) {
        auto it = nodes_.find(current);
        if (it == nodes_.end()) break;
        path.push_back(current);
        current = it->second.parent_id;
    }
    plan.path_node_ids = path;

    // Find nearest payload-bearing ancestor
    uint64_t payload_ancestor = 0;
    for (uint64_t id : path) {
        auto it = nodes_.find(id);
        if (it != nodes_.end() && !it->second.is_metadata_only &&
            it->second.exact_blob_payload_id != 0) {
            payload_ancestor = id;
            break;
        }
    }

    if (payload_ancestor == 0) {
        plan.fallback_reason = cache_fallback_reason::no_payload_ancestor;
        return plan;
    }
    plan.source_payload_node_id = payload_ancestor;

    // Validate each segment from payload ancestor to selected node
    uint64_t deepest_validated = payload_ancestor;
    size_t validated_tokens = 0;
    bool found_mismatch = false;

    // Walk from payload ancestor down to selected node
    // (path is from selected to root, so iterate in reverse)
    bool start_validating = false;
    for (auto it = path.rbegin(); it != path.rend(); ++it) {
        auto node_it = nodes_.find(*it);
        if (!start_validating) {
            if (*it == payload_ancestor) {
                start_validating = true;
                // Validate payload ancestor's tokens
                const branch_node & ancestor = node_it->second;
                size_t match = 0;
                for (size_t i = 0; i < ancestor.token_span.size() && i < request_tokens.size(); i++) {
                    if (ancestor.token_span[i] == request_tokens[i]) match++; else break;
                }
                if (match < ancestor.token_span.size()) {
                    found_mismatch = true;
                    plan.mismatch_node_id = *it;
                    break;
                }
                validated_tokens += ancestor.token_span.size();
                deepest_validated = *it;
            }
            continue;
        }

        // Validate this segment
        const branch_node & segment = node_it->second;
        size_t match = 0;
        for (size_t i = 0; i < segment.token_span.size() && i < request_tokens.size(); i++) {
            if (segment.token_span[i] == request_tokens[i]) match++; else break;
        }
        if (match < segment.token_span.size()) {
            found_mismatch = true;
            plan.mismatch_node_id = *it;
            break;
        }
        validated_tokens += segment.token_span.size();
        deepest_validated = *it;
    }

    plan.deepest_validated_node_id = deepest_validated;
    plan.validated_tokens = validated_tokens;

    if (found_mismatch) {
        plan.fallback_reason = cache_fallback_reason::validation_mismatch;
    }

    return plan;
}

std::vector<uint64_t> branch_forest_index::metadata_prune_candidates() const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<uint64_t> candidates;

    for (const auto & item : nodes_) {
        const branch_node & node = item.second;

        // Must be metadata-only
        if (!node.is_metadata_only) {
            continue;
        }

        // No active slot references
        if (node.slot_ref_count.load(std::memory_order_relaxed) > 0) {
            continue;
        }

        // Not a protected root
        if (node.protected_root) {
            continue;
        }

        // No retained descendants
        auto child_it = children_.find(item.first);
        if (child_it != children_.end() && !child_it->second.empty()) {
            continue;
        }

        candidates.push_back(item.first);
    }

    // Sort by pruning score: oldest use_sequence first, then oldest insertion_sequence
    std::sort(candidates.begin(), candidates.end(),
        [&](uint64_t a, uint64_t b) {
            const branch_node * node_a = nullptr;
            const branch_node * node_b = nullptr;
            {
                auto it = nodes_.find(a);
                if (it != nodes_.end()) node_a = &it->second;
            }
            {
                auto it = nodes_.find(b);
                if (it != nodes_.end()) node_b = &it->second;
            }
            if (!node_a || !node_b) return node_a != nullptr;

            if (node_a->use_sequence != node_b->use_sequence) {
                return node_a->use_sequence < node_b->use_sequence;
            }
            return node_a->insertion_sequence < node_b->insertion_sequence;
        });

    return candidates;
}

size_t branch_forest_index::enforce_metadata_budget(size_t soft_max_bytes) {
    if (soft_max_bytes == 0) {
        return 0;
    }

    size_t total_freed = 0;
    size_t current_bytes = total_metadata_ram_bytes();

    while (current_bytes > soft_max_bytes) {
        auto candidates = metadata_prune_candidates();
        if (candidates.empty()) {
            break;
        }

        // Prune the best candidate (first in sorted order)
        const uint64_t node_id = candidates.front();
        const branch_node * node = nullptr;
        {
            auto it = nodes_.find(node_id);
            if (it != nodes_.end()) node = &it->second;
        }
        if (!node) {
            break;
        }

        const size_t node_bytes = node->metadata_ram_bytes();
        if (prune_node(node_id)) {
            total_freed += node_bytes;
            if (current_bytes >= node_bytes) {
                current_bytes -= node_bytes;
            } else {
                current_bytes = 0;
            }
        } else {
            break;
        }
    }

    return total_freed;
}

std::unordered_set<uint64_t> branch_forest_index::cleanup_cold() const {
    std::lock_guard<std::mutex> lock(mutex_);

    // Collect all descriptor IDs referenced by retained branch nodes
    std::unordered_set<uint64_t> referenced_ids;
    for (const auto & item : nodes_) {
        const branch_node & node = item.second;
        if (node.exact_blob_payload_id != 0) {
            referenced_ids.insert(node.exact_blob_payload_id);
        }
        if (node.checkpoint_payload_id != 0) {
            referenced_ids.insert(node.checkpoint_payload_id);
        }
    }

    // The safe-to-delete set is empty for now - the caller (hybrid controller)
    // will compute the difference against all known cold descriptor IDs.
    // We return the referenced set so the caller can determine what's safe.
    return referenced_ids;
}

bool branch_forest_index::is_protected(uint64_t node_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodes_.find(node_id);
    return it != nodes_.end() && it->second.protected_root;
}

size_t branch_forest_index::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return nodes_.size();
}

size_t branch_forest_index::active_slot_refs() const {
    std::lock_guard<std::mutex> lock(mutex_);
    size_t total = 0;
    for (const auto & item : nodes_) {
        total += item.second.slot_ref_count.load(std::memory_order_relaxed);
    }
    return total;
}

uint32_t branch_forest_index::peak_slot_refs() const {
    return peak_slot_refs_.load(std::memory_order_relaxed);
}

branch_traversal_counts branch_forest_index::traversal_counts() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return traversal_counts_;
}
