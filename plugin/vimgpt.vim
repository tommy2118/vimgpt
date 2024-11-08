" vimgpt.vim - Plugin to chat with ChatGPT within Vim, with conversation and code-only support
"
" # VimGPT Plugin Documentation
"
" ## Overview
" VimGPT is a Vim plugin that allows you to interact with OpenAI's ChatGPT model directly within Vim. 
" You can submit prompts, request code snippets, engage in continuous conversations, and display responses in various formats.
"
" ## Prerequisites
" - **API Key**: Ensure that you have an OpenAI API key and that it is available in your environment as `$OPENAI_API_KEY`.
" - **Curl**: This plugin relies on `curl` to send HTTP requests.
"
" ## Installation
" Place this plugin in your Vim plugins directory, or use a plugin manager like vim-plug:
"
" ```vim
" Plug 'path/to/vimgpt.vim'
" ```
" After installing, reload Vim and ensure `$OPENAI_API_KEY` is set in your environment.
"
" ## Commands
"
" ### `:ChatGPT <prompt>`
" Sends a single prompt to ChatGPT and displays the response in the Quickfix List. Each use clears the conversation history.
" - **Example**: `:ChatGPT "Explain recursion in simple terms"`
"
" ### `:ChatGPTCode <prompt>`
" Requests only code from ChatGPT and displays it in a new, full-screen buffer. Clears conversation history each time.
" - **Example**: `:ChatGPTCode "Show me a Python function to calculate factorial"`
"
" ### `:ChatGPTConversation <prompt>`
" Sends a prompt with conversation history retained, allowing for ongoing interactions.
" - **Example**:
" ```vim
" :ChatGPTConversation "Hello, who are you?"
" :ChatGPTConversation "Can you tell me more about yourself?"
" ```
"
" ### `:ChatGPTBuffer`
" Combines a custom prompt with selected text (or entire buffer if nothing is selected) and sends it to ChatGPT as a single request.
" - **Usage**: Select text in visual mode, then `:ChatGPTBuffer`, or run directly for full buffer content.
"
" ## Troubleshooting
" - **No API Key**: Ensure `$OPENAI_API_KEY` is set in your environment.
" - **Dependencies**: Ensure `curl` is installed on your system.
" - **Clearing Buffers**: Use `:bwipeout` if buffer conflicts occur.
"
" ---------------------------- END DOCUMENTATION -----------------------------

" Store the OpenAI API key (replace with environment variable for security in a real setup)
let g:vimgpt_api_key = $OPENAI_API_KEY  " Ensure this is exported in your shell

" API URL for OpenAI’s ChatGPT
let g:vimgpt_api_url = 'https://api.openai.com/v1/chat/completions'

" Function to send a single prompt to ChatGPT without retaining history
function! VimgptRequest(prompt, code_only) abort
    " Clear conversation history for single prompt requests
    let g:vimgpt_conversation = []

    " Add the current user prompt to the conversation
    call add(g:vimgpt_conversation, {'role': 'user', 'content': a:prompt})

    " Display prompt in Quickfix List for reference if not code-only
    if !a:code_only
        call s:DisplayInQuickfix(["You: " . a:prompt])
    endif

    " Send the prompt to ChatGPT
    call VimgptRequestAsync(a:prompt, a:code_only)
endfunction

" Function to send a prompt to ChatGPT, retaining conversation history
function! VimgptConversationRequest(prompt) abort
    " Add the current user prompt to the ongoing conversation
    call add(g:vimgpt_conversation, {'role': 'user', 'content': a:prompt})

    " Display the prompt in Quickfix List for reference
    call s:DisplayInQuickfix(["You: " . a:prompt])

    " Send the prompt to ChatGPT, without clearing history, and show full response
    call VimgptRequestAsync(a:prompt, 0)
endfunction

" Function to send selected text or buffer content with custom prompt to ChatGPT
function! VimgptRequestFromBufferWithPrompt() abort
    " Clear conversation history to treat this as a single prompt
    let g:vimgpt_conversation = []

    " Prompt user for custom context or question
    let l:custom_prompt = input("Enter your prompt or context: ")

    " Get the selected text in visual mode or the entire buffer content if no selection
    let l:buffer_text = s:GetSelectedOrBufferText()

    if l:buffer_text == ""
        echo "No text selected or available in buffer."
        return
    endif

    " Combine custom prompt with buffer content
    let l:combined_prompt = l:custom_prompt . "\n\n" . l:buffer_text

    " Display the combined prompt in the Quickfix List
    call s:DisplayInQuickfix(["You: " . l:combined_prompt])

    " Send the combined prompt to ChatGPT without code-only flag (0 indicates full response)
    call VimgptRequestAsync(l:combined_prompt, 0)
endfunction

" Helper function to get selected text or full buffer content
function! s:GetSelectedOrBufferText() abort
    " Check if in visual mode
    if mode() ==# 'v' || mode() ==# 'V' || mode() ==# "\<C-V>"
        " Get visually selected text
        let [lnum1, col1] = getpos("'<")[1:2]
        let [lnum2, col2] = getpos("'>")[1:2]
        return join(getline(lnum1, lnum2), "\n")
    else
        " Get entire buffer content
        return join(getline(1, '$'), "\n")
    endif
endfunction

