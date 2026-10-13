<?php

// JSON API for the dashboard. Every action shells out to the omarchy-herd CLI,
// so the terminal, the bar widget and this page always agree.

declare(strict_types=1);

const CLI = __DIR__ . '/../bin/omarchy-herd';
const HOST = 'herd.test';

header('Content-Type: application/json');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");

function respond(array|string $payload, int $status = 200): never
{
    http_response_code($status);
    echo is_string($payload) ? $payload : json_encode($payload, JSON_UNESCAPED_SLASHES);
    exit;
}

function fail(string $error, int $status = 400): never
{
    respond(['ok' => false, 'error' => $error], $status);
}

/** Run the CLI without a shell and return its stdout, which is always JSON. */
function herd(string ...$args): string
{
    $process = proc_open(
        [CLI, ...$args, '--json'],
        [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        getenv('HOME') ?: null,
    );
    if (! is_resource($process)) {
        fail('could not run omarchy-herd', 500);
    }

    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $code = proc_close($process);

    if (trim($stdout) === '') {
        fail(trim($stderr) ?: "omarchy-herd exited with code $code", 500);
    }

    return $stdout;
}

/**
 * Start the CLI as its own transient user service and return at once. Used for actions
 * that restart the PHP-FPM serving this request: run inline, they'd kill themselves.
 */
function herdInBackground(string ...$args): string
{
    $unit = 'omarchy-herd-task-' . bin2hex(random_bytes(4));
    $process = proc_open(
        ['/usr/bin/systemd-run', '--user', '--collect', '--quiet', '--unit=' . $unit, '--', CLI, ...$args],
        [0 => ['file', '/dev/null', 'r'], 1 => ['file', '/dev/null', 'w'], 2 => ['pipe', 'w']],
        $pipes,
    );
    if (! is_resource($process)) {
        fail('could not start a background task', 500);
    }
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    if (proc_close($process) !== 0) {
        fail(trim($stderr) ?: 'could not start a background task', 500);
    }

    return json_encode([
        'ok' => true,
        'background' => true,
        'message' => 'Working on it: the dashboard reconnects in a few seconds',
    ]);
}

function arg(array $input, string $key, string $pattern): string
{
    $value = $input[$key] ?? '';
    if ($key === 'path' && is_string($value) && preg_match('#^~(/|$)#', $value)) {
        $value = getenv('HOME') . substr($value, 1);
    }
    if (! is_string($value) || ! preg_match($pattern, $value)) {
        fail("invalid $key");
    }

    return $value;
}

const SITE = '/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/';
const PHP_VERSION_RE = '/^8\.[0-5]$/';
const NODE_VERSION = '/^(\d+(\.\d+){0,2}|lts|latest)$/';
const SERVICE = '/^(mariadb|postgres|valkey|php-8\.[0-5])$/';
const PATH_RE = '/^\/[^"\n\\\\{}]*$/';

// Only answer the dashboard's own origin: blocks other websites and DNS rebinding.
$host = strtolower(explode(':', $_SERVER['HTTP_HOST'] ?? '')[0]);
if ($host !== HOST) {
    fail('wrong host', 403);
}
// Browsers label every request with where it came from; only accept the dashboard itself.
$fetchSite = $_SERVER['HTTP_SEC_FETCH_SITE'] ?? null;
if ($fetchSite !== null && ! in_array($fetchSite, ['same-origin', 'none'], true)) {
    fail('cross-site requests are not allowed', 403);
}
$origin = $_SERVER['HTTP_ORIGIN'] ?? null;
if ($origin !== null && ! in_array($origin, ['https://' . HOST, 'http://' . HOST], true)) {
    fail('cross-origin requests are not allowed', 403);
}

set_time_limit(0);

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? 'status';

    respond(match ($action) {
        'status' => herd('status'),
        'php-available' => herd('php', 'available'),
        'node-available' => herd('node', 'available'),
        default => fail('unknown action'),
    });
}

// Writes need a custom header, which forces a CORS preflight that other origins can't pass.
if ($_SERVER['REQUEST_METHOD'] !== 'POST' || ($_SERVER['HTTP_X_HERD'] ?? '') !== '1') {
    fail('forbidden', 403);
}

$input = json_decode(file_get_contents('php://input') ?: '', true);
if (! is_array($input)) {
    fail('expected a JSON body');
}

// The PHP version serving this dashboard; restarting it from here needs a background task.
$self = PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;
$action = $input['action'] ?? '';

if (in_array($action, ['start', 'stop', 'restart'], true)) {
    $service = arg($input, 'service', SERVICE);
    if ($service === "php-$self") {
        if ($action === 'stop') {
            fail("PHP $self runs this dashboard; stop it from a terminal with: omarchy-herd stop php-$self");
        }
        respond(herdInBackground($action, $service));
    }
    respond(herd($action, $service));
}
if ($action === 'php-update' || ($action === 'php-install' && arg($input, 'version', PHP_VERSION_RE) === $self)) {
    respond(herdInBackground('php', $action === 'php-update' ? 'update' : 'install', ...($action === 'php-update' ? [] : [$self])));
}

respond(match ($action) {
    'php-install' => herd('php', 'install', arg($input, 'version', PHP_VERSION_RE)),
    'php-uninstall' => herd('php', 'uninstall', arg($input, 'version', PHP_VERSION_RE)),
    'php-default' => herd('php', 'default', arg($input, 'version', PHP_VERSION_RE)),
    'php-update' => herd('php', 'update'),

    'isolate' => herd('isolate', arg($input, 'version', PHP_VERSION_RE), arg($input, 'site', SITE)),
    'unisolate' => herd('unisolate', arg($input, 'site', SITE)),

    'node-install' => herd('node', 'install', arg($input, 'version', NODE_VERSION)),
    'node-uninstall' => herd('node', 'uninstall', arg($input, 'version', '/^\d+\.\d+\.\d+$/')),
    'node-default' => herd('node', 'default', arg($input, 'version', NODE_VERSION)),
    'node-use' => herd('node', 'use', arg($input, 'version', NODE_VERSION), arg($input, 'site', SITE)),
    'node-reset' => herd('node', 'reset', arg($input, 'site', SITE)),

    'park' => herd('park', arg($input, 'path', PATH_RE)),
    'unpark' => herd('unpark', arg($input, 'path', PATH_RE)),
    'link' => herd('link', arg($input, 'name', SITE), arg($input, 'path', PATH_RE)),
    'unlink' => herd('unlink', arg($input, 'name', SITE)),
    'proxy' => herd('proxy', arg($input, 'name', SITE), arg($input, 'target', '/^([a-z0-9.-]+:)?\d{2,5}$/')),
    'unproxy' => herd('unproxy', arg($input, 'name', SITE)),

    default => fail('unknown action'),
});
