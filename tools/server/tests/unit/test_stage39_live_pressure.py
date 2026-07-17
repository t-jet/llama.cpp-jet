import contextlib
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import threading
import time

import pytest
import requests


ROOT = Path(__file__).resolve().parents[4]
ON_BINARY = Path(os.environ.get(
    "LLAMA_SERVER_BIN_PATH",
    ROOT / "build-stage39-seam-on" / "bin" / "Release" / "llama-server.exe",
))
OFF_BINARY = Path(os.environ.get(
    "LLAMA_STAGE39_OFF_BIN_PATH",
    ROOT / "build-stage39-seam-off" / "bin" / "Release" / "llama-server.exe",
))
MODEL = Path(os.environ.get(
    "LLAMA_CACHE_TEST_MODEL",
    ROOT / "._test_models" / "Qwen3-0.6B-GGUF" / "Qwen3-0.6B-Q8_0.gguf",
))
TOKEN = "stage39-route-test-token-0123456789abcdef"
MTP_MODEL = ROOT / "._test_models" / "Qwen3.5-4B-MTP-GGUF" / "Qwen3.5-4B-Q4_K_M.gguf"
MTP_TEMPLATE = ROOT / "._test_models" / "Qwen3.5-4B-MTP-GGUF" / "chat_template_new.jinja"
MTP_MODEL_BYTES = 2834975040
MTP_WALL_SECONDS = 20 * 60
MTP_RSS_BYTES = 16 * 1024**3
MTP_COLD_BYTES = 4 * 1024**3
MTP_LOG_BYTES = 64 * 1024**2
MTP_REQUESTS = {
    "source": {
        "suffix": "suffix-source|", "max_tokens": 32, "bytes": 5687,
        "sha256": "d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49",
        "lengths": [250, 707, 355, 835, 355, 643, 419, 643, 355, 721],
    },
    "incoming": {
        "suffix": "suffix-incoming|", "max_tokens": 1, "bytes": 5688,
        "sha256": "a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b",
        "lengths": [250, 707, 355, 835, 355, 643, 419, 643, 355, 723],
    },
}


def _mtp_request_bytes(role):
    contract = MTP_REQUESTS[role]
    messages = [
        {"role": "system", "content": "S|" + "shared-system-0123456789abcdef|" * 8},
        {"role": "user", "content": "U1|" + "alpha-0001|" * 64},
        {"role": "assistant", "content": "A1|" + "bravo-0002|" * 32},
        {"role": "user", "content": "U2|" + "charlie-0003|" * 64},
        {"role": "assistant", "content": "A2|" + "delta-0004|" * 32},
        {"role": "user", "content": "U3|" + "echo-0005|" * 64},
        {"role": "assistant", "content": "A3|" + "foxtrot-0006|" * 32},
        {"role": "user", "content": "U4|" + "golf-0007|" * 64},
        {"role": "assistant", "content": "A4|" + "hotel-0008|" * 32},
        {"role": "user", "content": "U5|" + "india-0009|" * 64 + contract["suffix"]},
    ]
    if [len(row["content"]) for row in messages] != contract["lengths"]:
        raise ValueError("literal message length mismatch")
    body = {
        "model": "Qwen3.5-4B", "messages": messages,
        "max_tokens": contract["max_tokens"], "temperature": 0,
        "seed": 42, "stream": False,
    }
    encoded = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if (len(encoded) != contract["bytes"] or
            hashlib.sha256(encoded).hexdigest() != contract["sha256"]):
        raise ValueError(f"{role} request bytes drift")
    return encoded


def _zero_preapply_events(metrics):
    return (sum(row["value"] for row in metrics["cache_two_layer_decisions"]) == 0 and
            sum(row["value"] for row in metrics["cache_cold_transactions"]) == 0)


def _validate_mtp_lifecycle(source, source_metrics, incoming, incoming_metrics, cold_files):
    if (source_metrics["branch_forest"]["total_nodes"] != 1 or
            source.get("hot_candidates") or source.get("cold_sets") or
            not _zero_preapply_events(source_metrics)):
        raise ValueError("source is not the sole pinned node")
    hot = incoming.get("hot_candidates", [])
    cold_sets = incoming.get("cold_sets", [])
    if (incoming_metrics["branch_forest"]["total_nodes"] != 2 or len(hot) != 1 or
            len(cold_sets) != 1 or cold_sets[0].get("candidates") or cold_files or
            not _zero_preapply_events(incoming_metrics)):
        raise ValueError("post-incoming inventory mismatch")
    source_row = hot[0]
    if (source_row.get("payload_kind") != "exact_blob" or
            not source_row.get("payload_id") or not source_row.get("owner_entry_id") or
            source_row.get("resident_bytes", 0) <= 0):
        raise ValueError("released source exact row mismatch")
    if (cold_sets[0].get("incoming_payload_id") != source_row["payload_id"] or
            cold_sets[0].get("incoming_owner_entry_id") != source_row["owner_entry_id"]):
        raise ValueError("source cold-set key drift")
    return source_row


def _free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class Stage39Server:
    def __init__(self, tmp_path, *, opt_in=True, binary=ON_BINARY, extra_env=None):
        self.port = _free_port()
        self.base = f"http://127.0.0.1:{self.port}"
        self.cold = tmp_path / "cold"
        self.cold.mkdir(parents=True)
        env = os.environ.copy()
        if opt_in:
            env["LLAMA_STAGE39_LIVE_TEST_SEAM"] = "1"
            env["LLAMA_STAGE39_LIVE_TEST_TOKEN"] = TOKEN
        else:
            env.pop("LLAMA_STAGE39_LIVE_TEST_SEAM", None)
            env.pop("LLAMA_STAGE39_LIVE_TEST_TOKEN", None)
        if extra_env:
            env.update(extra_env)
        command = [
            str(binary), "-m", str(MODEL), "--host", "127.0.0.1", "--port", str(self.port),
            "--cache-mode", "hybrid", "--cache-ram", "32", "--metrics", "--parallel", "1",
            "--ctx-size", "2048", "--n-gpu-layers", "0", "--cache-cold-path", str(self.cold),
            "--cache-cold-max-mib", "256", "--no-ui",
        ]
        self.log = open(tmp_path / "server.log", "w", encoding="utf-8")
        self.process = subprocess.Popen(command, env=env, stdout=self.log, stderr=subprocess.STDOUT)
        deadline = time.time() + 60
        while time.time() < deadline:
            if self.process.poll() is not None:
                self.close()
                raise RuntimeError("Stage 39 route server exited during startup")
            try:
                if requests.get(self.base + "/health", timeout=1).status_code == 200:
                    return
            except requests.RequestException:
                pass
            time.sleep(0.1)
        self.close()
        raise RuntimeError("Stage 39 route server health timeout")

    def close(self):
        if getattr(self, "process", None) is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
        if getattr(self, "log", None) is not None and not self.log.closed:
            self.log.close()

    def control(self, body, token=TOKEN):
        return requests.post(
            self.base + "/debug/cache/stage39-live-pressure",
            headers={"x-llama-stage39-test-token": token}, json=body, timeout=30,
        )

    def admit(self, suffix="alpha", n_predict=1, ignore_eos=False):
        response = requests.post(self.base + "/completion", json={
            "prompt": "stage39 pressure row " + suffix + " " + ("x " * 80),
            "n_predict": n_predict,
            "ignore_eos": ignore_eos,
            "cache_prompt": True,
        }, timeout=60)
        assert response.status_code == 200

    def admit_inventory(self, prefix="inventory"):
        for index in range(6):
            self.admit(f"{prefix}-{index}")
        deadline = time.time() + 10
        while time.time() < deadline:
            response = self.control({"operation": "discover"})
            if response.status_code == 200:
                snapshot = response.json()
                if snapshot["hot_candidates"]:
                    return snapshot
            else:
                assert response.status_code == 503
                assert ("Stage 39 control requires idle slots" in response.text or
                        "inventory_integrity_error" in response.text)
            time.sleep(0.05)
        raise AssertionError("Stage 39 discovery returned no eligible hot candidate")

    def discover(self):
        response = self.control({"operation": "discover"})
        assert response.status_code == 200
        return response.json()