" Asynchronous function to send a request to ChatGPT API using a temporary file
function! VimgptRequestAsync(prompt, code_only) abort
    let l:api_key = g:vimgpt_api_key
    let l:url = g:vimgpt_api_url

    " Convert the conversation history to JSON
    let l:data = '{"model": "gpt-3.5-turbo", "messages": ' . json_encode(g:vimgpt_conversation) . '}'

    " Define a temporary file to store the output
    let l:tempfile = tempname()

    " Prepare the curl command as a list for job_start, redirecting output to tempfile
    let l:command = [
          \ 'curl', '-s', '-X', 'POST', l:url,
          \ '-H', 'Content-Type: application/json',
          \ '-H', 'Authorization: Bearer ' . l:api_key,
          \ '-d', l:data, '-o', l:tempfile
          \ ]

    " Start the job asynchronously and pass the tempfile to the handler
    let l:job = job_start(l:command)

    " Wait briefly and handle response after job completes, passing tempfile and code_only flag
    call timer_start(100, { -> s:HandleGPTResponse(l:job, l:tempfile, a:code_only) })
endfunction

" Function to handle the ChatGPT response after job completes, with code filtering option
function! s:HandleGPTResponse(job_id, tempfile, code_only) abort
    " Check if the job is still running
    if job_status(a:job_id) != 'dead'
        " Recheck after a short delay if the job is not done
        call timer_start(100, { -> s:HandleGPTResponse(a:job_id, a:tempfile, a:code_only) })
        return
    endif

    " Read the response from the tempfile
    let l:response = join(readfile(a:tempfile), "\n")

    " Remove problematic control characters, escape sequences, and `||` markers
    let l:response = substitute(l:response, '[\x00-\x1F\x7F\x80-\x9F]', '', 'g')
    let l:response = substitute(l:response, '||', '', 'g')

    " Decode JSON response
    let l:json = json_decode(l:response)

    " Check if the API returned a valid response
    if has_key(l:json, 'choices')
        let l:reply = l:json['choices'][0]['message']['content']

        " Add assistant's reply to conversation history for ongoing conversations
        if a:code_only == 0
            call add(g:vimgpt_conversation, {'role': 'assistant', 'content': l:reply})
        endif

        " If code_only is set, extract code blocks only and display in a new buffer
        if a:code_only
            let l:code_content = s:ExtractCodeBlocks(l:reply)
            if empty(l:code_content)
                let l:code_content = ["No code blocks found in the response."]
            endif
            call s:DisplayCodeInNewBuffer(l:code_content)
        else
            " Otherwise, format the entire response and display in Quickfix List
            let l:formatted_reply = s:FormatReply(l:reply)
            call s:DisplayInQuickfix(l:formatted_reply)
        endif
    else
        " Display error if response is invalid
        call s:DisplayInQuickfix(["Error: " . l:response])
    endif

    " Clean up by deleting the temporary file
    call delete(a:tempfile)
endfunction

" Function to extract only code blocks from the response text
function! s:ExtractCodeBlocks(response) abort
    let l:lines = split(a:response, "\n")
    let l:code_lines = []
    let l:in_code_block = 0

    for l:line in l:lines
        " Detect code block markers
        if l:line =~ '^```'
            let l:in_code_block = !l:in_code_block
        elseif l:in_code_block
            " If inside a code block, add the line to code_lines
            call add(l:code_lines, l:line)
        endif
    endfor

    return l:code_lines
endfunction

" Function to display code-only output in a new full-screen buffer
function! s:DisplayCodeInNewBuffer(code_content) abort
    " Generate a unique buffer name with a timestamp to avoid conflicts
    let l:buffer_name = "ChatGPT_Code_Response_" . strftime("%Y%m%d%H%M%S") . "_" . reltimestr(reltime())

    " Check if a buffer with this name already exists and wipe it if so
    if bufexists(l:buffer_name)
        execute 'bwipeout' l:buffer_name
    endif

    " Open a new buffer with the unique name
    execute 'enew'
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    execute 'file ' . l:buffer_name

    " Insert code content into the new buffer
    call append(0, a:code_content)

    " Maximize the buffer to a full-screen layout
    " Close all other windows temporarily
    execute 'only'

    " Move cursor to the top of the buffer
    normal! gg
endfunction

" Function to format the reply into paragraphs for the Quickfix List
function! s:FormatReply(reply) abort
    " Split the reply into lines and initialize formatting
    let l:lines = split(a:reply, '\n')
    let l:formatted_paragraphs = []
    let l:paragraph = ""

    for l:line in l:lines
        " Detect code block markers and treat them as individual lines
        if l:line =~ '```'
            if l:paragraph != ""
                call add(l:formatted_paragraphs, l:paragraph)
                let l:paragraph = ""
            endif
            call add(l:formatted_paragraphs, l:line)
        elseif l:line =~ '^\s*$'
            " If there's an empty line, finalize the current paragraph
            if l:paragraph != ""
                call add(l:formatted_paragraphs, l:paragraph)
                let l:paragraph = ""
            endif
        else
            " Add line to the current paragraph, adding a space between lines
            let l:paragraph .= (l:paragraph == "" ? "" : " ") . l:line
        endif
    endfor

    " Add any remaining paragraph
    if l:paragraph != ""
        call add(l:formatted_paragraphs, l:paragraph)
    endif

    return l:formatted_paragraphs
endfunction

" Function to display the output in the Quickfix List
function! s:DisplayInQuickfix(paragraphs) abort
    " Populate the Quickfix List with the paragraphs as separate entries
    call setqflist([], 'r', {'title': 'ChatGPT Response', 'lines': a:paragraphs})

    " Open the Quickfix List
    copen
endfunction

" Define commands to trigger ChatGPT conversation, single prompt, or code-only response
command! -nargs=1 ChatGPT call VimgptRequest(<f-args>, 0)
command! -nargs=1 ChatGPTCode call VimgptRequest(<f-args>, 1)
command! -nargs=1 ChatGPTConversation call VimgptConversationRequest(<f-args>)
command! ChatGPTBuffer call VimgptRequestFromBufferWithPrompt()
