<?php

// JSON API for the dashboard. Every action shells out to the omarchy-herd CLI,
// so the terminal, the bar widget and this page always agree. Reads run inline;
// changes run as background tasks whose result the page polls for.

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

/** Where background tasks leave their JSON result for the page to collect. */
function taskDir(): string
{
    $data = getenv('XDG_DATA_HOME') ?: getenv('HOME') . '/.local/share';

    return $data . '/omarchy-herd/run/tasks';
}

/**
 * Run a changing action as its own transient user service and return its id at once.
 * Outside PHP-FPM's cgroup, an action that restarts this dashboard's PHP finishes anyway,
 * and nothing depends on the browser staying connected. The page polls for the result.
 */
function startTask(string ...$args): never
{
    $dir = taskDir();
    if (! is_dir($dir) && ! mkdir($dir, 0700, true) && ! is_dir($dir)) {
        fail('could not create ' . $dir, 500);
    }
    foreach (glob($dir . '/*.json') ?: [] as $old) {
        if (filemtime($old) < time() - 3600) {
            @unlink($old);
        }
    }

    $id = bin2hex(random_bytes(8));
    $process = proc_open(
        ['/usr/bin/systemd-run', '--user', '--collect', '--quiet', '--unit=omarchy-herd-task-' . $id,
            '--property=StandardOutput=truncate:' . $dir . '/' . $id . '.json', '--', CLI, ...$args, '--json'],
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

    respond(['ok' => true, 'task' => $id]);
}

/** A finished task's result, {"pending": true} while it runs, or an error if it died silently. */
function taskResult(string $id): never
{
    $file = taskDir() . '/' . $id . '.json';
    $result = is_file($file) ? trim((string) file_get_contents($file)) : '';
    if ($result !== '') {
        @unlink($file);
        respond($result);
    }

    $process = proc_open(
        ['/usr/bin/systemctl', '--user', 'is-active', 'omarchy-herd-task-' . $id],
        [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w'], 2 => ['file', '/dev/null', 'w']],
        $pipes,
    );
    $state = '';
    if (is_resource($process)) {
        $state = trim((string) stream_get_contents($pipes[1]));
        fclose($pipes[1]);
        proc_close($process);
    }
    if (in_array($state, ['active', 'activating', 'reloading'], true)) {
        respond(['pending' => true]);
    }

    @unlink($file);
    fail("The action stopped without a result; see: journalctl --user -u omarchy-herd-task-$id", 500);
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
        'task' => taskResult(arg($_GET, 'id', '/^[0-9a-f]{16}$/')),
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

$action = $input['action'] ?? '';

// Stopping the PHP that serves this page would leave nothing to start it again from here.
$self = PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;
if ($action === 'stop' && arg($input, 'service', SERVICE) === "php-$self") {
    fail("PHP $self runs this dashboard; stop it from a terminal with: omarchy-herd stop php-$self");
}

match ($action) {
    'start', 'stop', 'restart' => startTask($action, arg($input, 'service', SERVICE)),

    'php-install' => startTask('php', 'install', arg($input, 'version', PHP_VERSION_RE)),
    'php-uninstall' => startTask('php', 'uninstall', arg($input, 'version', PHP_VERSION_RE)),
    'php-default' => startTask('php', 'default', arg($input, 'version', PHP_VERSION_RE)),
    'php-update' => startTask('php', 'update'),

    'isolate' => startTask('isolate', arg($input, 'version', PHP_VERSION_RE), arg($input, 'site', SITE)),
    'unisolate' => startTask('unisolate', arg($input, 'site', SITE)),

    'node-install' => startTask('node', 'install', arg($input, 'version', NODE_VERSION)),
    'node-uninstall' => startTask('node', 'uninstall', arg($input, 'version', '/^\d+\.\d+\.\d+$/')),
    'node-default' => startTask('node', 'default', arg($input, 'version', NODE_VERSION)),
    'node-use' => startTask('node', 'use', arg($input, 'version', NODE_VERSION), arg($input, 'site', SITE)),
    'node-reset' => startTask('node', 'reset', arg($input, 'site', SITE)),

    'park' => startTask('park', arg($input, 'path', PATH_RE)),
    'unpark' => startTask('unpark', arg($input, 'path', PATH_RE)),
    'link' => startTask('link', arg($input, 'name', SITE), arg($input, 'path', PATH_RE)),
    'unlink' => startTask('unlink', arg($input, 'name', SITE)),
    'proxy' => startTask('proxy', arg($input, 'name', SITE), arg($input, 'target', '/^([a-z0-9.-]+:)?\d{2,5}$/')),
    'unproxy' => startTask('unproxy', arg($input, 'name', SITE)),

    default => fail('unknown action'),
};
