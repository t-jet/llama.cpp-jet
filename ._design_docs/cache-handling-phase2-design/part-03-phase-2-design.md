# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 3: Phase 2 Design

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

#### Phase 2 Design

**New Structure for Return Value**:

```cpp
// In server-chat.h
struct prepared_prompt_result {
    server_tokens tokens;
    prepared_prompt_metadata metadata;  // Boundary information
    bool success;
    std::string error_message;
};
```

**Enhanced Chat Template Application**:

```cpp
// In server-chat.cpp
prepared_prompt_result apply_chat_template_with_metadata(
    llama_context * ctx,
    const json & messages,
    const std::string & template_str,
    bool add_generation_prompt = false)
{
    prepared_prompt_result result;
    result.success = false;
    
    // 1. Parse template and extract structure
    // This requires understanding the template's output structure
    
    // 2. Track token offsets during tokenization
    size_t current_offset = 0;
    
    // 3. Process each message with boundary tracking
    for (size_t i = 0; i < messages.size(); i++) {
        const auto & msg = messages[i];
        const std::string role = msg.value("role", "");
        const std::string content = msg.value("content", "");
        
        // Handle system message
        if (role == "system") {
            size_t start_offset = current_offset;
            
            // Tokenize system prompt
            auto sys_tokens = llama_tokenize(ctx, content, ...);
            result.tokens.insert(result.tokens.end(), 
                               sys_tokens.begin(), sys_tokens.end());
            
            size_t end_offset = current_offset + sys_tokens.size();
            
            // Record system boundaries
            prompt_boundary sys_start{
                boundary_type::SYSTEM_START,
                static_cast<int>(start_offset)
            };
            prompt_boundary sys_end{
                boundary_type::SYSTEM_END,
                static_cast<int>(end_offset)
            };
            
            result.metadata.add_boundary(sys_start);
            result.metadata.add_boundary(sys_end);
            
            current_offset = end_offset;
        }
        // Handle regular messages
        else {
            size_t msg_start = current_offset;
            
            // Apply template prefix for this message role
            std::string prefix = get_role_prefix(template_str, role);
            auto prefix_tokens = llama_tokenize(ctx, prefix, ...);
            result.tokens.insert(result.tokens.end(), 
                               prefix_tokens.begin(), prefix_tokens.end());
            current_offset += prefix_tokens.size();
            
            // Mark message start
            size_t content_start = current_offset;
            prompt_boundary msg_start_boundary{
                boundary_type::MESSAGE_START,
                static_cast<int>(content_start)
            };
            result.metadata.add_boundary(msg_start_boundary);
            
            // Tokenize content
            auto content_tokens = llama_tokenize(ctx, content, ...);
            result.tokens.insert(result.tokens.end(), 
                               content_tokens.begin(), content_tokens.end());
            current_offset += content_tokens.size();
            
            // Mark message end
            prompt_boundary msg_end_boundary{
                boundary_type::MESSAGE_END,
                static_cast<int>(current_offset)
            };
            result.metadata.add_boundary(msg_end_boundary);
            
            // Apply template suffix
            std::string suffix = get_role_suffix(template_str, role);
            auto suffix_tokens = llama_tokenize(ctx, suffix, ...);
            result.tokens.insert(result.tokens.end(), 
                               suffix_tokens.begin(), suffix_tokens.end());
            current_offset += suffix_tokens.size();
        }
        
        // Handle tool calls if present
        if (msg.contains("tool_calls")) {
            const auto & tool_calls = msg["tool_calls"];
            
            for (const auto & tool_call : tool_calls) {
                size_t tool_start = current_offset;
                
                // Tokenize tool call
                std::string tool_str = tool_call.dump();
                auto tool_tokens = llama_tokenize(ctx, tool_str, ...);
                result.tokens.insert(result.tokens.end(), 
                                   tool_tokens.begin(), tool_tokens.end());
                
                size_t tool_end = current_offset + tool_tokens.size();
                
                // Record tool boundaries
                result.metadata.add_boundary(
                    prompt_boundary{boundary_type::TOOL_CALL_START, 
                                  static_cast<int>(tool_start)});
                result.metadata.add_boundary(
                    prompt_boundary{boundary_type::TOOL_CALL_END, 
                                  static_cast<int>(tool_end)});
                
                current_offset = tool_end;
            }
        }
    }
    
    // 4. Add generation prompt if requested
    if (add_generation_prompt) {
        std::string gen_prompt = get_generation_prompt(template_str);
        auto gen_tokens = llama_tokenize(ctx, gen_prompt, ...);
        result.tokens.insert(result.tokens.end(), 
                           gen_tokens.begin(), gen_tokens.end());
        current_offset += gen_tokens.size();
    }
    
    result.success = true;
    return result;
}
```

#### Template-Specific Handling

Different chat templates have different structures. We need template-aware boundary extraction:

```cpp
// Helper to detect template type and extract boundaries accordingly
class ChatTemplateParser {
public:
    virtual prepared_prompt_result parse(
        llama_context * ctx,
        const json & messages,
        bool add_generation_prompt) = 0;
    
    static std::unique_ptr<ChatTemplateParser> 
    create_parser(const std::string & template_str);
};

// Example: ChatML template parser
class ChatMLParser : public ChatTemplateParser {
    // Handles: <|im_start|>role\ncontent<|im_end|>
    prepared_prompt_result parse(...) override;
};

// Example: Llama2 template parser  
class Llama2Parser : public ChatTemplateParser {
    // Handles: [INST] content [/INST]
    prepared_prompt_result parse(...) override;
};

// Example: Generic/fallback parser
class GenericParser : public ChatTemplateParser {
    // Best-effort boundary detection
    prepared_prompt_result parse(...) override;
};
```

#### Fallback Strategy

When boundary extraction fails or is unavailable:

```cpp
prepared_prompt_result apply_chat_template_safe(
    llama_context * ctx,
    const json & messages,
    const std::string & template_str,
    bool add_generation_prompt = false)
{
    try {
        // Try enhanced extraction
        return apply_chat_template_with_metadata(
            ctx, messages, template_str, add_generation_prompt);
    }
    catch (const std::exception & e) {
        LOG_WRN("Boundary extraction failed: %s (falling back to basic)\n", 
                e.what());
        
        // Fallback: tokenize without boundaries
        prepared_prompt_result result;
        result.tokens = apply_chat_template(
            ctx, messages, template_str, add_generation_prompt);
        result.success = true;
        // result.metadata remains empty - cache will handle gracefully
        
        return result;
    }
}
```

#### Integration with Task Creation

Update task creation to populate metadata:

```cpp
// In server-task.cpp or server-http.cpp
server_task create_chat_completion_task(const json & request) {
    server_task task;
    task.type = server_task_type::TASK_TYPE_COMPLETION;
    
    // Extract messages
    const auto & messages = request["messages"];
    
    // Apply template WITH boundary extraction
    prepared_prompt_result prep_result = apply_chat_template_with_metadata(
        ctx, messages, chat_template, true);
    
    if (!prep_result.success) {
        task.error = prep_result.error_message;
        return task;
    }
    
    // Populate task with tokens AND metadata
    task.prompt_tokens = std::move(prep_result.tokens);
    task.prompt_metadata = std::move(prep_result.metadata);  // KEY: Metadata attached
    
    LOG_DBG("Created task with %zu tokens and %zu boundaries\n",
            task.prompt_tokens.size(),
            task.prompt_metadata.boundaries.size());
    
    return task;
}
```

