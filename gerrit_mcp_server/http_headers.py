"""Builds curl attribution headers for Gerrit REST API requests."""

import contextvars
import re
from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version

_CONTROL_CHARS = re.compile(r"[\x00-\x1f\x7f]")


def _reject_if_unsafe(value: str, sentinel: str = "unparseable") -> str:
    """Return value unchanged, or sentinel if it contains control characters."""
    return sentinel if _CONTROL_CHARS.search(value) else value


@dataclass
class RequestObservabilityContext:
    tool_name: str
    client_name: str | None
    client_version: str | None
    protocol_version: str | None


_request_obs: contextvars.ContextVar[RequestObservabilityContext | None] = (
    contextvars.ContextVar("gerrit_mcp_request_obs", default=None)
)


def _package_version(pkg: str) -> str:
    try:
        return version(pkg)
    except PackageNotFoundError:
        return "unknown"


def build_curl_header_args(obs: RequestObservabilityContext | None) -> list[str]:
    """Returns curl args that set User-Agent and X-MCP-* attribution headers."""
    server_ver = _package_version("gerrit-mcp-server")
    sdk_ver = _package_version("mcp")

    ua_parts = [f"gerrit-mcp-server/{server_ver}", f"mcp-python-sdk/{sdk_ver}"]
    if obs and obs.client_name:
        client_name = _reject_if_unsafe(obs.client_name)
        client_ver = (
            _reject_if_unsafe(obs.client_version) if obs.client_version else "unknown"
        )
        ua_parts.append(f"{client_name}/{client_ver}")

    result = ["-A", " ".join(ua_parts)]

    if obs:
        if obs.tool_name:
            result += ["-H", f"X-MCP-Tool: {_reject_if_unsafe(obs.tool_name)}"]
        if obs.client_name:
            result += ["-H", f"X-MCP-Client: {_reject_if_unsafe(obs.client_name)}"]
        if obs.protocol_version:
            result += [
                "-H",
                f"X-MCP-Protocol-Version: {_reject_if_unsafe(obs.protocol_version)}",
            ]

    return result
