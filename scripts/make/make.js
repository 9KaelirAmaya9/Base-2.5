#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const COMMANDS = new Set(["setup", "start", "stop", "restart", "logs", "test", "deploy"]);
const ALIASES = { up: "start", down: "stop" };

function printHelp(exitCode = 0) {
  const lines = [
    "Usage:",
    "  node scripts/make/make.js [--shell bash|powershell] <command> [args...]",
    "",
    "Commands:",
    "  setup   start   stop   restart   logs   test   deploy",
    "",
    "Aliases:",
    "  up -> start",
    "  down -> stop",
    "",
    "Examples:",
    "  node scripts/make/make.js start --compose-file development.docker.yml",
    "  node scripts/make/make.js --shell powershell test -ComposeFile local.docker.yml",
  ];
  process.stdout.write(lines.join("\n") + "\n");
  process.exit(exitCode);
}

function parseArgs(argv) {
  let shellType = null;
  let command = null;
  const rest = [];

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") {
      printHelp(0);
    }
    if (arg.startsWith("--shell=")) {
      shellType = arg.split("=")[1];
      continue;
    }
    if (arg === "--shell") {
      shellType = argv[i + 1];
      i += 1;
      continue;
    }
    if (!command) {
      command = arg;
      continue;
    }
    rest.push(arg);
  }

  return { shellType, command, rest };
}

function resolveCommand(command) {
  if (!command) {
    printHelp(1);
  }
  const resolved = ALIASES[command] || command;
  if (!COMMANDS.has(resolved)) {
    process.stderr.write(`Unknown command: ${command}\n`);
    printHelp(1);
  }
  return resolved;
}

function resolveShell(shellType) {
  if (shellType) {
    const normalized = shellType.toLowerCase();
    if (normalized === "powershell" || normalized === "ps" || normalized === "pwsh") {
      return "powershell";
    }
    if (normalized === "bash" || normalized === "sh") {
      return "bash";
    }
    process.stderr.write(`Unknown shell: ${shellType}\n`);
    printHelp(1);
  }
  return process.platform === "win32" ? "powershell" : "bash";
}

function ensureScript(scriptPath) {
  if (!fs.existsSync(scriptPath)) {
    process.stderr.write(`Missing script: ${scriptPath}\n`);
    process.exit(1);
  }
}

function runBash(command, rest) {
  const scriptPath = path.resolve(__dirname, "..", "bash", `${command}.sh`);
  ensureScript(scriptPath);
  const result = spawnSync("bash", [scriptPath, ...rest], { stdio: "inherit" });
  process.exit(result.status ?? 1);
}

function runPowerShell(command, rest) {
  const scriptPath = path.resolve(__dirname, "..", "powershell", `${command}.ps1`);
  ensureScript(scriptPath);
  const args = ["-ExecutionPolicy", "Bypass", "-File", scriptPath, ...rest];
  let result = spawnSync("pwsh", args, { stdio: "inherit" });
  if (result.error && result.error.code === "ENOENT") {
    result = spawnSync("powershell", args, { stdio: "inherit" });
  }
  process.exit(result.status ?? 1);
}

const parsed = parseArgs(process.argv.slice(2));
const command = resolveCommand(parsed.command);
const shellType = resolveShell(parsed.shellType);

if (shellType === "powershell") {
  runPowerShell(command, parsed.rest);
} else {
  runBash(command, parsed.rest);
}
