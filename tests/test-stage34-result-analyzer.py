def stage34_cached_tokens(response):
    if response is None:
        return 0
    details = response.get("usage", {}).get("prompt_tokens_details", {})
    if "cached_tokens" in details:
        return details["cached_tokens"]
    return response.get("timings", {}).get("cache_n", 0)


def stage34_join_verdict(expected_result, response_row):
    cached = 0
    http_status = None
    has_response = False
    if response_row is not None:
        http_status = response_row.get("http_status")
        response = response_row.get("response")
        has_response = response is not None
        cached = stage34_cached_tokens(response)
    if expected_result == "hit":
        if http_status != 200:
            return "FAIL-http"
        if not has_response:
            return "FAIL-null-response"
        if cached <= 0:
            return "FAIL-cache-miss"
    return "PASS"


def stage34_expected_budget_reason(token_count, hot_budget_mib, estimated_payload_mib_per_token):
    estimated_payload_mib = token_count * estimated_payload_mib_per_token
    if estimated_payload_mib > hot_budget_mib:
        return "EXPECTED-HOT-BUDGET-SAVE-REJECTED"
    return ""


def test_stage34_cached_tokens_prefers_chat_usage_details():
    response = {
        "usage": {
            "prompt_tokens_details": {
                "cached_tokens": 1911,
            },
        },
        "timings": {
            "cache_n": 0,
        },
    }

    assert stage34_cached_tokens(response) == 1911
    assert stage34_cached_tokens({"timings": {"cache_n": 77}}) == 77


def test_stage34_cached_tokens_handles_null_response():
    assert stage34_cached_tokens(None) == 0
    assert stage34_cached_tokens({}) == 0


def test_stage34_join_verdict_keeps_http_and_null_response_distinct():
    assert stage34_join_verdict("hit", None) == "FAIL-http"
    assert stage34_join_verdict("hit", {"http_status": 500, "response": None}) == "FAIL-http"
    assert stage34_join_verdict("hit", {"http_status": 200, "response": None}) == "FAIL-null-response"
    assert stage34_join_verdict("hit", {"http_status": 200, "response": {"timings": {"cache_n": 0}}}) == "FAIL-cache-miss"
    assert stage34_join_verdict("hit", {"http_status": 200, "response": {"usage": {"prompt_tokens_details": {"cached_tokens": 8}}}}) == "PASS"


def test_stage34_budget_reason_marks_save_rejection():
    assert stage34_expected_budget_reason(1499, 100, 0.1) == "EXPECTED-HOT-BUDGET-SAVE-REJECTED"
    assert stage34_expected_budget_reason(1499, 4096, 0.1) == ""