class Stage39MTPServer:
    def __init__(self, node_name):
        stamp = f"{time.time_ns()}-{os.getpid()}"
        root = Path(os.environ.get(
            "LLAMA_STAGE39_ROUTE_ARTIFACT_ROOT",
            ROOT / "._test_output" / "stage39-route-fixture",
        ))
        self.artifacts = root / f"{node_name}-{stamp}"
        self.artifacts.mkdir(parents=True)
        self.cold = self.artifacts / "cold"
        self.cold.mkdir()
        self.started = time.monotonic()
        self.resources = []
        self.process = None
        self.log = None
        self.token = secrets.token_hex(32)
        self.port = _free_port()
        self.base = f"http://127.0.0.1:{self.port}"
        self._check_fixture()
        env = os.environ.copy()
        env["LLAMA_STAGE39_LIVE_TEST_SEAM"] = "1"
        env["LLAMA_STAGE39_LIVE_TEST_TOKEN"] = self.token
        self.command = [
            str(ON_BINARY), "--model", str(MTP_MODEL), "--jinja",
            "--chat-template-file", str(MTP_TEMPLATE),
            "--spec-type", "draft-mtp", "--log-verbosity", "4",
            "--ctx-size", "8192", "--batch-size", "512", "--ubatch-size", "512",
            "--parallel", "1", "--cache-mode", "hybrid", "--cache-ram", "2048",
            "--cache-cold-max-mib", "2048", "--ctx-checkpoints", "32",
            "--checkpoint-min-step", "0", "--metrics", "--temp", "0", "--seed", "42",
            "--host", "127.0.0.1", "--no-ui", "--port", str(self.port),
            "--cache-cold-path", str(self.cold),
        ]
        self._write_json("command.json", {
            "argv": self.command,
            "environment_names": [
                "LLAMA_STAGE39_LIVE_TEST_SEAM", "LLAMA_STAGE39_LIVE_TEST_TOKEN",
            ],
        })
        selectors = [index for index, value in enumerate(self.command) if value == "--spec-type"]
        if len(selectors) != 1 or self.command[selectors[0]:selectors[0] + 4] != [
                "--spec-type", "draft-mtp", "--log-verbosity", "4"]:
            self._block("BLOCKED-route-fixture-capability", "draft-mtp argv selector mismatch")
        log_options = [
            (index, value) for index, value in enumerate(self.command)
            if value in {"-v", "--verbose", "-lv", "--verbosity", "--log-verbosity"}
            or value.startswith("-lv=")
            or value.startswith("--verbosity=")
            or value.startswith("--log-verbosity=")
        ]
        if log_options != [(selectors[0] + 2, "--log-verbosity")]:
            self._block("BLOCKED-route-fixture-capability", "log verbosity argv mismatch")
        if env.get("LLAMA_ARG_LOG_VERBOSITY") is not None:
            self._block("BLOCKED-route-fixture-capability", "log verbosity environment override")
        self.log = open(self.artifacts / "server.log", "w", encoding="utf-8")
        self.process = subprocess.Popen(
            self.command, env=env, stdout=self.log, stderr=subprocess.STDOUT,
        )
        self._wait_for_health()

    def _write_json(self, name, value):
        path = self.artifacts / name
        path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def _redacted(self, value):
        value = copy.deepcopy(value)
        if isinstance(value, dict):
            for key in list(value):
                if key in {"snapshot_token", "proof_token", "terminal_hmac"}:
                    value[key] = "<redacted>"
                else:
                    value[key] = self._redacted(value[key])
        elif isinstance(value, list):
            value = [self._redacted(item) for item in value]
        return value

    def _redacted_snapshot_token(self, value):
        value = copy.deepcopy(value)
        if isinstance(value, dict):
            for key in list(value):
                if key == "snapshot_token":
                    value[key] = "<redacted>"
                else:
                    value[key] = self._redacted_snapshot_token(value[key])
        elif isinstance(value, list):
            value = [self._redacted_snapshot_token(item) for item in value]
        return value

    def _block(self, reason, detail):
        self._write_json("preflight-result.json", {
            "result": reason,
            "detail": detail,
            "elapsed_seconds": round(time.monotonic() - self.started, 3),
        })
        raise AssertionError(f"{reason}: {detail}; artifacts={self.artifacts}")

    def _check_fixture(self):
        if not ON_BINARY.is_file() or not MTP_MODEL.is_file() or not MTP_TEMPLATE.is_file():
            self._block("BLOCKED-route-fixture-missing", "binary, model, or template is absent")
        if MTP_MODEL.stat().st_size != MTP_MODEL_BYTES:
            self._block("BLOCKED-route-fixture-metadata", "model byte size mismatch")
        sys.path.insert(0, str(ROOT / "gguf-py"))
        try:
            from gguf import GGUFReader
            reader = GGUFReader(MTP_MODEL, "r")
            metadata = {
                "general.architecture": reader.get_field("general.architecture").contents(),
                "qwen35.context_length": reader.get_field("qwen35.context_length").contents(),
                "qwen35.nextn_predict_layers": reader.get_field("qwen35.nextn_predict_layers").contents(),
            }
        except Exception as exc:
            self._block("BLOCKED-route-fixture-metadata", type(exc).__name__)
        finally:
            sys.path.pop(0)
        self._write_json("model-metadata.json", metadata)
        if metadata != {
                "general.architecture": "qwen35",
                "qwen35.context_length": 262144,
                "qwen35.nextn_predict_layers": 1}:
            self._block("BLOCKED-route-fixture-metadata", "required GGUF metadata mismatch")

    def _rss_bytes(self):
        if self.process is None or self.process.poll() is not None:
            return 0
        if os.name == "nt":
            import ctypes
            from ctypes import wintypes

            class Counters(ctypes.Structure):
                _fields_ = [
                    ("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                    ("PeakWorkingSetSize", ctypes.c_size_t),
                    ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t),
                    ("PeakPagefileUsage", ctypes.c_size_t),
                ]
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            handle = wintypes.HANDLE(int(self.process._handle))
            if ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
                return int(counters.WorkingSetSize)
        return 0

    def _guard(self, operation):
        elapsed = time.monotonic() - self.started
        rss = self._rss_bytes()
        cold_bytes = sum(path.stat().st_size for path in self.cold.rglob("*") if path.is_file())
        log_path = self.artifacts / "server.log"
        log_bytes = log_path.stat().st_size if log_path.is_file() else 0
        self.resources.append({
            "operation": operation, "elapsed_seconds": round(elapsed, 3),
            "rss_bytes": rss, "cold_root_bytes": cold_bytes, "server_log_bytes": log_bytes,
        })
        self._write_json("resource-capture.json", self.resources)
        if log_bytes > MTP_LOG_BYTES:
            self.close()
            self._block("BLOCKED-route-fixture-cap", "server.log")
        if elapsed > MTP_WALL_SECONDS or rss > MTP_RSS_BYTES or cold_bytes > MTP_COLD_BYTES:
            self._block("BLOCKED-route-fixture-cap", operation)
        if self.process is not None and self.process.poll() is not None:
            self._block("BLOCKED-route-fixture-startup", f"server exited during {operation}")

    def _wait_for_health(self):
        while time.monotonic() - self.started <= MTP_WALL_SECONDS:
            self._guard("health")
            try:
                if requests.get(self.base + "/health", timeout=2).status_code == 200:
                    return
            except requests.RequestException:
                pass
            time.sleep(0.25)
        self._block("BLOCKED-route-fixture-cap", "health timeout")

    def _request_bytes(self, role):
        try:
            return _mtp_request_bytes(role)
        except ValueError as exc:
            self._block("BLOCKED-route-fixture-request", str(exc))

    def control(self, body):
        self._guard(body["operation"])
        return requests.post(
            self.base + "/debug/cache/stage39-live-pressure",
            headers={"x-llama-stage39-test-token": self.token}, json=body, timeout=120,
        )

    def _metrics(self):
        self._guard("metrics")
        response = requests.get(self.base + "/metrics", timeout=30)
        if response.status_code != 200:
            self._block("BLOCKED-route-fixture-drift", "metrics request failed")
        try:
            return _parse_stage39_metrics(response.text)
        except ValueError as exc:
            self._block("BLOCKED-route-fixture-drift", str(exc))

    def _wait_for_idle_discovery(self):
        while time.monotonic() - self.started <= MTP_WALL_SECONDS:
            reply = self.control({"operation": "discover"})
            if reply.status_code == 200:
                return reply.json()
            if reply.status_code != 503 or ("idle slots" not in reply.text and
                    "inventory_integrity_error" not in reply.text):
                self._block("BLOCKED-route-fixture-idle", f"HTTP {reply.status_code}")
            time.sleep(0.1)
        self._block("BLOCKED-route-fixture-cap", "idle timeout")

    def _admit_chat(self, role):
        request_bytes = self._request_bytes(role)
        (self.artifacts / f"{role}-request.json").write_bytes(request_bytes)
        self._write_json(f"{role}-request-sha256.json", {
            "bytes": len(request_bytes), "sha256": hashlib.sha256(request_bytes).hexdigest(),
        })
        self._guard(f"chat-admission-{role}")
        try:
            response = requests.post(
                self.base + "/v1/chat/completions", data=request_bytes,
                headers={"content-type": "application/json"}, timeout=MTP_WALL_SECONDS,
            )
        except requests.RequestException as exc:
            self._block("BLOCKED-route-fixture-admission", type(exc).__name__)
        (self.artifacts / f"{role}-response.json").write_text(
            response.text + "\n", encoding="utf-8")
        if response.status_code != 200:
            self._block("BLOCKED-route-fixture-admission", f"{role} HTTP {response.status_code}")
        return response.status_code, self._wait_for_idle_discovery(), self._metrics()

    def _admit_two_requests(self):
        source_code, source, source_metrics = self._admit_chat("source")
        try:
            self._write_json(
                "discovery-after-source.json", self._redacted_snapshot_token(source))
            self._write_json("metrics-after-source.json", source_metrics)
        except (OSError, TypeError, ValueError):
            self._block("BLOCKED-route-fixture-capture", "post-source capture failed")
        incoming_code, incoming, incoming_metrics = self._admit_chat("incoming")
        return source_code, source, source_metrics, incoming_code, incoming, incoming_metrics

    def admit_pair(self):
        (source_code, source, source_metrics, incoming_code, first,
         metrics_before) = self._admit_two_requests()
        self.log.flush()
        startup = (self.artifacts / "server.log").read_text(encoding="utf-8", errors="replace")
        required_log = [
            MTP_MODEL.name, "creating MTP draft context", "bounded partial sequence removal",
            "draft-mtp", "context checkpoints enabled, max = 32, min spacing = 0",
            "created context checkpoint",
        ]
        if any(text not in startup for text in required_log):
            missing = [text for text in required_log if text not in startup]
            self._block("BLOCKED-route-fixture-capability", ", ".join(missing))
        draft_components = [
            float(value) for value in re.findall(r"dft:\s+([0-9]+(?:\.[0-9]+)?)", startup)
        ]
        if not draft_components or max(draft_components) <= 0:
            self._block("BLOCKED-route-fixture-capability", "source save has no positive draft component")

        try:
            self._write_json(
                "discovery-before-validation.json",
                self._redacted_snapshot_token(first),
            )
            self._write_json("metrics-before-validation.json", metrics_before)
        except (OSError, TypeError, ValueError):
            self._block("BLOCKED-route-fixture-capture", "pre-validation capture failed")
        if os.environ.get("LLAMA_STAGE39_CAPTURE_ONLY") == "1":
            self._block(
                "BLOCKED-route-fixture-diagnostic",
                "pre-validation capture complete",
            )
        files = [str(path.relative_to(self.cold)) for path in self.cold.rglob("*") if path.is_file()]
        try:
            hot_source = _validate_mtp_lifecycle(
                source, source_metrics, first, metrics_before, files)
        except (KeyError, TypeError, ValueError) as exc:
            self._block("BLOCKED-route-fixture-inventory", str(exc))
        hot = first["hot_candidates"]

        proof_request = {
            "operation": "proof", "snapshot_generation": first["snapshot_generation"],
            "snapshot_token": first["snapshot_token"], "payload_ids": [hot[0]["payload_id"]],
        }
        proof_response = self.control(proof_request)
        if proof_response.status_code != 200:
            self._block("BLOCKED-route-fixture-proof", f"HTTP {proof_response.status_code}")
        proof = proof_response.json()
        second_response = self.control({"operation": "discover"})
        if second_response.status_code != 200:
            self._block("BLOCKED-route-fixture-drift", "repeat discovery failed")
        second = second_response.json()
        repeated_proof = self.control(proof_request)
        if repeated_proof.status_code != 200:
            self._block("BLOCKED-route-fixture-drift", "repeat proof failed")
        metrics_after = self._metrics()
        rows = proof.get("rows", [])
        kinds = [row.get("payload_kind") for row in rows]
        if kinds != ["exact_blob", "checkpoint"]:
            self._block("BLOCKED-route-fixture-pair", f"proof kinds {kinds}")
        if (len({row["payload_id"] for row in rows}) != 2 or
                any(row["payload_id"] == 0 or row["owner_entry_id"] != hot[0]["owner_entry_id"] or
                    row["residency"] != "hot" or not row["runtime_pair_matches"] or
                    row["target_size_bytes"] <= 0 or
                    row["draft_size_bytes"] <= 0 or
                    row["resident_component_bytes"] != row["resident_bytes"]
                    for row in rows)):
            self._block("BLOCKED-route-fixture-pair", "owner, residency, runtime, or size mismatch")
        if first != second or proof != repeated_proof.json() or metrics_before != metrics_after:
            self._block("BLOCKED-route-fixture-drift", "discovery, proof, or metrics changed")
        self._write_json("discovery.json", self._redacted(first))
        self._write_json("proof.json", self._redacted(proof))
        self._write_json("metrics-before-apply.json", metrics_after)
        self._write_json("cold-inventory-before-apply.json", files)
        self._write_json("preflight-result.json", {
            "result": "PASS", "request_count": 2,
            "snapshot_generation": first["snapshot_generation"],
            "payload_ids": [row["payload_id"] for row in rows],
            "owner_entry_id": hot[0]["owner_entry_id"],
        })
        self._write_json("slot-release-preflight.json", {
            "request_count": 2,
            "response_codes": [source_code, incoming_code],
            "node_counts": [
                source_metrics["branch_forest"]["total_nodes"],
                metrics_before["branch_forest"]["total_nodes"],
            ],
            "source_candidate_id": hot_source["payload_id"],
            "source_owner_entry_id": hot_source["owner_entry_id"],
            "preapply_decision_events": sum(
                row["value"] for row in metrics_before["cache_two_layer_decisions"]),
            "preapply_transaction_events": sum(
                row["value"] for row in metrics_before["cache_cold_transactions"]),
        })
        return first, proof

    def preserve_apply(self, request, response):
        self._write_json("apply-request.json", self._redacted(request))
        try:
            body = response.json()
        except ValueError:
            body = {"text": response.text}
        self._write_json("apply-response.json", self._redacted(body))

    def preserve_terminal(self, retrieval, metrics):
        self._write_json("prepared-proof-retrieval.json", self._redacted(retrieval))
        self._write_json("metrics-final.json", metrics)
        self._write_json("cold-inventory-final.json", [
            {"path": str(path.relative_to(self.cold)), "bytes": path.stat().st_size}
            for path in self.cold.rglob("*") if path.is_file()
        ])
        self._guard("final")

    def close(self):
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
        if self.log is not None and not self.log.closed:
            self.log.close()


