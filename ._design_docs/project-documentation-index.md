# Project documentation index

This index covers project markdown files outside `._design_docs`.

## Project and contributor guides

| Document | What is inside | Useful for |
| --- | --- | --- |
| [README.md](../README.md) | Main project overview, quick start links, supported features, and common entry points. | Start here when learning what the project does. |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Contributor expectations, development workflow, tests, formatting, and PR guidance. | Use before preparing changes for upstream review. |
| [AGENTS.md](../AGENTS.md) | Local instructions for contributors and AI coding agents. | Use before editing this repository with an assistant. |
| [CLAUDE.md](../CLAUDE.md) | Claude-specific project notes. | Use when working with Claude-oriented tooling. |
| [SECURITY.md](../SECURITY.md) | Security policy and vulnerability reporting process. | Use when handling or reporting security issues. |

## Build, install, and deployment

| Document | What is inside | Useful for |
| --- | --- | --- |
| [docs/build.md](../docs/build.md) | Local build instructions for supported platforms and build options. | Use when setting up a development build. |
| [docs/install.md](../docs/install.md) | Prebuilt installation options. | Use when installing without building from source. |
| [docs/docker.md](../docs/docker.md) | Docker build and runtime instructions. | Use when running llama.cpp in containers. |
| [docs/android.md](../docs/android.md) | Android build and usage notes. | Use for Android targets. |
| [docs/build-s390x.md](../docs/build-s390x.md) | Build notes for s390x. | Use for IBM s390x builds. |
| [docs/build-riscv64-spacemit.md](../docs/build-riscv64-spacemit.md) | Build notes for RISC-V SpacemiT. | Use for that RISC-V target. |
| [ci/README.md](../ci/README.md) | Continuous integration setup and conventions. | Use when changing CI or debugging CI failures. |
| [ci/README-MUSA.md](../ci/README-MUSA.md) | MUSA CI notes. | Use when working on MUSA-related CI paths. |

## Runtime features and APIs

| Document | What is inside | Useful for |
| --- | --- | --- |
| [docs/speculative.md](../docs/speculative.md) | Speculative decoding behavior and configuration. | Use when tuning or testing draft-model generation. |
| [docs/preset.md](../docs/preset.md) | INI preset support. | Use when configuring repeatable command options. |
| [docs/function-calling.md](../docs/function-calling.md) | Function calling support and examples. | Use when integrating tool/function calls. |
| [docs/llguidance.md](../docs/llguidance.md) | LLGuidance support. | Use when constraining generation with LLGuidance. |
| [docs/multimodal.md](../docs/multimodal.md) | General multimodal support. | Use before working with image or multimodal models. |
| [docs/multi-gpu.md](../docs/multi-gpu.md) | Multi-GPU usage notes. | Use when spreading inference across GPUs. |
| [docs/ops.md](../docs/ops.md) | GGML operation documentation. | Use when inspecting or extending low-level ops. |
| [grammars/README.md](../grammars/README.md) | GBNF grammar guide. | Use when writing grammar-constrained generation rules. |
| [docs/autoparser.md](../docs/autoparser.md) | Auto-parser architecture. | Use when parsing model output with higher-level parser support. |
| [docs/development/parsing.md](../docs/development/parsing.md) | PEG parser and model-output parsing details. | Use when implementing parser-driven output handling. |

## Backend documentation

