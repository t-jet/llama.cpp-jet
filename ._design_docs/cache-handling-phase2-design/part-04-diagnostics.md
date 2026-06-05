# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 4: Diagnostics

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

#### Diagnostics

Status note, 2026-05-25: the initial upstream target does not add `/cache/stats` and does not add cache data to `/health`. Keep cache observability on the existing Prometheus `/metrics` endpoint. Sections below that describe `/health.cache` or `/cache/stats` are earlier phase 2 notes, not current requirements.

Add logging for boundary extraction:

```cpp
void log_boundary_metadata(const prepared_prompt_metadata & metadata) {
    if (metadata.boundaries.empty()) {
        LOG_WRN("No boundary metadata available\n");
        return;
    }
    
    LOG_INF("Boundary metadata:\n");
    for (const auto & boundary : metadata.boundaries) {
        const char * type_str = boundary_type_to_string(boundary.type);
        LOG_INF("  %s at token offset %d\n", type_str, boundary.token_offset);
    }
}

const char * boundary_type_to_string(boundary_type type) {
    switch (type) {
        case boundary_type::SYSTEM_START:    return "SYSTEM_START";
        case boundary_type::SYSTEM_END:      return "SYSTEM_END";
        case boundary_type::MESSAGE_START:   return "MESSAGE_START";
        case boundary_type::MESSAGE_END:     return "MESSAGE_END";
        case boundary_type::TOOL_CALL_START: return "TOOL_CALL_START";
        case boundary_type::TOOL_CALL_END:   return "TOOL_CALL_END";
        default:                             return "UNKNOWN";
    }
}
```

---

### Component 3: Statistics Endpoint Integration

**File**: `tools/server/server-http.cpp`

#### Cache Statistics Structure

```cpp
// In server-cache-controller.h
struct cache_statistics {
    std::string cache_type;         // "legacy" or "hybrid"
    size_t size_bytes;              // Current cache size
    size_t size_mib;                // Size in MiB
    size_t max_size_bytes;          // Budget limit
    size_t n_tokens;                // Total tokens cached
    size_t n_entries;               // Number of entries
    
    // Hybrid-specific metrics
    uint64_t n_hits;                // Cache hits
    uint64_t n_misses;              // Cache misses
    uint64_t n_evictions;           // Eviction events
    uint64_t n_save_failures;       // Save failures
    uint64_t n_load_failures;       // Load failures
    
    // Namespace information
    std::vector<uint64_t> active_namespaces;
    
    // Computed metrics
    double hit_rate() const {
        uint64_t total = n_hits + n_misses;
        return total > 0 ? (double)n_hits / total : 0.0;
    }
    
    double utilization() const {
        return max_size_bytes > 0 ? 
               (double)size_bytes / max_size_bytes : 0.0;
    }
};
```

#### Health Endpoint Extension

Extend existing `/health` endpoint:

```cpp
// In server-http.cpp
json handle_health_request(server_context & ctx) {
    json health;
    
    // Existing health metrics
    health["status"] = "ok";
    health["slots_idle"] = ctx.slots_idle();
    health["slots_processing"] = ctx.slots_processing();
    
    // NEW: Add cache statistics summary
    if (ctx.cache_controller_available()) {
        cache_statistics stats = ctx.get_cache_stats();
        
        json cache_summary;
        cache_summary["type"] = stats.cache_type;
        cache_summary["utilization_pct"] = stats.utilization() * 100.0;
        cache_summary["entries"] = stats.n_entries;
        cache_summary["size_mib"] = stats.size_mib;
        
        if (stats.cache_type == "hybrid") {
            cache_summary["hit_rate_pct"] = stats.hit_rate() * 100.0;
            cache_summary["hits"] = stats.n_hits;
            cache_summary["misses"] = stats.n_misses;
        }
        
        health["cache"] = cache_summary;
    }
    
    return health;
}
```

Example `/health` response with cache:

```json
{
  "status": "ok",
  "slots_idle": 2,
  "slots_processing": 1,
  "cache": {
    "type": "hybrid",
    "utilization_pct": 67.5,
    "entries": 12,
    "size_mib": 1350,
    "hit_rate_pct": 85.3,
    "hits": 523,
    "misses": 90
  }
}
```

#### Dedicated Cache Stats Endpoint

New endpoint for detailed cache metrics:

