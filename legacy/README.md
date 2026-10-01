# legacy/ — deprecated installers (kept for credit, DO NOT USE on 4GB)

These are the original pre-9i scripts. They pull proot-Ubuntu and/or full
`.[all]` extras or local Ollama models that OOM or fill disk on Realme 9i 4/64GB.

- `agent_install.sh`, `proot_install.sh`, `nous_agent.sh` — proot-Ubuntu path (~2GB+, double Python).
- `hermes_install.sh`, `install.sh` — early native attempts, missing psutil patch / router / Sizuku bridge.
- `nous_hermes_agent_install.sh` — most complete legacy, but installs `.[all]` (too heavy).

Canonical now: `../hermes-9i-install.sh` + `../SETUP.md`.
Origin: https://github.com/AbuZar-Ansarii/Hermes-Agent-On-Android
Upstream agent: https://github.com/NousResearch/hermes-agent
