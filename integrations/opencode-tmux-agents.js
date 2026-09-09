// OpenCode event bridge for tmux-agents.
// Install through scripts/install-opencode.sh, then restart OpenCode.
import { fileURLToPath } from "node:url"
import { dirname } from "node:path"

export const TmuxAgents = async ({ $ }) => {
  const pane = process.env.TMUX_PANE
  const moduleDir = dirname(dirname(fileURLToPath(import.meta.url)))
  const dir = moduleDir
  const updater = `${dir}/scripts/update-state.sh`
  const sessions = new Map()
  const pending = new Map()
  const owner = `opencode-${process.pid}-${Math.random().toString(36).slice(2)}`
  let last = ""
  let claimed = false
  let queue = Promise.resolve()

  const rank = { active: 0, idle: 1, working: 2, error: 3, waiting: 4 }

  const publishNow = async (next) => {
    if (!pane || (next === last && claimed)) return
    const action = claimed ? "update" : "claim"
    try {
      if (next === "off") {
        await $`bash ${updater} --action clear --pane ${pane} --owner ${owner}`
      } else {
        await $`bash ${updater} --action ${action} --pane ${pane} --owner ${owner} --state ${next} --pid ${process.pid} --agent opencode`
        claimed = true
      }
      last = next
    } catch {
      if (action === "claim") claimed = false
      // tmux may disappear while OpenCode is shutting down.
    }
  }

  const publish = (next) => {
    queue = queue.then(() => publishNow(next), () => publishNow(next))
    return queue
  }

  const aggregate = () => {
    let best = "active"
    for (const [sessionID, state] of sessions) {
      const effective = (pending.get(sessionID) || 0) > 0 ? "waiting" : state
      if ((rank[effective] || 0) > (rank[best] || 0)) best = effective
    }
    return best
  }

  const setSession = async (sessionID, state) => {
    if (!sessionID) return
    sessions.set(sessionID, state)
    await publish(aggregate())
  }

  const eventSession = (event) => {
    const properties = event.properties || {}
    return properties.sessionID || (properties.info && properties.info.id)
  }

  void publish("active")
  return {
    event: async ({ event }) => {
      const sessionID = eventSession(event)
      switch (event.type) {
        case "session.status":
          if (event.properties.status.type === "busy" || event.properties.status.type === "retry") {
            await setSession(sessionID, "working")
          } else if (event.properties.status.type === "error") {
            await setSession(sessionID, "error")
          } else {
            await setSession(sessionID, "idle")
          }
          break
        case "session.idle":
          await setSession(sessionID, "idle")
          break
        case "session.error":
          await setSession(sessionID, "error")
          break
        case "permission.asked":
        case "permission.v2.asked":
        case "question.asked":
        case "question.v2.asked":
          pending.set(sessionID, (pending.get(sessionID) || 0) + 1)
          await setSession(sessionID, "waiting")
          break
        case "permission.replied":
        case "permission.v2.replied":
        case "question.replied":
        case "question.v2.replied":
        case "question.rejected":
        case "question.v2.rejected":
          pending.set(sessionID, Math.max(0, (pending.get(sessionID) || 0) - 1))
          await setSession(sessionID, "working")
          break
        case "session.deleted":
          sessions.delete(sessionID)
          pending.delete(sessionID)
          await publish(aggregate())
          break
        default:
          break
      }
    },
    dispose: async () => publish("off"),
  }
}

export default TmuxAgents
