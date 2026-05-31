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