```cpp
// GET /cache/stats
json handle_cache_stats_request(server_context & ctx, 
                               const std::string & format = "json") {
    if (!ctx.cache_controller_available()) {
        json error;
        error["error"] = "Cache controller not available";
        return error;
    }
    
    cache_statistics stats = ctx.get_cache_stats();
    
    if (format == "prometheus") {
        return format_cache_stats_prometheus(stats);
    }
    
    // Default: JSON format
    json result;
    result["cache_type"] = stats.cache_type;
    result["size_bytes"] = stats.size_bytes;
    result["size_mib"] = stats.size_mib;
    result["max_size_bytes"] = stats.max_size_bytes;
    result["utilization"] = stats.utilization();
    result["n_tokens"] = stats.n_tokens;
    result["n_entries"] = stats.n_entries;
    
    if (stats.cache_type == "hybrid") {
        result["n_hits"] = stats.n_hits;
        result["n_misses"] = stats.n_misses;
        result["n_evictions"] = stats.n_evictions;
        result["hit_rate"] = stats.hit_rate();
        result["n_save_failures"] = stats.n_save_failures;
        result["n_load_failures"] = stats.n_load_failures;
        
        json namespaces = json::array();
        for (uint64_t ns_id : stats.active_namespaces) {
            namespaces.push_back(ns_id);
        }
        result["active_namespaces"] = namespaces;
    }
    
    return result;
}
```

Example `/cache/stats` response:

```json
{
  "cache_type": "hybrid",
  "size_bytes": 1415577600,
  "size_mib": 1350,
  "max_size_bytes": 2097152000,
  "utilization": 0.675,
  "n_tokens": 89234,
  "n_entries": 12,
  "n_hits": 523,
  "n_misses": 90,
  "n_evictions": 3,
  "hit_rate": 0.853,
  "n_save_failures": 0,
  "n_load_failures": 0,
  "active_namespaces": [12345]
}
```

#### Prometheus Format Support

```cpp
json format_cache_stats_prometheus(const cache_statistics & stats) {
    std::stringstream ss;
    
    ss << "# HELP cache_size_bytes Current cache size in bytes\n";
    ss << "# TYPE cache_size_bytes gauge\n";
    ss << "cache_size_bytes " << stats.size_bytes << "\n\n";
    
    ss << "# HELP cache_utilization Cache utilization ratio (0-1)\n";
    ss << "# TYPE cache_utilization gauge\n";
    ss << "cache_utilization " << stats.utilization() << "\n\n";
    
    ss << "# HELP cache_entries_total Number of cached entries\n";
    ss << "# TYPE cache_entries_total gauge\n";
    ss << "cache_entries_total " << stats.n_entries << "\n\n";
    
    if (stats.cache_type == "hybrid") {
        ss << "# HELP cache_hits_total Total cache hits\n";
        ss << "# TYPE cache_hits_total counter\n";
        ss << "cache_hits_total " << stats.n_hits << "\n\n";
        
        ss << "# HELP cache_misses_total Total cache misses\n";
        ss << "# TYPE cache_misses_total counter\n";
        ss << "cache_misses_total " << stats.n_misses << "\n\n";
        
        ss << "# HELP cache_evictions_total Total eviction events\n";
        ss << "# TYPE cache_evictions_total counter\n";
        ss << "cache_evictions_total " << stats.n_evictions << "\n\n";
        
        ss << "# HELP cache_hit_rate Hit rate ratio (0-1)\n";
        ss << "# TYPE cache_hit_rate gauge\n";
        ss << "cache_hit_rate " << stats.hit_rate() << "\n\n";
    }
    
    json result;
    result["content_type"] = "text/plain; version=0.0.4";
    result["body"] = ss.str();
    return result;
}
```

#### Endpoint Registration

```cpp
// In server-http.cpp initialization
void register_endpoints(httplib::Server & svr, server_context & ctx) {
    // Existing endpoints...
    
    // NEW: Cache statistics endpoint
    svr.Get("/cache/stats", [&ctx](const httplib::Request & req, 
                                   httplib::Response & res) {
        std::string format = req.get_param_value("format");
        if (format.empty()) {
            format = "json";
        }
        
        json stats = handle_cache_stats_request(ctx, format);
        
        if (format == "prometheus") {
            res.set_content(stats["body"], stats["content_type"]);
        } else {
            res.set_content(stats.dump(), "application/json");
        }
    });
}
```

---