@contextlib.contextmanager
def _server(tmp_path, **kwargs):
    server = Stage39Server(tmp_path, **kwargs)
    try:
        yield server
    finally:
        server.close()


@contextlib.contextmanager
def _mtp_server(node_name):
    server = Stage39MTPServer(node_name)
    try:
        yield server
    finally:
        server.close()


def _apply(snapshot, scenario="tp39-04"):
    incoming = snapshot["hot_candidates"][0]
    selected = next(item for item in snapshot["cold_sets"]
                    if item["incoming_payload_id"] == incoming["payload_id"])
    size = incoming["resident_bytes"]
    request = {
        "operation": "apply",
        "scenario": scenario,
        "hot_budget_bytes": max(1, size - 1),
        "cold_budget_bytes": max(1, size - 1),
        "snapshot_generation": snapshot["snapshot_generation"],
        "snapshot_token": snapshot["snapshot_token"],
        "incoming_payload_id": incoming["payload_id"],
        "incoming_owner_entry_id": incoming["owner_entry_id"],
        "hot_candidates": copy.deepcopy(snapshot["hot_candidates"]),
        "cold_sets": copy.deepcopy(snapshot["cold_sets"]),
        "desired_hot_orders": [
            {"owner_entry_id": row["owner_entry_id"], "desired_hot_order": 1000 + index}
            for index, row in enumerate(snapshot["hot_candidates"])
        ],
        "desired_cold_ranks": [
            {"payload_id": row["payload_id"], "desired_cold_rank": 77}
            for row in selected["candidates"]
        ],
    }
    if scenario == "tp39-03":
        request["tp39_03_cold_owner_setup"] = "selected_incoming_owner"
        request["desired_cold_ranks"] = []
    return request


