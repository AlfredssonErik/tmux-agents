import assert from "node:assert/strict"
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { delimiter, join } from "node:path"
import { pathToFileURL } from "node:url"

const pluginPath = process.argv[2]
const { default: plugin } = await import(pathToFileURL(pluginPath))
const tuiPath = pluginPath.replace(/index\.js$/, "tui.js")
const { default: tuiPlugin } = await import(pathToFileURL(tuiPath))

assert.equal(plugin.id, "tmux-agents")
assert.equal(typeof plugin.setup, "function")
assert.equal(tuiPlugin.id, "tmux-agents")
assert.equal(typeof tuiPlugin.setup, "function")

const tempDir = await mkdtemp(join(tmpdir(), "tmux-agents-plugin-test-"))
const binDir = join(tempDir, "bin")
const logPath = join(tempDir, "calls.jsonl")
const fakeBash = join(binDir, "bash")
await mkdir(binDir)
await writeFile(fakeBash, "#!/usr/bin/env node\nrequire('node:fs').appendFileSync(process.env.TMUX_AGENTS_TEST_LOG, JSON.stringify(process.argv.slice(2)) + '\\n')\n")
await chmod(fakeBash, 0o755)
process.env.TMUX_PANE = "%test"
process.env.TMUX_AGENTS_TEST_LOG = logPath
process.env.PATH = `${binDir}${delimiter}${process.env.PATH}`

