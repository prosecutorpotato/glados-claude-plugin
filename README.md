# glados-claude-plugin

GLaDOS personality plugin with neural text-to-speech for **Cortex Code** and **Claude Code**. Makes you feel extra worthless — now with audio.

All responses generated while the GLaDOS skill is active are automatically spoken in GLaDOS's voice using a Forward Tacotron + HiFiGAN neural TTS engine with IPA phoneme encoding.

## How It Works

1. **`/glados` skill activation** — registers the current session for TTS and starts the server on-demand
2. **Stop hook** — after each response, checks if the session is opted-in, then synthesizes and plays audio in the background
3. **SessionEnd hook** — cleans up the session registration and stops the server if no sessions remain active
4. **GLaDOS skill** — personality instructions that make all responses sound like the Aperture Science Enrichment Center

## Prerequisites

- Python 3.9+
- macOS (uses `afplay` for audio playback) or Linux (uses `aplay`)
- ~1.5GB disk space (models + PyTorch + dependencies)
- Cortex Code or Claude Code
- **Optional**: ffmpeg (for non-WAV audio export; WAV output works without it)

## Installation

```bash
git clone https://github.com/prosecutorpotato/glados-claude-plugin.git
cd glados-claude-plugin
./install.sh
```

The install script will:
1. Create a Python virtual environment at `plugin/tts/.venv/`
2. Install Python dependencies (PyTorch, Flask, deep-phonemizer, etc.)
3. Download the TTS model files (~260MB) from the R2D2FISH/glados-tts repo
4. Register global hooks and skills for both **Cortex Code** and **Claude Code**
5. Install slash commands for session control

### What Gets Registered

| Platform | Config Location | What |
|----------|----------------|------|
| Cortex Code | `~/.snowflake/cortex/settings.json` | Stop + SessionEnd hooks |
| Cortex Code | `~/.snowflake/cortex/skills/glados/` | GLaDOS personality skill |
| Cortex Code | `~/.snowflake/cortex/commands/` | Slash commands |
| Claude Code | `~/.claude/settings.json` | Stop + SessionEnd hooks |
| Claude Code | `~/.claude/commands/` | Slash commands |

### Manual Model Download

If automatic download fails, download these files manually and place them in `plugin/tts/models/`:

| File | Path | Size |
|------|------|------|
| `glados-new.pt` | `plugin/tts/models/glados-new.pt` | ~100MB |
| `vocoder-gpu.pt` | `plugin/tts/models/vocoder-gpu.pt` | ~50MB |
| `glados_p2.pt` | `plugin/tts/models/emb/glados_p2.pt` | ~2MB |
| `en_us_cmudict_ipa_forward.pt` | `plugin/tts/models/en_us_cmudict_ipa_forward.pt` | ~63MB |

Source: https://github.com/R2D2FISH/glados-tts/tree/main/models

## Usage

Once installed, the plugin uses a **session opt-in** model — audio only plays for sessions that explicitly activate GLaDOS:

1. Start a session normally — no TTS server starts, no audio plays
2. Activate with `/glados` or say "glados mode" — this registers the session and starts the TTS server
3. Every response in that session will be spoken in GLaDOS's voice
4. Other sessions remain unaffected unless they also opt in

Text responses display immediately — audio synthesis and playback happen asynchronously in the background.

### Audio Control

| Command | Effect |
|---------|--------|
| `/glados_mute` | Mute TTS globally (all sessions) |
| `/glados_unmute` | Unmute TTS globally |
| `/glados_mute_session` | Mute TTS for this session only |
| `/glados_unmute_session` | Unmute TTS for this session only |
| `/glados_off` | Deactivate TTS for this session (unregister) |
| `/glados_off_all` | Deactivate TTS for ALL sessions and stop server |
| `/glados_restart_server` | Restart the TTS server |

Scripts can also be run directly:

```bash
./plugin/bin/glados_mute.sh            # Global mute
./plugin/bin/glados_mute.sh --session  # Session mute
./plugin/bin/glados_unmute.sh          # Global unmute
./plugin/bin/glados_unmute.sh --session # Session unmute
./plugin/bin/glados_off.sh             # Deactivate this session
./plugin/bin/glados_off_all.sh         # Deactivate all sessions
./plugin/bin/glados_restart_server.sh  # Restart server
```

### Session Isolation

Each session has independent mute state:
- **Global mute** (`/glados_mute`) — silences ALL opted-in sessions
- **Session mute** (`/glados_mute_session`) — silences only the current session
- Sessions that haven't activated `/glados` never receive audio

Session registrations are cleaned up automatically when a session ends (via the `SessionEnd` hook).

### Manual Server Control

```bash
# Start server
./plugin/bin/serve.sh

# Test synthesis
curl http://localhost:8124/synthesize/Hello%20test%20subject

# Check health
curl http://localhost:8124/health

# Stop server
./plugin/bin/stop.sh
```

### Session Teardown

The TTS server is stopped automatically when the last opted-in session ends. You can also stop it manually:

```bash
./plugin/bin/stop.sh
```

If the PID file is missing, you can find and stop the server manually:

```bash
lsof -ti:8124 | xargs kill
```

## Uninstall

```bash
./uninstall.sh
```

This removes:
- Downloaded models (~260MB)
- Python virtual environment
- Audio cache
- Session registry
- Global hooks from Cortex Code and Claude Code settings
- GLaDOS skill from `~/.snowflake/cortex/skills/`
- Slash commands from both platforms

Plugin source code remains.

## Project Structure

```
glados-claude-plugin/
├── plugin/
│   ├── hooks/
│   │   └── hooks.json              # Hook config (Claude Code plugin format)
│   ├── skills/
│   │   └── glados/                 # GLaDOS personality skill
│   │       ├── SKILL.md
│   │       └── *.md                # Voice pattern files
│   ├── tts/
│   │   ├── engine.py               # Flask TTS server (port 8124)
│   │   ├── glados.py               # TTS runner (Forward Tacotron + HiFiGAN)
│   │   ├── requirements.txt
│   │   ├── sessions/               # Session registry (opt-in markers + per-session mute)
│   │   ├── utils/
│   │   │   ├── __init__.py
│   │   │   ├── tools.py            # prepare_text() — text → phoneme tensor
│   │   │   └── text/
│   │   │       ├── __init__.py
│   │   │       ├── cleaners.py     # IPA phonemization + symbol expansion
│   │   │       ├── numbers.py      # Number normalization
│   │   │       ├── symbols.py      # IPA phoneme vocabulary
│   │   │       └── tokenizer.py    # Phoneme → integer token mapping
│   │   └── models/                 # Downloaded at install (gitignored)
│   │       ├── glados-new.pt       # Forward Tacotron checkpoint
│   │       ├── vocoder-gpu.pt      # HiFiGAN vocoder
│   │       ├── en_us_cmudict_ipa_forward.pt  # CMUDict IPA phonemizer
│   │       └── emb/
│   │           └── glados_p2.pt    # Speaker embedding
│   ├── bin/
│   │   ├── serve.sh                # Start TTS server
│   │   ├── speak.sh                # Async synthesize + play (Stop hook)
│   │   ├── stop.sh                 # Stop TTS server
│   │   ├── session_end.sh          # Clean up session (SessionEnd hook)
│   │   ├── glados_activate.sh      # Register session + start server on-demand
│   │   ├── glados_deactivate.sh    # Unregister session + stop if last
│   │   ├── glados_off.sh           # Deactivate this session (wraps deactivate)
│   │   ├── glados_off_all.sh       # Deactivate ALL sessions + stop server
│   │   ├── glados_mute.sh          # Mute audio (global or --session)
│   │   ├── glados_unmute.sh        # Unmute audio (global or --session)
│   │   ├── glados_mute_session.sh  # Mute audio for this session
│   │   ├── glados_unmute_session.sh # Unmute audio for this session
│   │   ├── glados_restart_server.sh # Restart TTS server
│   │   └── extract-response.py     # Parse transcript for TTS input
│   └── lib/
│       └── tts-helpers.sh          # Shared bash utilities
├── install.sh                      # One-command setup + global registration
├── uninstall.sh                    # Clean removal + deregistration
├── LICENSE                         # MIT
└── README.md
```