@pytest.fixture(scope="module")
def live_server(tmp_path_factory):
    with _server(tmp_path_factory.mktemp("stage39-route")) as server:
        server.admit_inventory("shared")
        yield server


def test_live_pressure_route_absent_when_compiled_off():
    assert OFF_BINARY.is_file()
    assert b"/debug/cache/stage39-live-pressure" not in OFF_BINARY.read_bytes()


def test_live_pressure_rejects_runtime_off_and_startup_guards(tmp_path):
    with _server(tmp_path / "off", opt_in=False) as server:
        assert server.control({"operation": "discover"}).status_code == 404
    env = os.environ.copy()
    env["LLAMA_STAGE39_LIVE_TEST_SEAM"] = "1"
    env["LLAMA_STAGE39_LIVE_TEST_TOKEN"] = TOKEN
    result = subprocess.run([
        str(ON_BINARY), "-m", str(MODEL), "--host", "0.0.0.0", "--cache-mode", "hybrid",
        "--cache-ram", "1", "--cache-cold-path", str(tmp_path / "guard-cold"),
        "--cache-cold-max-mib", "1", "--metrics", "--parallel", "1",
    ], env=env, capture_output=True, text=True, timeout=20)
    assert result.returncode != 0


def test_live_pressure_rejects_non_loopback_and_wrong_admin_token(live_server):
    response = live_server.control({"operation": "discover"}, token="wrong")
    assert response.status_code != 200
    assert TOKEN not in response.text
    env = os.environ.copy()
    env["LLAMA_STAGE39_LIVE_TEST_SEAM"] = "1"
    env["LLAMA_STAGE39_LIVE_TEST_TOKEN"] = TOKEN
    result = subprocess.run([
        str(ON_BINARY), "-m", str(MODEL), "--host", "0.0.0.0", "--cache-mode", "hybrid",
        "--cache-ram", "1", "--cache-cold-path", str(live_server.cold / "non-loopback"),
        "--cache-cold-max-mib", "1", "--metrics", "--parallel", "1",
    ], env=env, capture_output=True, text=True, timeout=20)
    assert result.returncode != 0
    assert TOKEN not in result.stdout + result.stderr


def test_live_pressure_rejects_strict_schema_errors(live_server):
    for body in ({}, {"operation": "discover", "extra": 1}, {"operation": "unknown"}):
        assert live_server.control(body).status_code != 200


def test_live_pressure_tp39_03_tag_isolation(live_server):
    snapshot = live_server.discover()
    missing = _apply(snapshot, "tp39-03")
    del missing["tp39_03_cold_owner_setup"]
    assert live_server.control(missing).status_code != 200

    invalid = _apply(snapshot, "tp39-03")
    invalid["tp39_03_cold_owner_setup"] = "other"
    assert live_server.control(invalid).status_code != 200

    leaked = _apply(snapshot, "tp39-04")
    leaked["tp39_03_cold_owner_setup"] = "selected_incoming_owner"
    assert live_server.control(leaked).status_code != 200
    assert live_server.discover() == snapshot


def test_live_pressure_discover_non_consuming(live_server):
    first = live_server.discover()
    second = live_server.discover()
    assert first == second


def test_live_pressure_discover_integrity_error_retryable(live_server):
    before = live_server.discover()
    cold_rows = [row for item in before["cold_sets"] for row in item["candidates"]]
    assert cold_rows
    victim = cold_rows[0]
    path = live_server.cold / f"{victim['payload_id']:x}.cold"
    saved = path.read_bytes()
    path.unlink()
    try:
        rejected = live_server.control({"operation": "discover"})
        assert rejected.status_code != 200
        assert "inventory_integrity_error" in rejected.text
    finally:
        path.write_bytes(saved)
    after = live_server.discover()
    assert after == before


def test_live_pressure_apply_rejects_stale_generation(live_server):
    snapshot = live_server.discover()
    request = _apply(snapshot)
    request["snapshot_generation"] -= 1
    response = live_server.control(request)
    assert response.status_code != 200
    assert "stale_snapshot" in response.text
    assert TOKEN not in response.text


def test_live_pressure_apply_rejects_wrong_snapshot_token(live_server):
    snapshot = live_server.discover()
    request = _apply(snapshot)
    request["snapshot_token"] = "0" * 64
    assert live_server.control(request).status_code != 200


def test_live_pressure_apply_rejects_omitted_or_extra_checkpoint(live_server):
    snapshot = live_server.discover()
    request = _apply(snapshot)
    selected = next(item for item in request["cold_sets"]
                    if item["incoming_payload_id"] == request["incoming_payload_id"])
    checkpoints = [row for row in selected["candidates"] if row["payload_kind"] == "checkpoint"]
    if checkpoints:
        omitted = checkpoints[0]
        selected["candidates"].remove(omitted)
        request["desired_cold_ranks"] = [row for row in request["desired_cold_ranks"]
                                          if row["payload_id"] != omitted["payload_id"]]
    else:
        extra = dict(selected["candidates"][0])
        extra["payload_id"] = max(row["payload_id"] for row in selected["candidates"]) + 1000
        extra["payload_kind"] = "checkpoint"
        selected["candidates"].append(extra)
        request["desired_cold_ranks"].append({
            "payload_id": extra["payload_id"], "desired_cold_rank": 77,
        })
    assert live_server.control(request).status_code != 200
    assert live_server.discover() == snapshot


