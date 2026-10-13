// Pure helpers for the Herd panel: parsing CLI output and turning the status
// object into labels. No QML types here so the logic stays easy to follow.

var TYPE_LABELS = {
  laravel: "Laravel",
  php: "PHP",
  static: "Static",
  proxy: "Proxy",
  wordpress: "WordPress",
  symfony: "Symfony",
  statamic: "Statamic",
  craft: "Craft"
}

function list(value) {
  return Array.isArray(value) ? value : []
}

function oneLine(text, max) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  var limit = max || 160
  return value.length > limit ? value.substring(0, limit - 1) + "…" : value
}

// The CLI prints one JSON object on stdout for both success and failure, and
// exits non-zero on failure. Returns { ok, data, error }.
function parseResult(stdout, stderr, exitCode) {
  var text = String(stdout || "").trim()
  var parsed = null
  if (text !== "") {
    try { parsed = JSON.parse(text) } catch (e) { parsed = null }
  }
  if (parsed && typeof parsed === "object" && parsed.ok !== false && exitCode === 0)
    return { ok: true, data: parsed, error: "" }
  if (parsed && typeof parsed === "object" && parsed.error)
    return { ok: false, data: parsed, error: oneLine(parsed.error) }
  if (exitCode === 127) return { ok: false, data: null, error: "omarchy-herd was not found on PATH" }
  var fallback = String(stderr || "").trim() || text || ("omarchy-herd exited with code " + exitCode)
  return { ok: false, data: null, error: oneLine(fallback) }
}

// What to suggest under an error, so the panel is useful before setup.
function errorHint(error) {
  var text = String(error || "")
  if (text.indexOf("not set up") !== -1 || text.indexOf("setup") !== -1)
    return "Run omarchy-herd setup in a terminal, then refresh."
  if (text.indexOf("not found") !== -1)
    return "Link the CLI into ~/.local/bin, then refresh."
  return "Run omarchy-herd doctor in a terminal for details."
}

function webState(status) {
  var web = status && status.web ? status.web : {}
  return {
    web: web.caddy === true,
    dns: web.dns === true && web.resolves !== false,
    https: web.https_trusted === true
  }
}

// Problems that should tint the bar icon: the CLI failing, Caddy or DNS being
// down, or something that is enabled but not running.
function problems(status, error) {
  if (error) return [error]
  if (!status) return []
  var out = []
  var web = status.web || {}
  if (web.caddy !== true) out.push("Caddy is down")
  if (web.dns !== true) out.push("DNS is down")
  else if (web.resolves === false) out.push(".test does not resolve")
  var services = list(status.services)
  for (var i = 0; i < services.length; i++) {
    var svc = services[i]
    if (svc.installed !== false && svc.enabled === true && svc.running !== true)
      out.push(String(svc.name || svc.id) + " is stopped")
  }
  var php = list(status.php && status.php.versions)
  for (var j = 0; j < php.length; j++) {
    var version = php[j]
    var expected = version.enabled === true || (version.enabled === undefined && version.default === true)
    if (expected && version.running !== true) out.push("PHP " + version.version + " is stopped")
  }
  return out
}

function tooltip(status, error) {
  if (error) return "Herd: " + error
  if (!status) return "Herd"
  var count = list(status.sites).length
  var text = "Herd: " + count + (count === 1 ? " site" : " sites")
  var issues = problems(status, "")
  return issues.length > 0 ? text + " · " + issues.join(", ") : text
}

function serviceIcon(svc) {
  var id = String(svc && svc.id || "")
  if (id === "valkey" || id === "redis") return "󱐋"
  return "󰆼"
}

function serviceAddress(svc) {
  if (!svc) return ""
  var host = String(svc.host || "127.0.0.1")
  return svc.port ? host + ":" + svc.port : host
}

function serviceMeta(svc) {
  if (!svc) return ""
  if (svc.installed === false) return "Not installed"
  var parts = [serviceAddress(svc)]
  if (svc.user) parts.push(String(svc.user))
  return parts.join(" · ")
}

function typeLabel(type) {
  var key = String(type || "").toLowerCase()
  if (TYPE_LABELS[key]) return TYPE_LABELS[key]
  return key === "" ? "" : key.charAt(0).toUpperCase() + key.slice(1)
}

function siteIcon(site) {
  var type = String(site && site.type || "")
  if (site && site.proxy) return "󰒍"
  if (type === "laravel") return "󰫐"
  return "󰖟"
}

function siteDomain(site) {
  if (!site) return ""
  return String(site.domain || site.name || site.url || "")
}

function siteMeta(site) {
  if (!site) return ""
  if (site.proxy) return "→ " + site.proxy
  var parts = []
  var type = typeLabel(site.type)
  if (type !== "" && type !== "PHP") parts.push(type)
  if (site.php) {
    var php = "PHP " + site.php
    if (site.php_installed === false) php += " (missing)"
    else if (site.isolated === true) php += " (isolated)"
    parts.push(php)
  }
  if (parts.length === 0 && type !== "") parts.push(type)
  return parts.join(" · ")
}

// Theme colors.toml carries `green` (or `color2` on older themes); the shell's
// Color singleton only exposes foreground/accent/urgent, so read it here.
function themeGreen(raw, fallback) {
  var lines = String(raw || "").split("\n")
  var color2 = ""
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (!match) continue
    if (match[1] === "green") return match[2]
    if (match[1] === "color2") color2 = match[2]
  }
  return color2 !== "" ? color2 : fallback
}
