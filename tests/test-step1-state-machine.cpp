// Step 1 focused test: Transient residency states and full state machine
// This test verifies the can_transition function, enum values, and debug fault injection
// for the demoting and promoting transient states added in Stage 6 Step 1.

#include "server-cache-hybrid.h"
#include "server-cache-controller.h"
#include "server-cache-policy-lru.h"
#include "server-task.h"
#include "common.h"

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

// Custom assertion macro that works in both Debug and Release modes.
// Uses exit() instead of abort() for graceful termination.
#define TEST_ASSERT(cond) \
    do { \
        if (!(cond)) { \
            fprintf(stderr, "TEST FAILED: %s at %s:%d\n", __func__, __FILE__, __LINE__); \
            exit(1); \
        } \
    } while (0)

// Helper to create mock tokens
static server_tokens create_tokens(const std::vector<int> & ids) {
    server_tokens tokens;
    for (int id : ids) {
        tokens.push_back(id);
    }
    return tokens;
}

// Helper to create test common_params
static common_params create_test_params(
    const std::string & model_path = "test_model.gguf",
    const std::string & chat_template = "",
    const std::string & mmproj_path = "",
    bool kv_unified_val = false
) {
    common_params params;
    params.model.path = model_path;
    params.chat_template = chat_template;
    params.mmproj.path = mmproj_path;
    params.kv_unified = kv_unified_val;
    return params;
}

// Test 1: can_transition validates all allowed transitions
void test_can_transition_allowed() {
    printf("step1: can_transition allowed transitions...\n");

    // Valid transitions from hot
    TEST_ASSERT(can_transition(payload_residency_state::hot, payload_residency_state::demoting));
    TEST_ASSERT(can_transition(payload_residency_state::hot, payload_residency_state::evicted));

    // Valid transitions from demoting
    TEST_ASSERT(can_transition(payload_residency_state::demoting, payload_residency_state::cold));
    TEST_ASSERT(can_transition(payload_residency_state::demoting, payload_residency_state::hot));
    TEST_ASSERT(can_transition(payload_residency_state::demoting, payload_residency_state::evicted));

    // Valid transitions from promoting
    TEST_ASSERT(can_transition(payload_residency_state::promoting, payload_residency_state::hot));
    TEST_ASSERT(can_transition(payload_residency_state::promoting, payload_residency_state::cold));
    TEST_ASSERT(can_transition(payload_residency_state::promoting, payload_residency_state::evicted));

    // Valid transitions from cold
    TEST_ASSERT(can_transition(payload_residency_state::cold, payload_residency_state::promoting));
    TEST_ASSERT(can_transition(payload_residency_state::cold, payload_residency_state::evicted));

    printf("  PASSED\n");
}

// Test 2: can_transition rejects all disallowed transitions
void test_can_transition_disallowed() {
    printf("step1: can_transition disallowed transitions...\n");

    // No transitions from evicted
    TEST_ASSERT(!can_transition(payload_residency_state::evicted, payload_residency_state::hot));
    TEST_ASSERT(!can_transition(payload_residency_state::evicted, payload_residency_state::demoting));
    TEST_ASSERT(!can_transition(payload_residency_state::evicted, payload_residency_state::promoting));
    TEST_ASSERT(!can_transition(payload_residency_state::evicted, payload_residency_state::cold));
    TEST_ASSERT(!can_transition(payload_residency_state::evicted, payload_residency_state::evicted));

    // Invalid transitions from hot
    TEST_ASSERT(!can_transition(payload_residency_state::hot, payload_residency_state::hot));
    TEST_ASSERT(!can_transition(payload_residency_state::hot, payload_residency_state::promoting));
    TEST_ASSERT(!can_transition(payload_residency_state::hot, payload_residency_state::cold));

    // Invalid transitions from demoting
    TEST_ASSERT(!can_transition(payload_residency_state::demoting, payload_residency_state::demoting));
    TEST_ASSERT(!can_transition(payload_residency_state::demoting, payload_residency_state::promoting));

    // Invalid transitions from promoting
    TEST_ASSERT(!can_transition(payload_residency_state::promoting, payload_residency_state::demoting));
    TEST_ASSERT(!can_transition(payload_residency_state::promoting, payload_residency_state::promoting));

    // Invalid transitions from cold
    TEST_ASSERT(!can_transition(payload_residency_state::cold, payload_residency_state::hot));
    TEST_ASSERT(!can_transition(payload_residency_state::cold, payload_residency_state::cold));
    TEST_ASSERT(!can_transition(payload_residency_state::cold, payload_residency_state::demoting));

    printf("  PASSED\n");
}