def test_live_pressure_snapshot_token_process_binding_and_redaction(live_server, tmp_path):
    snapshot = live_server.discover()
    with _server(tmp_path / "other") as other:
        request = _apply(other.admit_inventory("process-binding"))
        request["snapshot_token"] = snapshot["snapshot_token"]
        response = other.control(request)
        assert response.status_code != 200
        assert snapshot["snapshot_token"] not in response.text


def test_live_pressure_idle_dispatch_race(live_server):
    completion = threading.Thread(target=live_server.admit, args=("idle-race", 256, True))
    completion.start()
    deadline = time.time() + 10
    saw_non_idle = False
    while completion.is_alive() and time.time() < deadline:
        response = live_server.control({"operation": "discover"})
        if response.status_code != 200 and "requires idle slots" in response.text:
            saw_non_idle = True
            break
        time.sleep(0.01)
    completion.join(timeout=60)
    assert not completion.is_alive()
    assert saw_non_idle
    assert live_server.discover()["snapshot_generation"] > 0


def test_live_pressure_terminal_after_mutation_failure(tmp_path):
    with _server(tmp_path / "terminal", extra_env={
            "LLAMA_STAGE39_LIVE_TEST_FAIL_AFTER_TX_UPDATE": "1"}) as server:
        request = _apply(server.admit_inventory("terminal"))
        first = server.control(request)
        assert first.status_code != 200
        assert "terminal_pressure_failure" in first.text
        state = first.json()["error"]["stage39_state"]
        assert state["after_generation"] > state["before_generation"]
        assert not state["pressure_completed"]
        second = server.control(request)
        assert second.status_code != 200
        assert "consumed" in second.text


def test_live_pressure_success_returns_before_after_state(tmp_path):
    with _server(tmp_path / "success") as server:
        response = server.control(_apply(server.admit_inventory("success")))
        assert response.status_code == 200
        body = response.json()
        assert body["after_generation"] > body["before_generation"]
        assert set(body["before"]) == {"hot_candidates", "cold_sets"}
        assert set(body["after"]) == {"hot_candidates", "cold_sets"}
        assert "snapshot_token" not in response.text


def _mtp_prepared_apply(snapshot, proof, fault):
    hot = snapshot["hot_candidates"][0]
    owner_entry_id = hot["owner_entry_id"]
    rows = proof["rows"]
    assert [row["payload_kind"] for row in rows] == ["exact_blob", "checkpoint"]
    request = {
        "operation": "apply",
        "scenario": "tp39-03",
        "tp39_03_setup": "same_owner_kind_sequence",
        "run_id": "tp39-03-prepared-" + fault,
        "fault": fault,
        "process_identity": proof["process_identity"],
        "proof_token": proof["proof_token"],
        "snapshot_generation": snapshot["snapshot_generation"],
        "snapshot_token": snapshot["snapshot_token"],
        "incoming_payload_id": rows[0]["payload_id"],
        "incoming_owner_entry_id": owner_entry_id,
        "hot_budget_bytes": hot["resident_bytes"],
        "cold_budget_bytes": 64 + max(row["resident_component_bytes"] for row in rows),
        "hot_candidates": copy.deepcopy(snapshot["hot_candidates"]),
        "cold_sets": copy.deepcopy(snapshot["cold_sets"]),
        "desired_hot_orders": [{"owner_entry_id": owner_entry_id, "desired_hot_order": 1000}],
        "desired_cold_ranks": [],
        "prepared_bindings": [
            {
                "workload_role": "canonical_same_owner",
                "request_number": 1,
                "pressure_step": index + 1,
                "payload_id": row["payload_id"],
                "owner_entry_id": owner_entry_id,
                "payload_kind": "exact_blob" if index == 0 else "checkpoint",
                "pair_state": row["pair_state"],
                "runtime_has_draft": row["runtime_has_draft"],
                "target_size_bytes": row["target_size_bytes"],
                "draft_size_bytes": row["draft_size_bytes"],
                "target_checksum": row["target_checksum"],
                "draft_checksum": row["draft_checksum"],
            }
            for index, row in enumerate(rows)
        ],
    }
    return request


def _assert_terminal_state_shape(proof, *, expected_fault, checkpoint_attempted):
    records = proof["records"]
    assert len(records) == (2 if checkpoint_attempted else 1)
    assert records[0]["payload_kind"] == "exact_blob"
    exact_id = records[0]["payload_id"]
    checkpoint_id = proof["terminal_state"]["checkpoint_descriptor"]["payload_id"]
    if checkpoint_attempted:
        assert records[1]["payload_kind"] == "checkpoint"
        assert records[1]["payload_id"] == checkpoint_id
    state = proof["terminal_state"]
    entry = state["entry"]
    branch = state["branch"]
    assert entry["entry_id"] == records[0]["owner_entry_id"]
    assert entry["exact_link"] == exact_id
    assert entry["checkpoint_link"] == checkpoint_id
    assert entry["resident_bytes"] == state["checkpoint_descriptor"]["resident_component_bytes"]
    assert entry["has_target"] is True and entry["has_draft"] is True
    assert branch["branch_id"] > 0
    assert branch["exact_link"] == entry["exact_link"]
    assert branch["checkpoint_link"] == entry["checkpoint_link"]
    assert branch["resident_bytes"] == entry["resident_bytes"]
    assert branch["has_target"] is True and branch["has_draft"] is True
    assert branch["sync_count"] == 1
    exact = state["exact_descriptor"]
    assert exact["payload_id"] == exact_id and exact["residency"] == "cold"
    assert exact["cold_file_bytes"] == records[0]["serialized_bytes"]
    assert exact["descriptor_bytes"] == records[0]["target_size_bytes"] + records[0]["draft_size_bytes"]
    assert exact["byte_map_bytes"] == exact["cold_file_bytes"]
    checkpoint = state["checkpoint_descriptor"]
    assert checkpoint["residency"] == "hot"
    assert checkpoint["resident_component_bytes"] > 0
    assert state["cold_inventory"] == [{
        "name": format(exact_id, "x") + ".cold", "bytes": exact["cold_file_bytes"]}]
    assert state["staging_inventory"] == []
    topology = state["topology"]
    assert topology["entry_count"] > 0 and topology["node_count"] > 0
    assert topology["lru_memberships"] == 1
    for key in ("entry_count_delta", "node_count_delta", "lru_membership_delta",
                "branch_prune_delta", "later_victim_count"):
        assert topology[key] == 0
    assert state["decision_deltas"] == [{
        "mode": "hybrid", "result": "retained_cold", "reason": "cold_room", "value": 1}]
    assert state["transaction_deltas"] == [{
        "mode": "hybrid", "result": "commit", "reason": "none", "value": 1}]
    assert state["diagnostic_deltas"] == {}
    observations = state["forbidden_observations"]
    for key in ("checkpoint_cold_file", "checkpoint_descriptor", "checkpoint_link"):
        assert observations[key]["before"] == observations[key]["after"]
        assert observations[key]["event_delta"] == 0
    forbidden = state["forbidden_effects"]
    for key in (
            "checkpoint_classification_delta", "checkpoint_admission_delta",
            "checkpoint_publish_delta", "checkpoint_commit_delta", "checkpoint_cold_file_delta",
            "checkpoint_descriptor_mutation_delta", "checkpoint_link_mutation_delta",
            "checkpoint_decision_delta", "checkpoint_diagnostic_delta", "later_work_delta",
            "later_victim_delta", "explicit_generation_advance_delta", "duplicate_sync_delta",
            "success_snapshot_count"):
        assert forbidden[key] == 0
    assert forbidden["failed_apply_count"] == 1
    assert proof["checkpoint_attempted"] is checkpoint_attempted
    assert proof["checkpoint_prepared"] is checkpoint_attempted
    return state


