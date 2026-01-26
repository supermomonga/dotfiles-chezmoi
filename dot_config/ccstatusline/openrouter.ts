#!/usr/bin/env bun
/**
 * OpenRouter cost tracking statusline for Claude Code (Bun-compatible)
 *
 * Displays: Provider: model - $cost - cache discount: $saved
 *
 * Setup: Add to your ~/.claude/settings.json:
 * {
 *   "statusLine": {
 *     "type": "command",
 *     "command": "/path/to/openrouter.ts"
 *   }
 * }
 *
 * Requires: ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY set to your OpenRouter API key
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

interface StatuslineInput {
  session_id: string;
  transcript_path: string;
}

interface GenerationData {
  total_cost: number;
  cache_discount: number | null;
  provider_name: string;
  model: string;
}

interface State {
  seen_ids: string[];
  total_cost: number;
  total_cache_discount: number;
  last_provider: string;
  last_model: string;
}

async function fetchGeneration(id: string, apiKey: string): Promise<GenerationData | null> {
  try {
    const res = await fetch(`https://openrouter.ai/api/v1/generation?id=${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });

    if (!res.ok) return null;

    const json = (await res.json()) as any;
    const data = json?.data;

    if (!data || typeof data.total_cost !== "number") return null;

    return data as GenerationData;
  } catch {
    return null;
  }
}

interface CreditData {
  total_credits: number;
  total_usage: number;
}

async function fetchCredit(apiKey: string): Promise<CreditData | null> {
  try {
    const res = await fetch(`https://openrouter.ai/api/v1/credits`, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });

    if (!res.ok) return null;

    const json = (await res.json()) as any;
    const data = json?.data;
    if (!data) return null;

    return data as CreditData;
  } catch {
    return null;
  }
}

function extractGenerationIds(transcriptPath: string): string[] {
  try {
    const content = readFileSync(transcriptPath, "utf-8");
    const ids: string[] = [];

    for (const line of content.split("\n")) {
      if (!line.trim()) continue;

      try {
        const entry = JSON.parse(line);
        const messageId = entry?.message?.id;
        if (typeof messageId === "string" && messageId.startsWith("gen-")) {
          ids.push(messageId);
        }
      } catch {
        // skip malformed lines
      }
    }

    return [...new Set(ids)];
  } catch {
    return [];
  }
}

function loadState(statePath: string): State {
  const defaultState: State = {
    seen_ids: [],
    total_cost: 0,
    total_cache_discount: 0,
    last_provider: "",
    last_model: "",
  };

  if (!existsSync(statePath)) return defaultState;

  try {
    const content = readFileSync(statePath, "utf-8");
    if (!content.trim()) return defaultState;

    const parsed = JSON.parse(content);

    if (!Array.isArray(parsed.seen_ids)) return defaultState;

    return {
      seen_ids: parsed.seen_ids,
      total_cost: typeof parsed.total_cost === "number" ? parsed.total_cost : 0,
      total_cache_discount:
        typeof parsed.total_cache_discount === "number" ? parsed.total_cache_discount : 0,
      last_provider: typeof parsed.last_provider === "string" ? parsed.last_provider : "",
      last_model: typeof parsed.last_model === "string" ? parsed.last_model : "",
    };
  } catch {
    return defaultState;
  }
}

function saveState(statePath: string, state: State): void {
  writeFileSync(statePath, JSON.stringify(state, null, 2));
}

function shortModelName(model: string): string {
  return model.replace(/^[^/]+\//, "").replace(/-\d{8}$/, "");
}

async function readStdinText(): Promise<string> {
  // Bun: Response can wrap Node streams
  return await new Response(process.stdin as any).text();
}

async function main(): Promise<void> {
  const apiKey = process.env.ANTHROPIC_AUTH_TOKEN ?? process.env.ANTHROPIC_API_KEY ?? "";

  if (!apiKey) {
    process.stdout.write("Set ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY to use the OpenRouter statusline");
    return;
  }

  let input: StatuslineInput;
  try {
    const inputText = await readStdinText();
    input = JSON.parse(inputText);
  } catch {
    process.stdout.write("Invalid statusline input");
    return;
  }

  const session_id = input?.session_id;
  const transcript_path = input?.transcript_path;

  if (typeof session_id !== "string" || typeof transcript_path !== "string") {
    process.stdout.write("Invalid statusline input");
    return;
  }

  const statePath = join(tmpdir(), `claude-openrouter-cost-${session_id}.json`);
  const state = loadState(statePath);

  const allIds = extractGenerationIds(transcript_path);
  const seenSet = new Set(state.seen_ids);
  const newIds = allIds.filter((id) => !seenSet.has(id));

  let fetchFailed = 0;

  for (const id of newIds) {
    const gen = await fetchGeneration(id, apiKey);

    if (!gen) {
      fetchFailed++;
      continue;
    }

    state.total_cost += gen.total_cost ?? 0;
    state.total_cache_discount += gen.cache_discount ?? 0;

    if (gen.provider_name) state.last_provider = gen.provider_name;
    if (gen.model) state.last_model = gen.model;

    state.seen_ids.push(id);
  }

  saveState(statePath, state);

  const shortModel = shortModelName(state.last_model);
  let statusIndicator = "";

  if (newIds.length > 0) {
    const green = "\x1b[32m";
    const red = "\x1b[31m";
    const reset = "\x1b[0m";
    statusIndicator = fetchFailed === 0 ? ` ${green}✅️${reset}` : ` ${red}🔄${reset}`;
  }

  const credit = await fetchCredit(apiKey);
  const remain_credits =
    credit && typeof credit.total_credits === "number" && typeof credit.total_usage === "number"
      ? credit.total_credits - credit.total_usage
      : NaN;

  const creditsText = Number.isFinite(remain_credits) ? `$${remain_credits.toFixed(2)}` : "N/A";

  if (state.last_provider) {
    process.stdout.write(
      `${shortModel}(${state.last_provider}) | $${state.total_cost.toFixed(4)}(-$${state.total_cache_discount.toFixed(
        2,
      )}) | Credits: ${creditsText}${statusIndicator}`,
    );
  } else {
    process.stdout.write(
      `$${state.total_cost.toFixed(4)}(-$${state.total_cache_discount.toFixed(2)}) | Credits: ${creditsText}${statusIndicator}`,
    );
  }
}

main().catch((err: any) => {
  process.stdout.write(`error: ${err?.message ?? String(err)}`);
});