try {
  const handlers = new Map()
  const pendingForms = new Map()
  const pendingInbox = new Map()
  const pendingPermissions = new Map()
  const cachedSessions = []
  const cachedStatuses = new Map()
  const dispose = await tuiPlugin.setup({
    ui: { router: { current: () => ({ type: "session", sessionID: "s1" }) } },
    data: {
      listen(handler) {
        handlers.set("all", handler)
        return () => handlers.delete("all")
      },
      location: { default: () => "/test" },
      session: {
        list: () => cachedSessions,
        sync: async () => {},
        status: (sessionID) => cachedStatuses.get(sessionID),
        permission: {
          sync: async () => {},
          list: (sessionID) => pendingPermissions.get(sessionID) ?? [],
        },
        form: {
          sync: async (sessionID) => {},
          list: (sessionID) => pendingForms.get(sessionID) ?? [],
        },
        pending: {
          sync: async () => {},
          list: (sessionID) => pendingInbox.get(sessionID) ?? [],
        },
      },
    },
  })

  const deadline = Date.now() + 5000
  while (Date.now() < deadline) {
    try {
      const calls = (await readFile(logPath, "utf8")).trim().split("\n")
      if (calls.length >= 1) break
    } catch {
      // Initial tmux state publication has not completed yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }

  const emit = (type, data) => handlers.get("all")({ details: { type, data } })
  emit("session.execution.started", { sessionID: "s1" })
  pendingPermissions.set("s1", [{ id: "p1" }])
  emit("permission.asked", { sessionID: "s1" })
  pendingPermissions.delete("s1")
  emit("permission.replied", { sessionID: "s1" })
  pendingForms.set("s1", [{ id: "f1" }])
  emit("form.created", { form: { id: "f1", sessionID: "s1" } })
  const formDeadline = Date.now() + 5000
  while (Date.now() < formDeadline) {
    try {
      if ((await readFile(logPath, "utf8")).trim().split("\n").length >= 5) break
    } catch {
      // Form state has not been published yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  pendingForms.delete("s1")
  emit("form.replied", { id: "f1" })
  const formClearDeadline = Date.now() + 5000
  while (Date.now() < formClearDeadline) {
    try {
      if ((await readFile(logPath, "utf8")).trim().split("\n").length >= 6) break
    } catch {
      // Cleared form state has not been published yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  pendingInbox.set("s1", [{ id: "i1" }])
  emit("session.inbox.enqueued", { sessionID: "s1", inboxID: "i1" })
  const inboxDeadline = Date.now() + 5000
  while (Date.now() < inboxDeadline) {
    try {
      if ((await readFile(logPath, "utf8")).trim().split("\n").length >= 7) break
    } catch {
      // Pending inbox state has not been published yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  pendingInbox.delete("s1")
  emit("session.inbox.delivered", { sessionID: "s1", inboxID: "i1" })
  const inboxClearDeadline = Date.now() + 5000
  while (Date.now() < inboxClearDeadline) {
    try {
      if ((await readFile(logPath, "utf8")).trim().split("\n").length >= 8) break
    } catch {
      // Cleared pending inbox state has not been published yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  emit("session.execution.succeeded", { sessionID: "s1" })
  emit("session.deleted", { sessionID: "s1" })

  const transitionDeadline = Date.now() + 5000
  while (Date.now() < transitionDeadline) {
    try {
      const calls = (await readFile(logPath, "utf8")).trim().split("\n")
      if (calls.length >= 10) break
    } catch {
      // Initial tmux state publication has not completed yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }

  await dispose()

  const calls = (await readFile(logPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line))
  const states = calls
    .map((args) => args.indexOf("--state") >= 0 ? args[args.indexOf("--state") + 1] : "clear")
  assert.deepEqual(states, ["active", "working", "waiting", "working", "waiting", "working", "pending", "working", "idle", "active", "clear"])
  assert.equal(handlers.size, 0)

  await writeFile(logPath, "")
  const restoredHandlers = new Map()
  const disposeRestored = await tuiPlugin.setup({
    ui: { router: { current: () => ({ type: "session", sessionID: "restored" }) } },
    data: {
      listen(handler) {
        restoredHandlers.set("all", handler)
        return () => restoredHandlers.delete("all")
      },
      location: { default: () => "/test" },
      session: {
        list: () => [{ id: "restored" }],
        sync: async () => {},
        status: () => ({ type: "busy" }),
        permission: { sync: async () => {}, list: () => [{ id: "p1" }] },
        form: { sync: async () => {}, list: () => [] },
        pending: { sync: async () => {}, list: () => [] },
      },
    },
  })
  const hydrationDeadline = Date.now() + 5000
  while (Date.now() < hydrationDeadline) {
    try {
      if ((await readFile(logPath, "utf8")).trim().split("\n").length >= 2) break
    } catch {
      // Restored state has not been published yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  await disposeRestored()
  const restoredStates = (await readFile(logPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line))
    .map((args) => args.indexOf("--state") >= 0 ? args[args.indexOf("--state") + 1] : "clear")
  assert.deepEqual(restoredStates, ["active", "waiting", "clear"])
  assert.equal(restoredHandlers.size, 0)

  await writeFile(logPath, "")
  process.env.TMUX_PANE = "%other"
  const foreignHandlers = new Map()
  const disposeForeign = await tuiPlugin.setup({
    ui: { router: { current: () => ({ type: "session", sessionID: "s2" }) } },
    data: {
      listen(handler) {
        foreignHandlers.set("all", handler)
        return () => foreignHandlers.delete("all")
      },
      location: { default: () => "/test" },
      session: {
        list: () => [],
        sync: async () => {},
        status: () => undefined,
        permission: { sync: async () => {}, list: () => [] },
        form: { sync: async () => {}, list: () => [] },
        pending: { sync: async () => {}, list: () => [] },
      },
    },
  })
  const foreignDeadline = Date.now() + 5000
  while (Date.now() < foreignDeadline) {
    try {
      if ((await readFile(logPath, "utf8")).trim()) break
    } catch {
      // Initial state has not been published yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  foreignHandlers.get("all")({ details: { type: "form.created", data: { form: { id: "foreign", sessionID: "s1" } } } })
  await new Promise((resolve) => setTimeout(resolve, 100))
  await disposeForeign()
  const foreignStates = (await readFile(logPath, "utf8"))
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line))
    .filter((args) => args[args.indexOf("--pane") + 1] === "%other")
    .map((args) => args.indexOf("--state") >= 0 ? args[args.indexOf("--state") + 1] : "clear")
  assert.deepEqual(foreignStates, ["active", "clear"])
  assert.equal(foreignHandlers.size, 0)
} finally {
  delete process.env.TMUX_PANE
  delete process.env.TMUX_AGENTS_TEST_LOG
  await rm(tempDir, { recursive: true, force: true })
}
