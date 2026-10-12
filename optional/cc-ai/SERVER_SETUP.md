# cc-ai server setup

The `cc-ai` program on the turtle is only the chat client. It talks to a
Python Flask server you run on a real computer (your PC, a homelab box,
anything the Minecraft instance can reach). The server forwards messages
to OpenAI's API, so this costs money per OpenAI's pricing.

Upstream project: RareMojo/cc-ai (MIT). The client we ship is verbatim
from that repo, pinned at the commit in `version.txt`.

## 1. Get the server code

Clone RareMojo/cc-ai on the machine that will host the server:

```
git clone https://github.com/RareMojo/cc-ai.git
cd cc-ai
```

## 2. Install dependencies

Python 3, then:

```
pip install -r requirements.txt
```

The pinned set is: Flask 2.3.3, openai 0.27.9, Flask-Limiter,
charset-normalizer, click, colorama, Jinja2, MarkupSafe, Werkzeug,
certifi, idna, requests, urllib3, async-timeout, limits, ordered-set,
Deprecated, packaging, aiosignal, frozenlist, multidict, yarl, aiosignal.

## 3. Configure the .env file

Copy `example_.env` to `.env` and fill it in:

```
OPENAI_API_KEY=<your OpenAI API key>
API_TOKEN=<must match the token in cc-ai_config.txt on the turtle>
PORT=<port the server listens on, e.g. 5000>
MODEL_NAME="gpt-3.5-turbo"
TEMPERATURE=0.7
LOG_LEVEL="INFO"
```

- `OPENAI_API_KEY`: from OpenAI's website. This is what bills you.
- `API_TOKEN`: the Lua client generates its own token on first run and
  saves it in `cc-ai_config.txt` on the computer. Run the client once,
  type `/token` to see it, paste that value here.
- `PORT`: pick a non-default port.

## 4. Run it

```
python main.py
```

or use the bundled `start.sh` / `start.bat`.

## 5. Point the turtle at it

On the turtle, run `cc-ai`. First run walks you through setup. The key
value is the base URL, e.g. `http://192.168.1.50:5000`. Change it later
with `/settings`.

Requirements on the Minecraft side:

- `http.enabled = true` in the ComputerCraft / CC:Tweaked server
  config (default is true).
- The MC instance must be able to reach the server address (LAN,
  Tailscale/tailnet, or a public IP with the port open through the
  firewall).

## 6. System prompt

The file `preprompts/system` holds the hidden system prompt injected
before every response. `{AINAME}` in it is replaced with the AI's
configured name. Edit it to change the assistant's personality.

## Notes

- The server keeps per-computer conversation memory (last 3 messages,
  keyed by the computer's ID) and injects hidden context (in-game time,
  in-game day, uptime) into each request.
- `/clear` asks the server to wipe conversation memory.
- This is a chat toy, not a turtle driver: it cannot move turtles, read
  peripherals, or run programs.
