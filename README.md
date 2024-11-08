VimGPT

VimGPT is a Vim plugin for interacting with OpenAI’s ChatGPT model directly within Vim. It allows you to submit prompts, request code snippets, engage in continuous conversations, and display responses either in the Quickfix List or full-screen buffers.

Prerequisites

	•	API Key: Set up an OpenAI API key in your environment as $OPENAI_API_KEY.
	•	Curl: This plugin relies on curl to send HTTP requests.

Installation

With Vim-Plug

If you use vim-plug, add this line to your .vimrc or init.vim:

Plug 'yourusername/vimgpt'

Then, install it by running:

```vim
:PlugInstall
```

Manual Installation

	1.	Clone this repository to your local machine.
	2.	Move the contents to your Vim/Neovim configuration directories:
	•	For Vim: ~/.vim/
	•	For Neovim: ~/.config/nvim/
	3.	Ensure doc/vimgpt.txt is in your doc/ directory, then generate help tags:

```vim
:helptags ~/.vim/doc
```

(For Neovim, run :helptags ~/.config/nvim/doc).

Usage

VimGPT provides several commands to interact with ChatGPT directly within Vim:

	•	:ChatGPT <prompt>
Sends a single prompt to ChatGPT and displays the response in the Quickfix List. Each use clears the conversation history.
	•	Example:

```vim
:ChatGPT "Explain recursion in simple terms"
```

	•	:ChatGPTCode <prompt>
Requests code from ChatGPT and displays only the code blocks in a new, full-screen buffer. Clears conversation history for each command.
	•	Example:

```vim
:ChatGPTCode "Show me a Python function to calculate factorial"
```

	•	:ChatGPTConversation <prompt>
Sends a prompt to ChatGPT, retaining conversation history to allow ongoing interaction with context.
	•	Example:

```vim
:ChatGPTConversation "Hello, who are you?"
:ChatGPTConversation "Can you tell me more about yourself?"
```

	•	:ChatGPTBuffer
Sends a custom prompt combined with selected text (or the entire buffer if no selection) as a single request. This command does not retain conversation history.
	•	Usage:
	•	Select text in visual mode, then :ChatGPTBuffer.
	•	If no text is selected, the entire buffer content is used.

Examples

Single Prompt

```vim
:ChatGPT "What is the difference between HTTP and HTTPS?"
```

Code-Only Response

```vim
:ChatGPTCode "Provide a JavaScript function to reverse a string"
```

Continuous Conversation

```vim
:ChatGPTConversation "Who are you?"
:ChatGPTConversation "Can you tell me more about your capabilities?"
```

Buffer with Custom Prompt

	1.	Select text in visual mode.
	2.	Run:

```vim
:ChatGPTBuffer
```

Or, if no text is selected, the entire buffer will be sent.

Troubleshooting

	•	No API Key: Ensure $OPENAI_API_KEY is set in your environment.
	•	Curl Dependency: Make sure curl is installed on your system.
	•	Clearing Buffers: Use :bwipeout if buffer conflicts occur.

License

This plugin is released under the MIT License. See the LICENSE file for details.
