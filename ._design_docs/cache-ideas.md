# Cache optimization ideas


## Keep only checkpoints and checksums+token count/length between

Avoid keeping prompt KV tokens in the cache, instead keep only checkpoints and checksums+token count/length between. This way we can restore the state of the cache without having to keep all the tokens in memory, which can be very large for long prompts. For matching incomping prompt with the cache, get number of tokens between checkpoints and the checksum for the root of the cache, then get the same number of tokens from the incoming prompt and calculate the checksum, if it matches, we can restore the cache state from the checkpoint. Doing it across all prompt starts we can choose candidates, then take all branches of those candidates and for each branch repeat the compaison process until we find the best match. This way we can restore the cache state without having to keep all the tokens in memory, which can be very large for long prompts.
For multimedia chunks we can use their own checksums and length and incorporate these values to the sequence against which checksums between checkpoints are calculated. When calculating the checksum for the incoming prompt, we can also calculate the checksum for the multimedia chunks and incorporate these values to the sequence against which checksums between checkpoints are calculated. This way we can restore the cache state even if the prompt contains multimedia chunks, without having to keep all the tokens in memory.

It would decrease efficiency for the "classical" models which can restore their state by simply appending tokens to layer's outputs, but using such models as a special case with a separate cache management logic seems like a premature optimization, especially considering that the "classical" models are not the main target for optimization in the first place. Moreover, it would make the cache management logic more complex and harder to maintain, while the proposed approach is more general and can be applied to any model architecture without requiring special handling for specific cases. Anyway, using the new cache management logic should be optional and switched on only if user specifies corresponding option in the command parameters.

## Set checkpoint boundaries at the boundary of messages instead of at the boundary of tokens.

Conversations naturally splitted into messages (system, user, assistant, tools output, ...) so it's more intuitive to set checkpoint boundaries at the boundary of messages instead of at the boundary of tokens. This way we can restore the cache state and branch conversations more efficiently. In the current implementation, if we have a long message that exceeds checkpoint threshold, we have to split it into multiple checkponts, wich will consume more memory, but wouldn't allow us to restore the cache state exactly on the message booundry which will cause additional computation to restore conversation up to the end of message if next checkpoint was set after the message end.

## Offload to the "Cold" on-disk cache layer

Offload less frequently used checkpoints to the cold on-disk cache layer, which will free memory to keep more history in the cache and allow to restore the cache state for longer conversations. Hot branches of the cache can be kept in memory for faster access, while checkpoint from cold branches can be offloaded to disk and loaded back into memory when needed. With modern SSD storage access speeds and OS caching mechanisms, the performance impact of loading checkpoints from disk should be minimal.
User can specify path to the directory where cold cache checkpoints will be stored, maximum size of the cold cache layer and the policy for offloading checkpoints to the cold cache layer, e.g. based on the last access time or the distance from the current position in the conversation.


## Think about cache as a wood and trees

The cach can be thought of as a wood, where each tree starts at the first prompt message and grows withe each new checpoint/message. Each tree can have multiple branches, which represent different conversation paths. It splits into branches on some tokens inside the conversation path, whoch ideally should be set at the boundary of messages and have a corresponding checkpoint, covering the state at the end of the message. When we want to restore the cache state for a given prompt, we can traverse the wood and find the best matching tree and branch, which will allow us to restore the cache state efficiently. If there is no matching tree or branch, we can create a new tree or branch for that prompt and add it to the wood.
Each tree can have metadata, attributing it to specific model to distinguish between different models and their corresponding caches.

## Don't separate cache between slots

The whole wood can be reused by any slot in parallel environment, but each slot will have its own pointer to the current position in the wood, which will allow it to restore the cache state independently from other slots. 

## MTP models should have synchronised cache for prediction model context and main model

For MTP models, the prediction model context can have it's own cache, but it should be synchronised with the cache of the main model to restore both states synchronously. It seems that cache elimination and cold layer offloading should be applied synchronously as well.

## Reuse model calculated tokens up to the point when it uses external information, e.g. a tool call.

For agentic workflows we can provide an option to reuse model calculated tokens up to the point when it uses external information, e.g. a tool call or user input. This way we can restore the cache state for the part of the conversation that doesn't involve external information, which can save time and resources. As an example, if one agent invokes another agent with a similar prompt, the first response prodused by the second agent can be provided from the cache instead of recalculating it. I'm thinking about it as analogue of using the model with fixed random seed and zero temperature to reproduce the same output for the same input, which in the case of the proposed option should mean that the first variants of the moel response are trusted for the all future invocations of the same prompt.

## Support capability to explicitly mark positions in the prompt to be cached, like in v1/messages from Anthropic.

Probably we can support capability to explicitly mark positions in the prompt to be cached, like in v1/messages from Anthropic. This way we can have more control over the cache and allow users to specify which parts of the prompt should be cached and which should not. It can be useful for cases when we want to cache only specific messages or parts of messages, e.g. system instructions or user inputs, while not caching other parts of the prompt, e.g. model responses or tool outputs.

Link: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

