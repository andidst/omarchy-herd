import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Talks to the omarchy-herd CLI: polls `status --json` (slowly for the bar
// icon, faster while the panel is open) and runs start/stop actions.
Item {
  id: root

  property string statusCommand: ""
  property string herdCommand: "omarchy-herd"
  property bool panelOpen: false
  property int idleIntervalSec: 30
  property int openIntervalSec: 5

  property var status: null
  property bool loaded: false
  property string error: ""
  property string pendingId: ""
  property string pendingAction: ""
  property string actionMessage: ""
  property string actionError: ""
  property bool manualRefresh: false
  // After a successful start/stop, hold the new state until the next status
  // arrives so the switch does not flick back while the CLI catches up.
  property string expectId: ""
  property bool expectRunning: false

  // Lists are only reassigned when their contents change, so the panel's
  // repeaters and the sites list keep their rows (and scroll position)
  // across the 5 second polls.
  property var services: []
  property var phpVersions: []
  property var nodeVersions: []
  property var sites: []

  readonly property bool refreshing: statusProcess.running
  readonly property bool busy: actionProcess.running
  readonly property var web: Model.webState(status)
  readonly property var problems: Model.problems(status, error)
  readonly property bool healthy: loaded && problems.length === 0
  readonly property string tooltip: loaded ? Model.tooltip(status, error) : "Herd"
  readonly property string dashboardUrl: status && status.dashboard ? String(status.dashboard) : "https://herd.test"

  // The CLI is linked into ~/.local/bin; keep it resolvable even when the shell
  // was started with a thinner PATH.
  readonly property string pathSetup: "export PATH=\"$PATH:$HOME/.local/bin\"; "

  signal actionFailed(string message)

  property bool _refreshAgain: false
  property bool _clearsExpect: false
  property string _lastRaw: ""
  property var _listJson: ({})
  property string _statusOut: ""
  property string _statusErr: ""
  property string _actionOut: ""
  property string _actionErr: ""

  function refresh(manual) {
    if (manual === true) manualRefresh = true
    if (statusProcess.running) {
      _refreshAgain = true
      return
    }
    _statusOut = ""
    _statusErr = ""
    // Only a poll started after the action finished may settle the switch.
    _clearsExpect = expectId !== ""
    statusProcess.command = ["bash", "-c", pathSetup + statusCommand]
    statusProcess.running = true
  }

  function runAction(action, id) {
    if (actionProcess.running || !id) return
    pendingId = String(id)
    pendingAction = action
    actionError = ""
    actionMessage = ""
    _actionOut = ""
    _actionErr = ""
    actionProcess.command = ["bash", "-c", pathSetup + "exec \"$0\" \"$@\"", herdCommand, action, pendingId, "--json"]
    actionProcess.running = true
  }

  function toggleService(svc) {
    if (!svc || svc.installed === false) return
    runAction(isRunning(svc) ? "stop" : "start", svc.id)
  }

  function isPending(id) {
    return busy && pendingId === String(id)
  }

  function isRunning(svc) {
    if (!svc) return false
    var id = String(svc.id)
    if (isPending(id)) return pendingAction !== "stop"
    if (expectId === id) return expectRunning
    return svc.running === true
  }

  function openUrl(url) {
    if (url) Quickshell.execDetached(["xdg-open", String(url)])
  }

  function setList(name, value) {
    var json = JSON.stringify(value)
    if (_listJson[name] === json) return
    _listJson[name] = json
    root[name] = value
  }

  function applyStatus(stdout, stderr, exitCode) {
    var raw = String(stdout || "") + "\u0000" + String(stderr || "") + "\u0000" + exitCode
    loaded = true
    if (_clearsExpect) expectId = ""
    if (raw === _lastRaw) return
    _lastRaw = raw

    var result = Model.parseResult(stdout, stderr, exitCode)
    status = result.ok ? result.data : null
    error = result.ok ? "" : result.error
    setList("services", Model.list(status && status.services))
    setList("phpVersions", Model.list(status && status.php && status.php.versions))
    setList("nodeVersions", Model.list(status && status.node && status.node.versions))
    setList("sites", Model.list(status && status.sites))
  }

  function applyAction(stdout, stderr, exitCode) {
    var result = Model.parseResult(stdout, stderr, exitCode)
    if (result.ok) {
      expectId = pendingId
      expectRunning = pendingAction !== "stop"
      actionMessage = Model.oneLine(result.data && result.data.message || "")
      messageTimer.restart()
    } else {
      actionError = result.error
      actionFailed(result.error)
    }
    pendingId = ""
    pendingAction = ""
    refresh()
  }

  onPanelOpenChanged: if (panelOpen) refresh()

  Timer {
    interval: (root.panelOpen ? root.openIntervalSec : root.idleIntervalSec) * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: messageTimer
    interval: 3000
    onTriggered: root.actionMessage = ""
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._statusOut = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root._statusErr = text }
    onExited: function(exitCode) {
      root.applyStatus(statusStdout.text || root._statusOut, statusStderr.text || root._statusErr, exitCode)
      if (root._refreshAgain) {
        root._refreshAgain = false
        Qt.callLater(root.refresh)
      } else {
        root.manualRefresh = false
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root._actionOut = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root._actionErr = text }
    onExited: function(exitCode) {
      root.applyAction(actionStdout.text || root._actionOut, actionStderr.text || root._actionErr, exitCode)
    }
  }
}
