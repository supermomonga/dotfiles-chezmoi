#!/usr/bin/env bun
/**
 * Usage monitor dispatcher for Claude Code statusline
 *
 * Detects the current LLM provider from ANTHROPIC_BASE_URL and
 * dispatches to the appropriate statusline script:
 *   - openrouter.ai  → openrouter.ts
 *   - api.z.ai       → glm.ts
 */

async function readStdinText(): Promise<string> {
  return await new Response(process.stdin as any).text();
}

async function main(): Promise<void> {
  const baseUrl = process.env.ANTHROPIC_BASE_URL ?? "";

  let scriptPath: string;

  if (baseUrl) {
    let hostname: string;
    try {
      hostname = new URL(baseUrl).hostname;
    } catch {
      process.exit(0);
    }

    if (hostname === "openrouter.ai") {
      scriptPath = `${import.meta.dir}/openrouter.ts`;
    } else if (hostname === "api.z.ai") {
      scriptPath = `${import.meta.dir}/glm.ts`;
    } else {
      // Unknown provider — output nothing
      process.exit(0);
    }
  } else {
    // No base URL set — output nothing
    process.exit(0);
  }

  const stdinText = await readStdinText();

  const proc = Bun.spawn(["bun", scriptPath], {
    stdin: Buffer.from(stdinText),
    stdout: "pipe",
    stderr: "inherit",
  });

  const output = await new Response(proc.stdout).text();
  process.stdout.write(output);
}

main().catch((err: any) => {
  process.stdout.write(`error: ${err?.message ?? String(err)}`);
});