// Test 3: Enum has exactly five distinct values
void test_enum_five_values() {
    printf("step1: enum has five distinct values...\n");

    auto hot = payload_residency_state::hot;
    auto demoting = payload_residency_state::demoting;
    auto promoting = payload_residency_state::promoting;
    auto cold = payload_residency_state::cold;
    auto evicted = payload_residency_state::evicted;

    // All five values must be distinct
    TEST_ASSERT(hot != demoting);
    TEST_ASSERT(hot != promoting);
    TEST_ASSERT(hot != cold);
    TEST_ASSERT(hot != evicted);
    TEST_ASSERT(demoting != promoting);
    TEST_ASSERT(demoting != cold);
    TEST_ASSERT(demoting != evicted);
    TEST_ASSERT(promoting != cold);
    TEST_ASSERT(promoting != evicted);
    TEST_ASSERT(cold != evicted);

    printf("  PASSED\n");
}

// Test 4: Descriptor residency defaults to hot
void test_descriptor_default_hot() {
    printf("step1: descriptor residency defaults to hot...\n");

    payload_descriptor descriptor;
    TEST_ASSERT(descriptor.residency == payload_residency_state::hot);
    TEST_ASSERT(descriptor.payload_id == 0);
    TEST_ASSERT(descriptor.store_ref.id == 0);

    printf("  PASSED\n");
}

// Test 5: Descriptor can be set to each residency state
void test_descriptor_residency_assignment() {
    printf("step1: descriptor residency assignment...\n");

    payload_descriptor descriptor;

    descriptor.residency = payload_residency_state::hot;
    TEST_ASSERT(descriptor.residency == payload_residency_state::hot);

    descriptor.residency = payload_residency_state::demoting;
    TEST_ASSERT(descriptor.residency == payload_residency_state::demoting);

    descriptor.residency = payload_residency_state::promoting;
    TEST_ASSERT(descriptor.residency == payload_residency_state::promoting);

    descriptor.residency = payload_residency_state::cold;
    TEST_ASSERT(descriptor.residency == payload_residency_state::cold);

    descriptor.residency = payload_residency_state::evicted;
    TEST_ASSERT(descriptor.residency == payload_residency_state::evicted);

    printf("  PASSED\n");
}

// Test 6: Debug fault injection for demoting and promoting states
void test_debug_fault_injection_transient_states() {
    printf("step1: debug fault injection transient states...\n");

    common_params params = create_test_params();

    // Inject demoting residency state
    hybrid_cache_controller ctrl1(params, 2, 1000, nullptr, nullptr);
    ctrl1.debug_add_entry_for_tests(create_tokens({1, 2}), false, "transient", 128, 0);
    TEST_ASSERT(ctrl1.debug_inject_first_payload_fault_for_tests(payload_debug_fault::demoting_residency));
    json demoting_stats = ctrl1.get_stats();
    TEST_ASSERT(demoting_stats["n_demoting_payload_descriptors"] == 1);

    // Inject promoting residency state
    hybrid_cache_controller ctrl2(params, 2, 1000, nullptr, nullptr);
    ctrl2.debug_add_entry_for_tests(create_tokens({3, 4}), false, "transient", 128, 0);
    TEST_ASSERT(ctrl2.debug_inject_first_payload_fault_for_tests(payload_debug_fault::promoting_residency));
    json promoting_stats = ctrl2.get_stats();
    TEST_ASSERT(promoting_stats["n_promoting_payload_descriptors"] == 1);

    printf("  PASSED\n");
}

// Test 7: Transition table completeness - every allowed transition is reachable
void test_transition_table_completeness() {
    printf("step1: transition table completeness...\n");

    // Count all allowed transitions
    int allowed_count = 0;
    payload_residency_state states[] = {
        payload_residency_state::hot,
        payload_residency_state::demoting,
        payload_residency_state::promoting,
        payload_residency_state::cold,
        payload_residency_state::evicted,
    };

    for (auto from : states) {
        for (auto to : states) {
            if (can_transition(from, to)) {
                allowed_count++;
            }
        }
    }

    // Expected: hot->demoting, hot->evicted, demoting->cold, demoting->hot, demoting->evicted,
    //           promoting->hot, promoting->cold, promoting->evicted,
    //           cold->promoting, cold->evicted = 10 allowed transitions
    TEST_ASSERT(allowed_count == 10);

    printf("  PASSED\n");
}

// Test 8: Evicted is a terminal state
void test_evicted_is_terminal() {
    printf("step1: evicted is terminal...\n");

    payload_residency_state states[] = {
        payload_residency_state::hot,
        payload_residency_state::demoting,
        payload_residency_state::promoting,
        payload_residency_state::cold,
        payload_residency_state::evicted,
    };

    for (auto to : states) {
        TEST_ASSERT(!can_transition(payload_residency_state::evicted, to));
    }

    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("Step 1: Transient residency states and state machine\n");
    printf("==================================================\n\n");

    test_can_transition_allowed();
    test_can_transition_disallowed();
    test_enum_five_values();
    test_descriptor_default_hot();
    test_descriptor_residency_assignment();
    test_debug_fault_injection_transient_states();
    test_transition_table_completeness();
    test_evicted_is_terminal();

    printf("\n==================================================\n");
    printf("All Step 1 tests passed! (8 tests)\n");
    printf("==================================================\n");

    return 0;
}