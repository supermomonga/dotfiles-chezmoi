#!/usr/bin/env bun
/**
 * Z.ai (GLM) usage tracking statusline for Claude Code (Bun-compatible)
 *
 * Output example:
 *   5H: [███████░░░░░░░░] 12% (2.3h) | 1W: [███████░░░░░░░░] 3% (168.3h)
 *
 * Requires: ANTHROPIC_AUTH_TOKEN set to your Z.ai API key
 *           ANTHROPIC_BASE_URL set to https://api.z.ai/...
 */

interface StatuslineInput {
  session_id: string;
  transcript_path: string;
}

interface TokensLimitItem {
  type: "TOKENS_LIMIT";
  unit: number;
  number: number;
  percentage: number;
  nextResetTime: number;
}

interface QuotaLimitData {
  limits?: Array<{ type: string; [key: string]: unknown }>;
}

// unit=3 → hours, unit=6 → weeks (based on observed API values)
function getLabel(unit: number, num: number): string | null {
  if (unit === 3) return `${num}H`;
  if (unit === 6) return num === 1 ? "1W" : `${num}W`;
  return null;
}

function progressBar(percentage: number, width = 10): string {
  const filled = Math.min(width, Math.round((percentage / 100) * width));
  return `[${"█".repeat(filled)}${"░".repeat(width - filled)}]`;
}

function hoursUntil(unixMs: number): string {
  const h = (unixMs - Date.now()) / 3_600_000;
  return h > 0 ? `${h.toFixed(1)}h` : "0.0h";
}

async function fetchQuotaLimit(baseUrl: string, authToken: string): Promise<QuotaLimitData | null> {
  try {
    const { protocol, host } = new URL(baseUrl);
    const url = `${protocol}//${host}/api/monitor/usage/quota/limit`;
    const res = await fetch(url, {
      headers: {
        Authorization: authToken,
        "Accept-Language": "en-US,en",
        "Content-Type": "application/json",
      },
    });
    if (!res.ok) return null;
    const json = (await res.json()) as any;
    return (json?.data ?? json) as QuotaLimitData;
  } catch {
    return null;
  }
}

async function main(): Promise<void> {
  const authToken = process.env.ANTHROPIC_AUTH_TOKEN ?? process.env.ANTHROPIC_API_KEY ?? "";
  const baseUrl = process.env.ANTHROPIC_BASE_URL ?? "";

  if (!authToken || !baseUrl) {
    process.stdout.write("Z.ai: no credentials");
    return;
  }

  // consume stdin (required by ccstatusline protocol)
  await new Response(process.stdin as any).text();

  const quota = await fetchQuotaLimit(baseUrl, authToken);

  if (!quota || !Array.isArray(quota.limits)) {
    process.stdout.write("Z.ai: N/A");
    return;
  }

  const parts: string[] = [];

  for (const raw of quota.limits) {
    if (raw.type !== "TOKENS_LIMIT") continue;
    const item = raw as unknown as TokensLimitItem;
    const label = getLabel(item.unit, item.number);
    if (!label) continue;

    const pct = item.percentage ?? 0;
    const bar = progressBar(pct);
    const remaining = hoursUntil(item.nextResetTime);
    parts.push(`${label}: ${bar} ${pct}% (${remaining})`);
  }

  process.stdout.write(parts.length > 0 ? parts.join(" | ") : "Z.ai: N/A");
}

main().catch((err: any) => {
  process.stdout.write(`Z.ai error: ${err?.message ?? String(err)}`);
});