def _assert_coherent_terminal_fault(server, response, *, expected_fault,
                                     checkpoint_attempted):
    assert response.status_code != 200
    assert "prepared_" + ("midpoint" if expected_fault == "midpoint" else "boundary") + "_abort" in response.text
    body = response.json()["error"]["stage39_state"]
    proof = body["prepared_proof"]
    assert proof["status"] == "failed"
    assert proof["fault"] == expected_fault
    _assert_terminal_state_shape(
        proof, expected_fault=expected_fault, checkpoint_attempted=checkpoint_attempted)
    assert proof["common_sync_observed"] is True
    assert proof["common_sync_generation"] > proof["exact_return_generation"]
    assert proof["final_generation"] >= proof["common_sync_generation"]
    assert "snapshot_token" not in response.text
    metrics = _metrics_after_pressure(server)
    commits = sum(row["value"] for row in metrics["cache_cold_transactions"]
                  if row["result"] == "commit" and row["reason"] == "none")
    assert commits == 1
    assert metrics["branch_forest"]["total_nodes"] >= 1
    return proof, metrics


def _terminal_shape_fixture():
    record = {
        "payload_kind": "exact_blob", "payload_id": 1, "owner_entry_id": 1,
        "serialized_bytes": 164, "target_size_bytes": 80, "draft_size_bytes": 20,
    }
    return {
        "records": [record], "checkpoint_attempted": False, "checkpoint_prepared": False,
        "terminal_state": {
            "entry": {"entry_id": 1, "exact_link": 1, "checkpoint_link": 2,
                      "resident_bytes": 60, "has_target": True, "has_draft": True},
            "branch": {"branch_id": 1, "exact_link": 1, "checkpoint_link": 2,
                       "resident_bytes": 60, "has_target": True, "has_draft": True,
                       "sync_count": 1},
            "exact_descriptor": {"payload_id": 1, "residency": "cold", "cold_file_bytes": 164,
                                 "descriptor_bytes": 100, "byte_map_bytes": 164},
            "checkpoint_descriptor": {"payload_id": 2, "residency": "hot",
                                      "resident_component_bytes": 60},
            "cold_inventory": [{"name": "1.cold", "bytes": 164}], "staging_inventory": [],
            "topology": {"entry_count": 1, "node_count": 1, "lru_memberships": 1,
                         "entry_count_delta": 0, "node_count_delta": 0,
                         "lru_membership_delta": 0, "branch_prune_delta": 0,
                         "later_victim_count": 0},
            "decision_deltas": [{"mode": "hybrid", "result": "retained_cold",
                                 "reason": "cold_room", "value": 1}],
            "transaction_deltas": [{"mode": "hybrid", "result": "commit",
                                    "reason": "none", "value": 1}],
            "diagnostic_deltas": {},
            "forbidden_observations": {
                "checkpoint_cold_file": {
                    "before": {"exists": False, "name": "2.cold", "bytes": 0},
                    "after": {"exists": False, "name": "2.cold", "bytes": 0},
                    "event_delta": 0,
                },
                "checkpoint_descriptor": {
                    "before": {
                        "payload_id": 2, "owner_entry_id": 1, "payload_kind": "checkpoint",
                        "residency": "hot", "store_ref": 2, "target_size_bytes": 40,
                        "draft_size_bytes": 20, "target_checksum": 101, "draft_checksum": 202,
                        "resident_payload_bytes": 60, "pair_state": "target_and_draft",
                    },
                    "after": {
                        "payload_id": 2, "owner_entry_id": 1, "payload_kind": "checkpoint",
                        "residency": "hot", "store_ref": 2, "target_size_bytes": 40,
                        "draft_size_bytes": 20, "target_checksum": 101, "draft_checksum": 202,
                        "resident_payload_bytes": 60, "pair_state": "target_and_draft",
                    },
                    "event_delta": 0,
                },
                "checkpoint_link": {"before": 2, "after": 2, "event_delta": 0},
            },
            "forbidden_effects": {
                "checkpoint_classification_delta": 0, "checkpoint_admission_delta": 0,
                "checkpoint_publish_delta": 0, "checkpoint_commit_delta": 0,
                "checkpoint_cold_file_delta": 0, "checkpoint_descriptor_mutation_delta": 0,
                "checkpoint_link_mutation_delta": 0, "checkpoint_decision_delta": 0,
                "checkpoint_diagnostic_delta": 0, "later_work_delta": 0,
                "later_victim_delta": 0, "explicit_generation_advance_delta": 0,
                "duplicate_sync_delta": 0, "success_snapshot_count": 0,
                "failed_apply_count": 1,
            },
        },
    }


_TERMINAL_REQUIRED_PATHS = [
    "terminal_state.entry.entry_id", "terminal_state.entry.exact_link",
    "terminal_state.entry.checkpoint_link", "terminal_state.entry.resident_bytes",
    "terminal_state.entry.has_target", "terminal_state.entry.has_draft",
    "terminal_state.branch.branch_id", "terminal_state.branch.exact_link",
    "terminal_state.branch.checkpoint_link", "terminal_state.branch.resident_bytes",
    "terminal_state.branch.has_target", "terminal_state.branch.has_draft",
    "terminal_state.branch.sync_count", "terminal_state.exact_descriptor.payload_id",
    "terminal_state.exact_descriptor.residency", "terminal_state.exact_descriptor.cold_file_bytes",
    "terminal_state.exact_descriptor.descriptor_bytes", "terminal_state.exact_descriptor.byte_map_bytes",
    "terminal_state.checkpoint_descriptor.payload_id", "terminal_state.checkpoint_descriptor.residency",
    "terminal_state.checkpoint_descriptor.resident_component_bytes", "terminal_state.cold_inventory",
    "terminal_state.staging_inventory", "terminal_state.topology.entry_count",
    "terminal_state.topology.node_count", "terminal_state.topology.lru_memberships",
    "terminal_state.topology.entry_count_delta", "terminal_state.topology.node_count_delta",
    "terminal_state.topology.lru_membership_delta", "terminal_state.topology.branch_prune_delta",
    "terminal_state.topology.later_victim_count", "terminal_state.decision_deltas",
    "terminal_state.transaction_deltas", "terminal_state.diagnostic_deltas",
] + [
    "terminal_state.forbidden_observations." + group + "." + field
    for group in ("checkpoint_cold_file", "checkpoint_descriptor", "checkpoint_link")
    for field in ("before", "after", "event_delta")
] + [
    "terminal_state.forbidden_observations.checkpoint_descriptor." + side + "." + field
    for side in ("before", "after")
    for field in _terminal_shape_fixture()["terminal_state"]["forbidden_observations"][
        "checkpoint_descriptor"][side]
] + ["terminal_state.forbidden_effects." + key for key in _terminal_shape_fixture()[
    "terminal_state"]["forbidden_effects"]]


@pytest.mark.parametrize("path", _TERMINAL_REQUIRED_PATHS)
def test_stage39_terminal_shape_rejects_missing_required_field(path):
    proof = _terminal_shape_fixture()
    target = proof
    parts = path.split(".")
    for part in parts[:-1]:
        target = target[part]
    del target[parts[-1]]
    with pytest.raises((AssertionError, KeyError)):
        _assert_terminal_state_shape(proof, expected_fault="midpoint", checkpoint_attempted=False)


_TERMINAL_ZERO_PATHS = [
    "terminal_state.topology.entry_count_delta", "terminal_state.topology.node_count_delta",
    "terminal_state.topology.lru_membership_delta", "terminal_state.topology.branch_prune_delta",
    "terminal_state.topology.later_victim_count", "terminal_state.staging_inventory",
    "terminal_state.diagnostic_deltas",
] + [
    "terminal_state.forbidden_observations." + group + ".event_delta"
    for group in ("checkpoint_cold_file", "checkpoint_descriptor", "checkpoint_link")
] + ["terminal_state.forbidden_effects." + key for key in _terminal_shape_fixture()[
    "terminal_state"]["forbidden_effects"] if key != "failed_apply_count"]


