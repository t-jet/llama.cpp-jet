# Historical link: restore and residency flow

This filename is retained for closed stage and test-record links. Current
restore, strict-prefix, hot/cold residency, and transaction behavior is in
[Part 4](part-04-runtime-behavior.md). Deployment and configuration are in
[Part 2](part-02-containers-and-deployment.md).

## Adopted Jinja boundary interface

Older test fixtures used template markers to verify boundary extraction. Current
production architecture does not require template-injected cache markers. Prompt
metadata is built internally after rendering and tokenization, as described in
[Part 3](part-03-components-and-data.md#prompt-metadata).

This file adds no architecture contract.