| Document | What is inside | Useful for |
| --- | --- | --- |
| [docs/backend/BLIS.md](../docs/backend/BLIS.md) | BLIS backend build and install notes. | Use when enabling BLIS. |
| [docs/backend/CANN.md](../docs/backend/CANN.md) | CANN backend setup. | Use for Ascend/CANN builds. |
| [docs/backend/CUDA-FEDORA.md](../docs/backend/CUDA-FEDORA.md) | CUDA setup on Fedora. | Use when preparing Fedora CUDA machines. |
| [docs/backend/OPENCL.md](../docs/backend/OPENCL.md) | OpenCL backend setup. | Use when building or testing OpenCL support. |
| [docs/backend/OPENVINO.md](../docs/backend/OPENVINO.md) | OpenVINO backend setup. | Use for Intel OpenVINO acceleration. |
| [docs/backend/SYCL.md](../docs/backend/SYCL.md) | SYCL backend setup. | Use when building with SYCL. |
| [docs/backend/VirtGPU.md](../docs/backend/VirtGPU.md) | VirtGPU backend overview. | Use when evaluating the VirtGPU backend. |
| [docs/backend/VirtGPU/configuration.md](../docs/backend/VirtGPU/configuration.md) | VirtGPU configuration. | Use when configuring VirtGPU runtime behavior. |
| [docs/backend/VirtGPU/development.md](../docs/backend/VirtGPU/development.md) | VirtGPU development and testing notes. | Use when modifying VirtGPU code. |
| [docs/backend/ZenDNN.md](../docs/backend/ZenDNN.md) | AMD ZenDNN backend notes. | Use for ZenDNN builds. |
| [docs/backend/zDNN.md](../docs/backend/zDNN.md) | IBM zDNN accelerator notes. | Use for zDNN targets. |
| [docs/backend/snapdragon/README.md](../docs/backend/snapdragon/README.md) | Snapdragon device overview. | Use before working on Snapdragon backends. |
| [docs/backend/snapdragon/developer.md](../docs/backend/snapdragon/developer.md) | Hexagon backend developer details. | Use when changing Snapdragon/Hexagon code. |
| [docs/backend/snapdragon/linux.md](../docs/backend/snapdragon/linux.md) | Snapdragon Linux instructions. | Use for Snapdragon Linux devices. |
| [docs/backend/snapdragon/windows.md](../docs/backend/snapdragon/windows.md) | Snapdragon Windows instructions. | Use for Snapdragon Windows devices. |

## Multimodal model notes

| Document | What is inside | Useful for |
| --- | --- | --- |
| [docs/multimodal/MobileVLM.md](../docs/multimodal/MobileVLM.md) | MobileVLM notes. | Use when running MobileVLM models. |
| [docs/multimodal/gemma3.md](../docs/multimodal/gemma3.md) | Gemma 3 vision notes. | Use for Gemma 3 multimodal setup. |
| [docs/multimodal/glmedge.md](../docs/multimodal/glmedge.md) | GLM Edge multimodal notes. | Use for GLM Edge vision models. |
| [docs/multimodal/granitevision.md](../docs/multimodal/granitevision.md) | Granite Vision notes. | Use for Granite Vision models. |
| [docs/multimodal/llava.md](../docs/multimodal/llava.md) | LLaVA notes. | Use for LLaVA-style models. |
| [docs/multimodal/minicpmv2.5.md](../docs/multimodal/minicpmv2.5.md) | MiniCPM-V 2.5 notes. | Use for MiniCPM-V 2.5. |
| [docs/multimodal/minicpmv2.6.md](../docs/multimodal/minicpmv2.6.md) | MiniCPM-V 2.6 notes. | Use for MiniCPM-V 2.6. |
| [docs/multimodal/minicpmv4.0.md](../docs/multimodal/minicpmv4.0.md) | MiniCPM-V 4.0 notes. | Use for MiniCPM-V 4.0. |
| [docs/multimodal/minicpmv4.5.md](../docs/multimodal/minicpmv4.5.md) | MiniCPM-V 4.5 notes. | Use for MiniCPM-V 4.5. |
| [docs/multimodal/minicpmv4.6.md](../docs/multimodal/minicpmv4.6.md) | MiniCPM-V 4.6 notes. | Use for MiniCPM-V 4.6. |
| [docs/multimodal/minicpmo2.6.md](../docs/multimodal/minicpmo2.6.md) | MiniCPM-o 2.6 notes. | Use for MiniCPM-o 2.6. |
| [docs/multimodal/minicpmo4.0.md](../docs/multimodal/minicpmo4.0.md) | MiniCPM-o 4.0 notes. | Use for MiniCPM-o 4.0. |

## Development references

| Document | What is inside | Useful for |
| --- | --- | --- |
| [docs/development/HOWTO-add-model.md](../docs/development/HOWTO-add-model.md) | Steps for adding a new model architecture. | Use before adding model support. |
| [docs/development/debugging-tests.md](../docs/development/debugging-tests.md) | Test debugging tips. | Use when investigating failing tests. |
| [docs/development/token_generation_performance_tips.md](../docs/development/token_generation_performance_tips.md) | Token-generation performance troubleshooting. | Use when profiling slow generation. |
| [common/jinja/README.md](../common/jinja/README.md) | llama.cpp Jinja engine documentation. | Use when changing chat template rendering. |
| [models/templates/README.md](../models/templates/README.md) | Model template notes. | Use when adding or adjusting model templates. |
| [gguf-py/README.md](../gguf-py/README.md) | Python GGUF package notes. | Use when working with GGUF Python tooling. |

## Server and UI