@pytest.mark.parametrize("path", _TERMINAL_ZERO_PATHS)
def test_stage39_terminal_shape_rejects_nonzero_forbidden_delta(path):
    proof = _terminal_shape_fixture()
    target = proof
    parts = path.split(".")
    for part in parts[:-1]:
        target = target[part]
    target[parts[-1]] = 1
    with pytest.raises(AssertionError):
        _assert_terminal_state_shape(proof, expected_fault="midpoint", checkpoint_attempted=False)


def _retrieve_terminal_proof(server, request, proof):
    retrieval_request = {
        "operation": "prepared_proof",
        "process_identity": request["process_identity"],
        "test_session_id": proof["test_session_id"],
        "run_id": request["run_id"],
        "terminal_hmac": proof["terminal_hmac"],
    }
    response = server.control(retrieval_request)
    assert response.status_code == 200
    retrieved = response.json()
    assert retrieved == proof
    return retrieved


def _metrics_after_pressure(server):
    response = requests.get(server.base + "/metrics", timeout=30)
    if response.status_code != 200:
        server._block("BLOCKED-route-fixture-drift", "metrics request failed")
    try:
        return _parse_stage39_metrics(response.text)
    except ValueError as exc:
        server._block("BLOCKED-route-fixture-drift", str(exc))


_STAGE39_METRIC_SCHEMAS = {
    "llamacpp:cache_two_layer_decisions_total": {"mode", "result", "reason"},
    "llamacpp:cache_cold_transactions_total": {"mode", "result", "reason"},
    "llamacpp:cache_namespace_nodes": {"mode", "scope"},
}
_PROMETHEUS_SAMPLE = re.compile(
    r"^(llamacpp:cache_two_layer_decisions_total|"
    r"llamacpp:cache_cold_transactions_total|"
    r"llamacpp:cache_namespace_nodes)\{(.*)\}[ \t]+([^ \t]+)[ \t]*$")
_PROMETHEUS_LABEL = re.compile(
    r'([A-Za-z_][A-Za-z0-9_]*)="((?:\\[\\"nr]|[^"\\])*)"')


def _parse_prometheus_labels(text):
    labels = {}
    position = 0
    while position < len(text):
        match = _PROMETHEUS_LABEL.match(text, position)
        if match is None:
            raise ValueError("malformed target labels")
        name, encoded = match.groups()
        if name in labels:
            raise ValueError("duplicate target label")
        labels[name] = re.sub(
            r'\\([\\"nr])',
            lambda escaped: {"\\": "\\", '"': '"', "n": "\n", "r": "\r"}[
                escaped.group(1)],
            encoded,
        )
        position = match.end()
        if position == len(text):
            break
        if text[position] != ",":
            raise ValueError("malformed target labels")
        position += 1
        if position == len(text):
            raise ValueError("malformed target labels")
    if not labels:
        raise ValueError("missing target labels")
    return labels


def _parse_stage39_metrics(text):
    decisions = []
    transactions = []
    nodes = []
    tuples = set()
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        match = _PROMETHEUS_SAMPLE.fullmatch(line)
        if match is None:
            if any(name in line for name in _STAGE39_METRIC_SCHEMAS):
                raise ValueError("malformed target sample")
            continue
        family, label_text, value_text = match.groups()
        labels = _parse_prometheus_labels(label_text)
        if set(labels) != _STAGE39_METRIC_SCHEMAS[family]:
            raise ValueError("wrong target labels")
        if not re.fullmatch(r"[0-9]+", value_text):
            raise ValueError("target value is not a nonnegative integer")
        value = int(value_text)
        metric_tuple = (family, tuple(sorted(labels.items())))
        if metric_tuple in tuples:
            raise ValueError("duplicate target tuple")
        tuples.add(metric_tuple)
        if labels["mode"] != "hybrid":
            continue
        if family == "llamacpp:cache_two_layer_decisions_total":
            decisions.append({
                "result": labels["result"], "reason": labels["reason"], "value": value,
            })
        elif family == "llamacpp:cache_cold_transactions_total":
            transactions.append({
                "result": labels["result"], "reason": labels["reason"], "value": value,
            })
        elif labels["scope"] == "all":
            nodes.append(value)
    if len(nodes) != 1:
        raise ValueError("expected one hybrid/all namespace-node sample")
    return {
        "cache_two_layer_decisions": sorted(
            decisions, key=lambda row: (row["result"], row["reason"])),
        "cache_cold_transactions": sorted(
            transactions, key=lambda row: (row["result"], row["reason"])),
        "branch_forest": {"total_nodes": nodes[0]},
    }


def _mock_lifecycle():
    source = {
        "snapshot_generation": 18, "snapshot_token": "source-token",
        "hot_candidates": [], "cold_sets": [],
    }
    source_metrics = {
        "branch_forest": {"total_nodes": 1},
        "cache_two_layer_decisions": [], "cache_cold_transactions": [],
    }
    incoming = {
        "snapshot_generation": 36, "snapshot_token": "incoming-token",
        "hot_candidates": [{
            "payload_id": 101, "owner_entry_id": 11,
            "payload_kind": "exact_blob", "resident_bytes": 4096,
        }],
        "cold_sets": [{
            "incoming_payload_id": 101, "incoming_owner_entry_id": 11,
            "candidates": [],
        }],
    }
    incoming_metrics = {
        "branch_forest": {"total_nodes": 2},
        "cache_two_layer_decisions": [], "cache_cold_transactions": [],
    }
    return source, source_metrics, incoming, incoming_metrics


def test_mtp_request_contract_exact_bytes_hash_order_and_lengths():
    for role in ("source", "incoming"):
        encoded = _mtp_request_bytes(role)
        contract = MTP_REQUESTS[role]
        assert len(encoded) == contract["bytes"]
        assert hashlib.sha256(encoded).hexdigest() == contract["sha256"]
        body = json.loads(encoded, object_pairs_hook=dict)
        assert list(body) == [
            "model", "messages", "max_tokens", "temperature", "seed", "stream",
        ]
        assert [len(row["content"]) for row in body["messages"]] == contract["lengths"]
        assert body["messages"][-1]["content"].endswith(contract["suffix"])
        assert body["max_tokens"] == contract["max_tokens"]


def test_mtp_admit_pair_orders_two_requests_and_captures_source(monkeypatch):
    server = Stage39MTPServer.__new__(Stage39MTPServer)
    source, source_metrics, incoming, incoming_metrics = _mock_lifecycle()
    calls = []
    captures = {}

    def admit(role):
        calls.append(role)
        return ((200, source, source_metrics) if role == "source"
                else (200, incoming, incoming_metrics))

    monkeypatch.setattr(server, "_admit_chat", admit)
    monkeypatch.setattr(server, "_redacted_snapshot_token", lambda value: value)
    monkeypatch.setattr(server, "_write_json", lambda name, value: captures.setdefault(name, value))
    result = server._admit_two_requests()
    assert calls == ["source", "incoming"]
    assert result == (200, source, source_metrics, 200, incoming, incoming_metrics)
    assert captures == {
        "discovery-after-source.json": source,
        "metrics-after-source.json": source_metrics,
    }


