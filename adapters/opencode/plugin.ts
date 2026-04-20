// Jesus Loop — opencode adapter (mustard seed).
//
// opencode plugins are JS/TS modules, not shell hooks. We bridge to the
// shared bash core (core/loop.sh) by spawning it from the plugin handler.
//
// Stop-equivalent strategy:
//   • If `session.stopping` exists (PR #16598 once merged) → use it; set
//     output.stop = false, output.message = <prompt from core>.
//   • Else fall back to `event` listener for `session.idle`, then call
//     client.session.prompt({ path:{id:sessionID}, body:{ parts:[{type:"text", text:<prompt>}] } }).
//
// The state file lives at .opencode/jesus-loop.<session>.local.md so multiple
// concurrent loops can run side-by-side.
import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { join } from "node:path"

export const JesusLoopPlugin = async ({ project, directory, client }: any) => {
  const pluginRoot = process.env.JL_PLUGIN_ROOT
    ?? join(directory, ".opencode", "jesus-loop")
  const stateDir = join(directory, ".opencode")
  const session = process.env.JL_SESSION ?? "default"

  const runCore = (transcriptPath?: string): { prompt: string; sysmsg: string } | null => {
    const stateFile = join(stateDir, `jesus-loop.${session}.local.md`)
    if (!existsSync(stateFile)) return null
    const r = spawnSync("bash", [join(pluginRoot, "core/loop.sh")], {
      input: JSON.stringify({ transcript_path: transcriptPath ?? "" }),
      env: {
        ...process.env,
        JL_PLUGIN_ROOT: pluginRoot,
        JL_STATE_DIR: stateDir,
        JL_SESSION: session,
        JL_OUTPUT_FORMAT: "raw",
        JL_SYSMSG_FD: "3",
      },
      stdio: ["pipe", "pipe", "inherit", "pipe"],
    })
    if (r.status !== 0) return null
    const prompt = (r.stdout ?? Buffer.alloc(0)).toString("utf8").trim()
    const sysmsg = ((r.output?.[3] as Buffer | undefined) ?? Buffer.alloc(0)).toString("utf8").trim()
    return { prompt, sysmsg }
  }

  const handler: any = {
    // Preferred path once PR #16598 lands.
    "session.stopping": async (input: any, output: any) => {
      const out = runCore(input?.transcriptPath)
      if (!out) return
      output.stop = false
      output.message = out.prompt
    },
    // Fallback: re-prompt on session.idle (works in TUI; visible user turn).
    event: async ({ event }: any) => {
      if (event?.type !== "session.idle") return
      const out = runCore()
      if (!out) return
      const sessionID = event?.properties?.sessionID
      if (!sessionID) return
      await client.session.prompt({
        path: { id: sessionID },
        body: { parts: [{ type: "text", text: out.prompt }] },
      })
    },
  }

  return handler
}

export default JesusLoopPlugin