| Document | What is inside | Useful for |
| --- | --- | --- |
| [tools/server/README.md](../tools/server/README.md) | HTTP server usage, endpoints, and configuration. | Use when running or integrating `llama-server`. |
| [tools/server/README-dev.md](../tools/server/README-dev.md) | Server development scope and architecture notes. | Use before implementing server features. |
| [tools/server/tests/README.md](../tools/server/tests/README.md) | Server test documentation. | Use when running or extending server tests. |
| [tools/server/bench/README.md](../tools/server/bench/README.md) | Server benchmark notes. | Use when measuring server performance. |
| [tools/ui/README.md](../tools/ui/README.md) | llama-ui usage and setup. | Use when running the UI. |
| [tools/ui/docs/architecture/high-level-architecture.md](../tools/ui/docs/architecture/high-level-architecture.md) | UI high-level architecture. | Use before changing UI structure. |
| [tools/ui/docs/architecture/high-level-architecture-simplified.md](../tools/ui/docs/architecture/high-level-architecture-simplified.md) | Simplified UI architecture. | Use for a shorter UI architecture overview. |
| [tools/ui/docs/flows/chat-flow.md](../tools/ui/docs/flows/chat-flow.md) | UI chat flow. | Use when changing chat behavior. |
| [tools/ui/docs/flows/conversations-flow.md](../tools/ui/docs/flows/conversations-flow.md) | UI conversations flow. | Use when changing conversation management. |
| [tools/ui/docs/flows/data-flow-simplified-model-mode.md](../tools/ui/docs/flows/data-flow-simplified-model-mode.md) | Simplified model-mode data flow. | Use when tracing model-mode UI data. |
| [tools/ui/docs/flows/data-flow-simplified-router-mode.md](../tools/ui/docs/flows/data-flow-simplified-router-mode.md) | Simplified router-mode data flow. | Use when tracing router-mode UI data. |
| [tools/ui/docs/flows/database-flow.md](../tools/ui/docs/flows/database-flow.md) | UI database flow. | Use when changing local data persistence. |
| [tools/ui/docs/flows/mcp-flow.md](../tools/ui/docs/flows/mcp-flow.md) | UI MCP flow. | Use when changing MCP integration. |
| [tools/ui/docs/flows/models-flow.md](../tools/ui/docs/flows/models-flow.md) | UI models flow. | Use when changing model selection or management. |
| [tools/ui/docs/flows/server-flow.md](../tools/ui/docs/flows/server-flow.md) | UI server flow. | Use when changing server lifecycle handling. |
| [tools/ui/docs/flows/settings-flow.md](../tools/ui/docs/flows/settings-flow.md) | UI settings flow. | Use when changing settings behavior. |
| [tools/ui/src/lib/components/app/SKILL.md](../tools/ui/src/lib/components/app/SKILL.md) | Skill metadata for the UI app component area. | Use when working with that local skill/component guidance. |

## Tools

| Document | What is inside | Useful for |
| --- | --- | --- |
| [tools/batched-bench/README.md](../tools/batched-bench/README.md) | Batched benchmark tool notes. | Use when benchmarking batched workloads. |
| [tools/cli/README.md](../tools/cli/README.md) | CLI tool usage. | Use when running command-line inference. |
| [tools/completion/README.md](../tools/completion/README.md) | Completion tool usage. | Use when testing text completion flows. |
| [tools/cvector-generator/README.md](../tools/cvector-generator/README.md) | Control vector generator notes. | Use when generating control vectors. |
| [tools/export-lora/README.md](../tools/export-lora/README.md) | LoRA export tool notes. | Use when exporting LoRA adapters. |
| [tools/fit-params/README.md](../tools/fit-params/README.md) | Fit-params tool notes. | Use when estimating model/runtime parameters. |
| [tools/gguf-split/README.md](../tools/gguf-split/README.md) | GGUF split tool notes. | Use when splitting GGUF files. |
| [tools/imatrix/README.md](../tools/imatrix/README.md) | Importance matrix tool notes. | Use when generating imatrix data for quantization. |
| [tools/llama-bench/README.md](../tools/llama-bench/README.md) | llama-bench usage. | Use when benchmarking inference. |
| [tools/mtmd/README.md](../tools/mtmd/README.md) | Multimodal tool support. | Use when working with `mtmd`. |
| [tools/mtmd/debug/mtmd-debug.md](../tools/mtmd/debug/mtmd-debug.md) | `mtmd-debug` notes. | Use when debugging multimodal inputs. |
| [tools/perplexity/README.md](../tools/perplexity/README.md) | Perplexity tool usage. | Use when evaluating perplexity. |
| [tools/quantize/README.md](../tools/quantize/README.md) | Quantization tool usage. | Use when quantizing models. |
| [tools/results/README.md](../tools/results/README.md) | Results tool notes. | Use when handling benchmark or evaluation results. |
| [tools/rpc/README.md](../tools/rpc/README.md) | RPC tool notes. | Use when running RPC backend workflows. |
| [tools/tts/README.md](../tools/tts/README.md) | TTS tool notes. | Use when running text-to-speech examples. |

