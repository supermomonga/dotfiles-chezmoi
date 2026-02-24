@echo off
set ANTHROPIC_BASE_URL=https://openrouter.ai/api
set ANTHROPIC_AUTH_TOKEN=%OPENROUTER_API_KEY%
set ANTHROPIC_API_KEY=
set API_TIMEOUT_MS=3000000

(for %%a in (%*) do if "%%a"=="--team-name" set CLAUDE_CODE_IS_TEAMMATE=1) 2>nul

claude %*