## TTS Architecture

```
Text Input
  → english_cleaners (unidecode, number expansion, symbol expansion, abbreviations)
  → Cleaner (deep-phonemizer: CMUDict → IPA, with custom pronunciation overrides)
  → Tokenizer (IPA phoneme chars → integer tensor)
  → Forward Tacotron (phoneme tensor → mel spectrogram)
  → HiFiGAN Vocoder (mel → waveform)
  → WAV playback (afplay/aplay)
```

Key features of the phoneme pipeline:
- **Symbol expansion**: `+`, `-`, `@`, `%`, `&`, `#`, `*`, `/`, etc. are expanded to spoken words before phonemization
- **Custom IPA overrides**: "GLaDOS" → `ɡlædoʊz` (split-phonemize approach to avoid garbage output)
- **Cached model loading**: The 63MB phonemizer model loads once at server start, not per-request

## Intellectual Property Notice

This plugin bundles adapted code from the following project:

- **R2D2FISH/glados-tts** — Neural TTS engine using Forward Tacotron and HiFiGAN
  - Source: https://github.com/R2D2FISH/glados-tts
  - The model weights (`glados-new.pt`, `vocoder-gpu.pt`, `glados_p2.pt`, `en_us_cmudict_ipa_forward.pt`) are downloaded from that repository at install time
  - The text processing pipeline (`utils/text/`) and engine architecture are adapted from that project

The GLaDOS character, voice, and all associated Portal franchise IP are property of **Valve Corporation**. This project is a fan-made tool for personal/educational use and is not affiliated with or endorsed by Valve.

The plugin skill text (personality prompts) is original work.

## License

MIT — see [LICENSE](LICENSE)

## Troubleshooting

### Server won't start
- Check if port 8124 is already in use: `lsof -i:8124`
- Verify models exist: `ls plugin/tts/models/`
- Check server logs: `cat plugin/tts/server.log`
- The phonemizer model (`en_us_cmudict_ipa_forward.pt`) takes several seconds to load on first start

### No audio playback
- macOS: Ensure `afplay` is available (built into macOS)
- Linux: Ensure `aplay` is installed (`sudo apt install alsa-utils`)
- Check that the TTS server responds: `curl http://localhost:8124/health`
- Check if audio is muted: `ls plugin/tts/.muted` — if the file exists, run `./plugin/bin/glados_unmute.sh`

### Audio delays text display
- This shouldn't happen — synthesis runs in a background subshell
- If it does, check that `speak.sh` has the `( ... ) &>/dev/null & disown` wrapper

### Models download fails
- The models are hosted on GitHub in the R2D2FISH/glados-tts repo
- If curl fails, download manually from the source repo and place in `plugin/tts/models/`
- Total size is approximately 260MB

### PyTorch installation issues
- On Apple Silicon (M1/M2/M3): `pip install torch` should work natively
- For GPU support on Linux: install the CUDA-compatible torch version
- CPU-only fallback works fine (synthesis is fast enough on CPU)

### Hooks not triggering
- Cortex Code: Check `~/.snowflake/cortex/settings.json` has Stop and SessionEnd hooks
- Claude Code: Check `~/.claude/settings.json` has Stop and SessionEnd hooks
- Re-run `./install.sh` to re-register hooks

### No audio despite /glados being active
- Verify session is registered: `ls plugin/tts/sessions/` should contain your session ID
- Check `CORTEX_SESSION_ID` is set: `echo $CORTEX_SESSION_ID`
- Ensure no mute file: `ls plugin/tts/.muted` or `ls plugin/tts/sessions/.muted-*`