## Examples

| Document | What is inside | Useful for |
| --- | --- | --- |
| [examples/batched/README.md](../examples/batched/README.md) | Batched example. | Use when learning batched inference. |
| [examples/batched.swift/README.md](../examples/batched.swift/README.md) | Swift batched example. | Use for Swift batched inference. |
| [examples/convert-llama2c-to-ggml/README.md](../examples/convert-llama2c-to-ggml/README.md) | llama2.c to GGML conversion example. | Use when converting that model format. |
| [examples/debug/README.md](../examples/debug/README.md) | Debug example. | Use when exploring debug flows. |
| [examples/deprecation-warning/README.md](../examples/deprecation-warning/README.md) | Binary filename migration notice. | Use when updating old binary names. |
| [examples/diffusion/README.md](../examples/diffusion/README.md) | Diffusion text generation example. | Use when testing diffusion generation. |
| [examples/embedding/README.md](../examples/embedding/README.md) | Embedding example. | Use when generating embeddings. |
| [examples/eval-callback/README.md](../examples/eval-callback/README.md) | Evaluation callback example. | Use when adding or testing callbacks. |
| [examples/gguf-hash/README.md](../examples/gguf-hash/README.md) | GGUF hash example. | Use when checking GGUF hashes. |
| [examples/idle/README.md](../examples/idle/README.md) | Idle example. | Use when testing idle behavior. |
| [examples/llama-eval/README.md](../examples/llama-eval/README.md) | llama-eval example. | Use when evaluating model outputs. |
| [examples/llama.swiftui/README.md](../examples/llama.swiftui/README.md) | SwiftUI example. | Use when building an Apple UI around llama.cpp. |
| [examples/lookahead/README.md](../examples/lookahead/README.md) | Lookahead example. | Use when testing lookahead decoding. |
| [examples/lookup/README.md](../examples/lookup/README.md) | Lookup example. | Use when testing lookup behavior. |
| [examples/model-conversion/README.md](../examples/model-conversion/README.md) | Model conversion example. | Use when converting model formats. |
| [examples/parallel/README.md](../examples/parallel/README.md) | Parallel example. | Use when testing parallel requests. |
| [examples/passkey/README.md](../examples/passkey/README.md) | Passkey example. | Use when testing long-context recall. |
| [examples/retrieval/README.md](../examples/retrieval/README.md) | Retrieval example. | Use when testing retrieval workflows. |
| [examples/simple/README.md](../examples/simple/README.md) | Simple inference example. | Use for a minimal llama.cpp example. |
| [examples/simple-chat/README.md](../examples/simple-chat/README.md) | Simple chat example. | Use for a minimal chat flow. |
| [examples/simple-cmake-pkg/README.md](../examples/simple-cmake-pkg/README.md) | Simple CMake package example. | Use when embedding llama.cpp via CMake. |
| [examples/speculative/README.md](../examples/speculative/README.md) | Speculative decoding example. | Use when trying draft-model inference. |
| [examples/speculative-simple/README.md](../examples/speculative-simple/README.md) | Simple speculative decoding example. | Use for a smaller speculative decoding demo. |
| [examples/sycl/README.md](../examples/sycl/README.md) | SYCL example. | Use when testing SYCL example builds. |
| [examples/training/README.md](../examples/training/README.md) | Training example. | Use when exploring training workflows. |

## Benchmarks

| Document | What is inside | Useful for |
| --- | --- | --- |
| [benches/dgx-spark/dgx-spark.md](../benches/dgx-spark/dgx-spark.md) | DGX Spark benchmark notes. | Use when comparing DGX Spark results. |
| [benches/mac-m2-ultra/mac-m2-ultra.md](../benches/mac-m2-ultra/mac-m2-ultra.md) | Mac M2 Ultra benchmark notes. | Use when comparing Apple Silicon results. |
| [benches/nemotron/nemotron-dgx-spark.md](../benches/nemotron/nemotron-dgx-spark.md) | Nemotron on DGX Spark benchmark notes. | Use when reviewing Nemotron benchmark data. |