def test_mtp_chat_admission_waits_for_http_200_then_idle(monkeypatch, tmp_path):
    server = Stage39MTPServer.__new__(Stage39MTPServer)
    server.artifacts = tmp_path
    server.base = "http://mock"
    events = []
    snapshot = {"hot_candidates": [], "cold_sets": []}
    metrics = {"branch_forest": {"total_nodes": 1},
               "cache_two_layer_decisions": [], "cache_cold_transactions": []}

    class Response:
        status_code = 200
        text = "{}"

    def post(*args, **kwargs):
        events.append(("http", kwargs["data"]))
        return Response()

    monkeypatch.setattr(requests, "post", post)
    monkeypatch.setattr(server, "_guard", lambda operation: events.append(("guard", operation)))
    monkeypatch.setattr(
        server, "_wait_for_idle_discovery",
        lambda: events.append(("idle", None)) or snapshot)
    monkeypatch.setattr(server, "_metrics", lambda: events.append(("metrics", None)) or metrics)
    code, observed, observed_metrics = server._admit_chat("source")
    assert code == 200 and observed is snapshot and observed_metrics is metrics
    assert [event[0] for event in events] == ["guard", "http", "idle", "metrics"]
    assert events[1][1] == _mtp_request_bytes("source")


def test_mtp_lifecycle_accepts_pinned_then_released_source():
    source, source_metrics, incoming, incoming_metrics = _mock_lifecycle()
    row = _validate_mtp_lifecycle(
        source, source_metrics, incoming, incoming_metrics, [])
    assert row["payload_id"] == 101 and row["owner_entry_id"] == 11


@pytest.mark.parametrize("mutation", [
    "source-hot", "source-node-count", "incoming-node-count", "missing-hot",
    "nonempty-cold", "owner-drift", "decision", "transaction",
])
def test_mtp_lifecycle_rejects_preproof_drift(mutation):
    source, source_metrics, incoming, incoming_metrics = _mock_lifecycle()
    if mutation == "source-hot":
        source["hot_candidates"] = [{"payload_id": 1}]
    elif mutation == "source-node-count":
        source_metrics["branch_forest"]["total_nodes"] = 2
    elif mutation == "incoming-node-count":
        incoming_metrics["branch_forest"]["total_nodes"] = 1
    elif mutation == "missing-hot":
        incoming["hot_candidates"] = []
    elif mutation == "nonempty-cold":
        incoming["cold_sets"][0]["candidates"] = [{"payload_id": 303}]
    elif mutation == "owner-drift":
        incoming["cold_sets"][0]["incoming_owner_entry_id"] = 22
    elif mutation == "decision":
        incoming_metrics["cache_two_layer_decisions"] = [{"value": 1}]
    else:
        incoming_metrics["cache_cold_transactions"] = [{"value": 1}]
    with pytest.raises(ValueError):
        _validate_mtp_lifecycle(source, source_metrics, incoming, incoming_metrics, [])


def test_stage39_metrics_parser_preserves_required_schema():
    body = """# HELP llamacpp:cache_namespace_nodes Branch nodes.
unrelated_metric{mode="hybrid"} 99
llamacpp:cache_two_layer_decisions_total{reason="both_filled",mode="hybrid",result="evicted"} 2
llamacpp:cache_two_layer_decisions_total{result="retained_cold",reason="cold_room",mode="hybrid"} 3
llamacpp:cache_cold_transactions_total{reason="rollback\\nretry",result="rollback",mode="hybrid"} 4
llamacpp:cache_cold_transactions_total{mode="hybrid",reason="none",result="commit"} 1
llamacpp:cache_namespace_nodes{scope="all",mode="hybrid"} 7
"""
    assert _parse_stage39_metrics(body) == {
        "cache_two_layer_decisions": [
            {"result": "evicted", "reason": "both_filled", "value": 2},
            {"result": "retained_cold", "reason": "cold_room", "value": 3},
        ],
        "cache_cold_transactions": [
            {"result": "commit", "reason": "none", "value": 1},
            {"result": "rollback", "reason": "rollback\nretry", "value": 4},
        ],
        "branch_forest": {"total_nodes": 7},
    }


def test_stage39_metrics_parser_ignores_non_sample_braces():
    body = """log prefix {not-json}
unrelated_before{mode="hybrid"} 1
llamacpp:cache_namespace_nodes{mode="hybrid",scope="all"} 8
unrelated_after{scope="all"} 2
log suffix {still-not-json}
"""
    assert _parse_stage39_metrics(body) == {
        "cache_two_layer_decisions": [],
        "cache_cold_transactions": [],
        "branch_forest": {"total_nodes": 8},
    }


@pytest.mark.parametrize("body", [
    "llamacpp:cache_two_layer_decisions_total{mode=\"hybrid\",result=\"x\",reason=\"y\"} 1\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\"} 1\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",mode=\"hybrid\",scope=\"all\"} 1\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",scope=\"all\"} 1\n"
    "llamacpp:cache_namespace_nodes{scope=\"all\",mode=\"hybrid\"} 2\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",scope=\"all\" 1\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",scope=\"all\"} -1\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",scope=\"all\"} 1.5\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",scope=\"all\"} NaN\n",
    "llamacpp:cache_namespace_nodes{mode=\"hybrid\",scope=\"all\"} +Inf\n",
])
def test_stage39_metrics_parser_rejects_target_schema_errors(body):
    with pytest.raises(ValueError):
        _parse_stage39_metrics(body)


def test_stage39_metrics_parser_detects_preapply_and_terminal_drift():
    canonical = """llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="retained_cold",reason="cold_room"} 1
llamacpp:cache_cold_transactions_total{mode="hybrid",result="commit",reason="none"} 1
llamacpp:cache_namespace_nodes{mode="hybrid",scope="all"} 2
"""
    before = _parse_stage39_metrics(canonical)
    assert before == _parse_stage39_metrics(canonical)
    for changed in (
            canonical.replace("cold_room\"} 1", "cold_room\"} 2"),
            canonical.replace("reason=\"none\"} 1", "reason=\"none\"} 2"),
            canonical.replace("scope=\"all\"} 2", "scope=\"all\"} 3")):
        assert before != _parse_stage39_metrics(changed)
    commits = sum(row["value"] for row in before["cache_cold_transactions"]
                  if row["result"] == "commit" and row["reason"] == "none")
    assert commits == 1


def test_live_pressure_slot_release_midpoint_smoke(tmp_path):
    del tmp_path
    with _mtp_server("slot-release-midpoint") as server:
        snapshot, proof = server.admit_pair()
        assert snapshot["hot_candidates"][0]["owner_entry_id"] == proof["rows"][0]["owner_entry_id"]
        assert not (server.artifacts / "apply-request.json").exists()
        assert not (server.artifacts / "apply-response.json").exists()


def test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal(tmp_path):
    del tmp_path
    with _mtp_server("midpoint-fault") as server:
        snapshot, runtime_proof = server.admit_pair()
        request = _mtp_prepared_apply(snapshot, runtime_proof, "midpoint")
        response = server.control(request)
        server.preserve_apply(request, response)
        proof, metrics = _assert_coherent_terminal_fault(
            server, response, expected_fault="midpoint", checkpoint_attempted=False)
        assert len(proof["records"]) == 1
        retrieved = _retrieve_terminal_proof(server, request, proof)
        server.preserve_terminal(retrieved, metrics)
        # No second shot: the one-shot control is consumed.
        second = server.control(request)
        assert second.status_code != 200
        assert "consumed" in second.text


def test_live_pressure_prepared_proof_step2_fault_coherent_terminal(tmp_path):
    del tmp_path
    with _mtp_server("step2-fault") as server:
        snapshot, runtime_proof = server.admit_pair()
        request = _mtp_prepared_apply(snapshot, runtime_proof, "step2")
        response = server.control(request)
        server.preserve_apply(request, response)
        proof, metrics = _assert_coherent_terminal_fault(
            server, response, expected_fault="step2", checkpoint_attempted=True)
        assert len(proof["records"]) == 2
        retrieved = _retrieve_terminal_proof(server, request, proof)
        server.preserve_terminal(retrieved, metrics)
        second = server.control(request)
        assert second.status_code != 200
        assert "consumed" in second.text
