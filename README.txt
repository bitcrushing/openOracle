============================================
  CLAUDE FOR OPENCOMPUTERS
  A Claude AI Assistant for Minecraft
============================================

REQUIREMENTS
------------
- OpenComputers computer with:
  - Internet Card
  - Data Card (Tier 3 required for TLS 1.3 ECDH key exchange)
  - Screen and Keyboard
  - Sufficient memory (Tier 2+ recommended)
- libtls13 library (install via: oppm install libtls13)
- Anthropic API key (get one at console.anthropic.com)

INSTALLATION
------------
Method 1: Using the installer
  1. Copy all files to a floppy disk or hard drive
  2. Insert into your OpenComputers computer
  3. Navigate to the directory with the files
  4. Run: install

Method 2: Manual installation
  1. Copy these files to /usr/lib/:
     - json.lua
     - config.lua
     - claude_api.lua
     - ui.lua
  2. Copy claude.lua to /usr/bin/claude (remove .lua extension)

USAGE
-----
First-time setup:
  claude --setup

Start chatting:
  claude

Start with a message:
  claude "Hello Claude!"

COMMANDS
--------
/help     - Show help information
/clear    - Clear conversation history
/setup    - Reconfigure API settings
/save     - Save conversation to file
/load     - Load conversation from file
/history  - Show conversation summary
/exit     - Exit Claude Code

CONFIGURATION
-------------
Settings are stored in /etc/claude.cfg

You can configure:
- API key (required)
- Model (default: claude-sonnet-4-20250514)
- Max tokens (default: 4096)

FILES
-----
/usr/lib/json.lua       - JSON encoder/decoder
/usr/lib/config.lua     - Configuration handler
/usr/lib/claude_api.lua - Claude API client
/usr/lib/ui.lua         - Terminal UI utilities
/usr/bin/claude         - Main program
/etc/claude.cfg         - Configuration file

TIPS
----
- Screen space is limited, so Claude will keep responses concise
- Conversations are kept in memory until you /clear or exit
- Use /save to preserve important conversations
- Press Ctrl+C to interrupt if Claude takes too long
- TLS handshakes may take a few seconds on first connection

TROUBLESHOOTING
---------------
"No internet card found"
  -> Install an Internet Card in your computer

"No data card found"
  -> Install a Tier 3 Data Card (required for TLS cryptography)

"TLS handshake failed: unable to negotiate security parameters"
  -> Ensure you have a Tier 3 Data Card installed
  -> Verify libtls13 is installed: oppm install libtls13

"API key not configured"
  -> Run 'claude --setup' to enter your API key

"Connection timeout"
  -> Check your Minecraft server has internet access
  -> Ensure the Internet Card is properly connected

"API error 401"
  -> Your API key is invalid, run --setup again

"API error 404"
  -> Invalid model name, run --setup and use a valid model ID
  -> Valid models: claude-sonnet-4-5-20250514, claude-sonnet-4-20250514

"API error 429"
  -> Rate limited, wait a moment and try again

LICENSE
-------
This software is provided as-is for personal use.
Claude is a product of Anthropic.

============================================
  Enjoy chatting with Claude in Minecraft!
============================================
