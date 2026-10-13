import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { realpathSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname } from "node:path"

const execFileAsync = promisify(execFile)

export default {
  id: "tmux-agents",
  setup(context) {
    const pane = process.env.TMUX_PANE
    const repo = dirname(dirname(dirname(realpathSync(fileURLToPath(import.meta.url)))))
    const updater = `${repo}/scripts/update-state.sh`
    const sessions = new Map()
    const pendingPermissions = new Map()
    const pendingForms = new Map()
    const pendingInbox = new Map()
    const formOwners = new Map()
    const location = context.location ?? context.data.location.default()
    const owner = `opencode-${process.pid}-${Math.random().toString(36).slice(2)}`
    let last = ""
    let claimed = false
    let queue = Promise.resolve()
    const currentSession = () => {
      const route = context.ui?.router.current()
      return route?.type === "session" ? route.sessionID : undefined
    }
    let trackedSessionID = currentSession()

    const rank = { active: 0, idle: 1, working: 2, pending: 3, error: 4, waiting: 5 }
    const publishNow = async (next) => {
      if (!pane || (next === last && claimed)) return
      const action = claimed ? "update" : "claim"
      try {
        if (next === "off") {
          await execFileAsync("bash", [updater, "--action", "clear", "--pane", pane, "--owner", owner])
          claimed = false
        } else {
          await execFileAsync("bash", [
            updater,
            "--action", action,
            "--pane", pane,
            "--owner", owner,
            "--state", next,
            "--pid", String(process.pid),
            "--agent", "opencode",
          ])
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
        const waiting = (pendingPermissions.get(sessionID) || 0) + (pendingForms.get(sessionID) || 0)
        const queued = pendingInbox.get(sessionID) || 0
        const effective = waiting > 0 ? "waiting" : queued > 0 ? "pending" : state
        if ((rank[effective] || 0) > (rank[best] || 0)) best = effective
      }
      return best
    }
    const setSession = async (sessionID, state) => {
      if (!sessionID) return
      sessions.set(sessionID, state)
      await publish(aggregate())
    }
    const refreshPending = async (sessionID) => {
      if (!sessionID) return
      try {
        await Promise.all([
          context.data.session.permission.sync(sessionID),
          context.data.session.form.sync(sessionID, location),
          context.data.session.pending.sync(sessionID),
        ])
        pendingPermissions.set(sessionID, (context.data.session.permission.list(sessionID) ?? []).length)
        const forms = context.data.session.form.list(sessionID, location) ?? []
        for (const [formID, ownerSessionID] of formOwners) {
          if (ownerSessionID === sessionID) formOwners.delete(formID)
        }
        for (const form of forms) formOwners.set(form.id, sessionID)
        pendingForms.set(sessionID, forms.length)
        pendingInbox.set(sessionID, (context.data.session.pending.list(sessionID) ?? []).length)
        await publish(aggregate())
      } catch {
        // Keep event-derived state if cache synchronization is unavailable.
      }
    }
    const sessionState = (status) => {
      const type = typeof status === "string" ? status : status?.type
      if (type === "idle") return "idle"
      if (type === "error") return "error"
      return "working"
    }
    const activeSessionID = () => {
      const current = currentSession()
      if (current !== trackedSessionID) {
        sessions.clear()
        pendingPermissions.clear()
        pendingForms.clear()
        pendingInbox.clear()
        formOwners.clear()
        trackedSessionID = current
        void publish(aggregate())
      }
      return current
    }
    const handleEvent = (details) => {
      const type = details?.type
      const data = details?.data ?? details?.properties ?? details
      let id = data?.sessionID ?? data?.form?.sessionID
      if (type === "form.replied" || type === "form.cancelled") {
        id ??= formOwners.get(data?.id)
      }
      if (!type) return
      const active = activeSessionID()
      if (!id || id !== active) return

      if (type === "session.status") {
        void setSession(id, sessionState(data.status))
      } else if (type === "session.execution.started" || type === "session.step.started") {
        void setSession(id, "working")
      } else if (
        type === "session.execution.succeeded" ||
        type === "session.execution.interrupted" ||
        type === "session.idle"
      ) {
        void setSession(id, "idle")
      } else if (type === "session.execution.failed" || type === "session.step.failed" || type === "session.error") {
        void setSession(id, "error")
      } else if (type === "permission.asked" || type === "question.asked") {
        pendingPermissions.set(id, (pendingPermissions.get(id) || 0) + 1)
        void setSession(id, "waiting")
        void refreshPending(id)
      } else if (
        type === "permission.replied" ||
        type === "question.replied" ||
        type === "question.rejected"
      ) {
        pendingPermissions.set(id, Math.max(0, (pendingPermissions.get(id) || 0) - 1))
        void setSession(id, "working")
        void refreshPending(id)
      } else if (type === "form.created") {
        if (data.form?.id) formOwners.set(data.form.id, id)
        pendingForms.set(id, (pendingForms.get(id) || 0) + 1)
        void setSession(id, "waiting")
        void refreshPending(id)
      } else if (type === "form.replied" || type === "form.cancelled") {
        formOwners.delete(data.id)
        pendingForms.set(id, Math.max(0, (pendingForms.get(id) || 0) - 1))
        void setSession(id, "working")
        void refreshPending(id)
      } else if (type.includes("form") || type.includes("inbox")) {
        void refreshPending(id)
      } else if (type === "session.deleted") {
        sessions.delete(id)
        pendingPermissions.delete(id)
        pendingForms.delete(id)
        pendingInbox.delete(id)
        for (const [formID, ownerSessionID] of formOwners) {
          if (ownerSessionID === id) formOwners.delete(formID)
        }
        void publish(aggregate())
      }
    }
    const unsubscribe = context.data.listen(({ details }) => handleEvent(details))

    const hydrate = async () => {
      const active = activeSessionID()
      if (!active) return
      const existing = context.data.session.list() ?? []
      await Promise.all(existing.map(async (session) => {
        const id = session.id ?? session.sessionID
        if (!id || id !== active) return
        try {
          await context.data.session.sync(id)
        } catch {
          // Continue with whatever state is already cached.
        }
        const status = context.data.session.status(id)
        if (status) sessions.set(id, sessionState(status))
        await refreshPending(id)
      }))
      await publish(aggregate())
    }

    void publish("active")
    void hydrate()
    return async () => {
      unsubscribe()
      await publish("off")
    }
  },
}
