#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { request as httpRequest } from "node:http";
import { setTimeout as delay } from "node:timers/promises";

const requestTimeoutMs = 5_000;
const readinessTimeoutMs = 60_000;
const maxResponseBytes = 64 * 1024;
class BootstrapError extends Error {}
class ConnectionError extends BootstrapError {}

function argumentsFor(args) {
  const files = [];
  let origin = "http://127.0.0.1:3002";
  let originSeen = false;
  const usage =
    "Usage: zipline-bootstrap-admin ADMIN_FILE [--origin http://127.0.0.1:PORT]";
  for (let index = 0; index < args.length; index++) {
    if (args[index] === "--origin" && !originSeen && args[index + 1]) {
      origin = args[++index];
      originSeen = true;
    } else if (args[index].startsWith("--")) {
      throw new BootstrapError(usage);
    } else {
      files.push(args[index]);
    }
  }
  if (files.length !== 1) throw new BootstrapError(usage);
  // Literal addresses avoid DNS rebinding; node:http ignores environment proxies.
  if (!/^http:\/\/(?:127\.0\.0\.1|\[::1\])(?::[0-9]+)?\/?$/.test(origin)) {
    throw new BootstrapError(
      "origin must be http://127.0.0.1 or http://[::1], optional port, no path",
    );
  }
  let url;
  try {
    url = new URL(origin);
  } catch {
    throw new BootstrapError("invalid origin");
  }
  if (url.port === "0") throw new BootstrapError("origin port must not be 0");
  return { file: files[0], origin: url.origin };
}

async function credentialsFrom(path) {
  let credentials;
  try {
    credentials = JSON.parse(await readFile(path, "utf8"));
  } catch {
    throw new BootstrapError(
      "admin file must be JSON with username and password",
    );
  }
  if (
    !credentials ||
    typeof credentials !== "object" ||
    Array.isArray(credentials) ||
    Object.keys(credentials).some(
      (key) => key !== "username" && key !== "password",
    ) ||
    [credentials.username, credentials.password].some(
      (value) =>
        typeof value !== "string" || !value.length || value !== value.trim(),
    )
  ) {
    throw new BootstrapError(
      "admin file must hold only nonempty, unpadded username and password",
    );
  }
  return credentials;
}

function clientFor(origin) {
  function request(method, path, body, timeoutMs = requestTimeoutMs) {
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const headers = { accept: "application/json" };
    if (payload !== undefined) {
      headers["content-type"] = "application/json";
      headers["content-length"] = Buffer.byteLength(payload);
    }
    return new Promise((resolve, reject) => {
      // No redirects, DNS lookups or proxies.
      const request = httpRequest(
        `${origin}${path}`,
        {
          method,
          headers,
          agent: false,
          signal: AbortSignal.timeout(timeoutMs),
        },
        (response) => {
          if (response.statusCode >= 300 && response.statusCode < 400) {
            reject(
              new BootstrapError(
                "Zipline redirected an API request; redirects are not permitted.",
              ),
            );
            response.destroy();
            return;
          }
          const chunks = [];
          let size = 0;
          response.on("data", (chunk) => {
            size += chunk.length;
            if (size > maxResponseBytes) {
              reject(
                new BootstrapError(
                  "Zipline returned an oversized API response.",
                ),
              );
              response.destroy();
              return;
            }
            chunks.push(chunk);
          });
          response.on("error", () =>
            reject(
              new ConnectionError(
                "The local Zipline API connection failed or timed out.",
              ),
            ),
          );
          response.on("end", () => {
            let data;
            try {
              data = JSON.parse(Buffer.concat(chunks).toString("utf8"));
            } catch {
              reject(
                new BootstrapError(
                  "Zipline returned an invalid JSON API response.",
                ),
              );
              return;
            }
            resolve({ status: response.statusCode, data });
          });
        },
      );
      request.on("error", () =>
        reject(
          new ConnectionError(
            "The local Zipline API connection failed or timed out.",
          ),
        ),
      );
      request.end(payload);
    });
  }
  return { request };
}

async function waitForSetup(client) {
  const deadline = Date.now() + readinessTimeoutMs;
  while (Date.now() < deadline) {
    try {
      const result = await client.request(
        "GET",
        "/api/setup",
        undefined,
        Math.max(1, Math.min(requestTimeoutMs, deadline - Date.now())),
      );
      if (result.status === 403 && result.data?.code === 9001) return false;
      if (result.status === 200 && result.data?.firstSetup === true)
        return true;
      if (result.status < 500)
        throw new BootstrapError("unexpected /api/setup response");
    } catch (error) {
      if (!(error instanceof ConnectionError)) throw error;
    }
    const remaining = deadline - Date.now();
    if (remaining > 0) await delay(Math.min(500, remaining));
  }
  throw new BootstrapError("Zipline not ready after 60 s");
}

async function main() {
  const { file, origin } = argumentsFor(process.argv.slice(2));
  const client = clientFor(origin);
  // Already set up: the dashboard owns the admin.
  if (!(await waitForSetup(client))) return;
  const admin = await credentialsFrom(file);
  // Zipline's setup endpoint does not create a session.
  const result = await client.request("POST", "/api/setup", admin);
  if (result.status !== 200)
    throw new BootstrapError("Initial Zipline setup failed.");
  const user = result.data?.user;
  if (
    result.data?.firstSetup !== false ||
    !user ||
    user.username !== admin.username ||
    user.role !== "SUPERADMIN"
  ) {
    throw new BootstrapError("setup returned an unexpected admin user");
  }
}

main().catch((error) => {
  // Keep credentials and API responses out of the journal.
  console.error(
    `zipline-bootstrap-admin: ${error instanceof BootstrapError ? error.message : "admin bootstrap failed; details withheld"}`,
  );
  process.exitCode = 1;
});
