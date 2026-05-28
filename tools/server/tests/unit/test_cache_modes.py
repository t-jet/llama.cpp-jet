import os
import subprocess
import pytest
from utils import *


server = ServerPreset.tinyllama2()


LONG_PROMPT = (
    "Cache integration prompt alpha. The scout crossed the frozen valley "
    "with a lantern, a notebook, and a map of the old observatory. "
    "Every ridge was marked with a careful note about wind and snow."
)

OTHER_PROMPT = (
    "Cache integration prompt beta. The engineer calibrated the radio "
    "array before sunrise and wrote down each signal that crossed the sky."
)


@pytest.fixture(autouse=True)
def create_server():
    global server
    server = ServerPreset.tinyllama2()
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    local_model = os.environ.get(
        "LLAMA_CACHE_TEST_MODEL",
        os.path.join(repo_root, "._test_models", "Qwen2.5-VL-3B-Instruct-GGUF", "Qwen2.5-VL-3B-Instruct-Q6_K.gguf"),
    )
    server.model_hf_repo = None
    server.model_hf_file = None
    server.model_file = local_model
    server.n_slots = 2
    server.n_predict = 4
    server.temperature = 0.0
    server.kv_unified = True
    server.server_slots = True
    server.cache_ram = 100
    server.slot_save_path = "./tmp"
    yield


def assert_cache_stats_shape(stats, expected_type):
    assert stats["type"] == expected_type
    assert isinstance(stats["size_mib"], (int, float))
    assert isinstance(stats["n_tokens"], int)
    assert isinstance(stats["n_entries"], int)


def assert_cache_metrics_shape(body, expected_type):
    assert f'llamacpp_cache_entries{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_bytes{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_tokens{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_payload_evictions_total{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_protected_root_decisions_total{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_descriptor_validation_failures_total{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_pairing_violations_total{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_fallback_restores_total{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_hot_payload_descriptors{{mode="{expected_type}"}}' in body
    assert f'llamacpp_cache_evicted_payload_descriptors{{mode="{expected_type}"}}' in body


def server_binary_path():
    if "LLAMA_SERVER_BIN_PATH" in os.environ:
        return os.environ["LLAMA_SERVER_BIN_PATH"]
    if os.name == "nt":
        return os.path.abspath(os.path.join(
            os.path.dirname(__file__), "..", "..", "..", "..", "build", "bin", "Release", "llama-server.exe",
        ))
    return os.path.abspath(os.path.join(
        os.path.dirname(__file__), "..", "..", "..", "..", "build", "bin", "llama-server",
    ))


def test_invalid_cache_mode_is_rejected():
    result = subprocess.run(
        [
            server_binary_path(),
            "--cache-mode",
            "definitely-not-a-cache-mode",
            "--model",
            "missing-model.gguf",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=10,
    )

    assert result.returncode != 0
    assert "invalid cache mode" in result.stdout


def test_cache_metrics_default_legacy():
    global server
    server.server_metrics = True
    server.start()

    health = server.make_request("GET", "/health")
    assert health.status_code == 200
    assert health.body == {"status": "ok"}

    stats = server.make_request("GET", "/cache/stats")
    assert stats.status_code == 404

    metrics = server.make_request("GET", "/metrics")
    assert metrics.status_code == 200
    assert_cache_metrics_shape(metrics.body, "legacy")


@pytest.mark.xfail(
    reason="Explicit id_slot requests do not enter the hybrid restore lookup path.",
)
def test_hybrid_cache_metrics_and_repeated_restore():
    global server
    server.cache_mode = "hybrid"
    server.server_metrics = True
    server.start()

    metrics = server.make_request("GET", "/metrics")
    assert metrics.status_code == 200
    assert_cache_metrics_shape(metrics.body, "hybrid")
    assert 'llamacpp_cache_hits_total{mode="hybrid"} 0' in metrics.body
    assert 'llamacpp_cache_misses_total{mode="hybrid"} 0' in metrics.body
    assert 'llamacpp_cache_restore_failures_total{mode="hybrid"} 0' in metrics.body

    first = server.make_request("POST", "/completion", data={
        "prompt": LONG_PROMPT,
        "id_slot": 0,
        "cache_prompt": True,
    })
    assert first.status_code == 200
    continuation_prompt = LONG_PROMPT + first.body["content"]

    second = server.make_request("POST", "/completion", data={
        "prompt": OTHER_PROMPT,
        "id_slot": 1,
        "cache_prompt": True,
    })
    assert second.status_code == 200

    after_save = server.make_request("GET", "/metrics")
    assert after_save.status_code == 200
    assert 'llamacpp_cache_entries{mode="hybrid"} 0' not in after_save.body

    erase_before_restore = server.make_request("POST", "/slots/0?action=erase")
    assert erase_before_restore.status_code == 200

    restored_once = server.make_request("POST", "/completion", data={
        "prompt": continuation_prompt,
        "id_slot": 0,
        "cache_prompt": True,
    })
    assert restored_once.status_code == 200
    assert restored_once.body["timings"]["cache_n"] > 0

    after_first_restore = server.make_request("GET", "/metrics")
    assert after_first_restore.status_code == 200
    assert 'llamacpp_cache_hits_total{mode="hybrid"} 0' not in after_first_restore.body

    erase = server.make_request("POST", "/slots/0?action=erase")
    assert erase.status_code == 200

    restored_twice = server.make_request("POST", "/completion", data={
        "prompt": continuation_prompt,
        "id_slot": 0,
        "cache_prompt": True,
    })
    assert restored_twice.status_code == 200
    assert restored_twice.body["timings"]["cache_n"] > 0

    after_second_restore = server.make_request("GET", "/metrics")
    assert after_second_restore.status_code == 200
    assert 'llamacpp_cache_entries{mode="hybrid"} 0' not in after_second_restore.body


def test_hybrid_cache_restore_without_request_cache_prompt_reports_cache_n():
    global server
    server.cache_mode = "hybrid"
    server.server_metrics = True
    server.n_slots = 1
    server.start()

    first = server.make_request("POST", "/completion", data={
        "prompt": LONG_PROMPT,
    })
    assert first.status_code == 200

    restored = server.make_request("POST", "/completion", data={
        "prompt": LONG_PROMPT,
    })
    assert restored.status_code == 200
    assert restored.body["timings"]["cache_n"] > 0
    assert restored.body["timings"]["prompt_n"] < restored.body["tokens_evaluated"]

    metrics = server.make_request("GET", "/metrics")
    assert metrics.status_code == 200
    assert 'llamacpp_cache_hits_total{mode="hybrid"} 0' not in metrics.body
