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
      "The origin must be an HTTP loopback literal (127.0.0.1 or [::1]), with an optional port and no path.",
    );
  }
  let url;
  try {
    url = new URL(origin);
  } catch {
    throw new BootstrapError("The loopback origin is invalid.");
  }
  if (url.port === "0")
    throw new BootstrapError("The loopback origin must use a nonzero port.");
  return { file: files[0], origin: url.origin };
}

async function credentialsFrom(path) {
  let credentials;
  try {
    credentials = JSON.parse(await readFile(path, "utf8"));
  } catch {
    throw new BootstrapError(
      "The administrator credential file must be readable JSON containing username and password.",
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
      "The administrator credential file must contain only nonempty, unpadded username and password strings.",
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
      // No redirect following, DNS lookup, proxy agent, or environment proxy support.
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
        throw new BootstrapError(
          "Zipline returned an unexpected setup response.",
        );
    } catch (error) {
      if (!(error instanceof ConnectionError)) throw error;
    }
    const remaining = deadline - Date.now();
    if (remaining > 0) await delay(Math.min(500, remaining));
  }
  throw new BootstrapError(
    "Zipline did not become ready on its loopback API within 60 seconds.",
  );
}

async function main() {
  const { file, origin } = argumentsFor(process.argv.slice(2));
  const client = clientFor(origin);
  // An initialized instance is dashboard-owned: never log in or reconcile credentials.
  if (!(await waitForSetup(client))) return;
  const admin = await credentialsFrom(file);
  // The pinned Zipline 4.8.0 setup endpoint does not create a session.
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
    throw new BootstrapError(
      "Zipline returned an unexpected bootstrap administrator identity.",
    );
  }
}

main().catch((error) => {
  // Never print raw exceptions, response bodies, credentials, cookies, or API tokens.
  console.error(
    `zipline-bootstrap-admin: ${error instanceof BootstrapError ? error.message : "Administrator bootstrap failed unexpectedly; credentials and API responses have been withheld."}`,
  );
  process.exitCode = 1;
});
