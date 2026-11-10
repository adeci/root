"""Kagi search with a session link: Quick Answer plus results."""

import argparse
import json
import os
import sys
from http.cookiejar import CookieJar
from urllib.error import URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import HTTPCookieProcessor, Request, build_opener

from bs4 import BeautifulSoup

BASE = "https://kagi.com"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"


class Kagi:
    def __init__(self, session_file):
        with open(session_file) as f:
            link = f.read().strip()
        # The file holds either the whole session link or just its token.
        token = parse_qs(urlparse(link).query).get("token", [link])[0]
        self.cookies = CookieJar()
        self.opener = build_opener(HTTPCookieProcessor(self.cookies))
        self.get(f"/html/search?token={token}")
        if not any(c.name == "kagi_session" for c in self.cookies):
            sys.exit("kagi-search: Kagi rejected the session link")

    def get(self, path, **kwargs):
        headers = {"User-Agent": USER_AGENT, **kwargs.pop("headers", {})}
        with self.opener.open(Request(BASE + path, headers=headers, **kwargs), timeout=60) as r:
            if urlparse(r.geturl()).path.startswith(("/signin", "/welcome")):
                sys.exit("kagi-search: Kagi rejected the session link")
            return r.read().decode()

    def results(self, query, limit):
        page = BeautifulSoup(self.get("/html/search?" + urlencode({"q": query})), "html.parser")
        found = []
        for result in page.select(".results-box .search-result"):
            link = result.select_one(".__sri-title-box a[href]")
            desc = result.select_one(".__sri-desc")
            for button in desc.select(".summarize-link") if desc else []:
                button.decompose()
            if link:
                found.append(
                    {
                        "title": link.get_text(" ", strip=True),
                        "url": link["href"],
                        "snippet": desc.get_text(" ", strip=True) if desc else "",
                    }
                )
        return found[:limit]

    def quick_answer(self, query):
        session = next((c.value for c in self.cookies if c.name == "kagi_session"), "")
        try:
            stream = self.get(
                "/mother/context?" + urlencode({"q": query}),
                data=b"",
                method="POST",
                headers={"Accept": "application/vnd.kagi.stream", "X-Kagi-Authorization": session},
            )
        except URLError:
            # Not every query gets a Quick Answer; the results still stand.
            return None
        # Lines are "<kind>:<payload>"; the finished answer is the new_message one.
        for line in stream.splitlines():
            kind, _, payload = line.partition(":")
            if kind == "new_message.json":
                message, _ = json.JSONDecoder().raw_decode(payload)
                answer = "\n\n".join(filter(None, [message.get("md"), message.get("references_md")]))
                return answer or None
        return None


def main():
    parser = argparse.ArgumentParser(description="Search Kagi: Quick Answer plus results.")
    parser.add_argument("query", nargs="+")
    parser.add_argument("-n", "--results", type=int, default=5, help="number of results (default 5)")
    parser.add_argument("-j", "--json", action="store_true", help="print JSON")
    args = parser.parse_args()

    session_file = os.environ.get("KAGI_SESSION_FILE")
    if not session_file:
        sys.exit("kagi-search: set KAGI_SESSION_FILE to a file holding the Kagi session link")

    query = " ".join(args.query)
    try:
        kagi = Kagi(session_file)
        answer = kagi.quick_answer(query)
        results = kagi.results(query, args.results)
    except URLError as e:
        sys.exit(f"kagi-search: {e}")

    if args.json:
        print(json.dumps({"quick_answer": answer, "results": results}, indent=2))
        return
    if answer:
        print(answer, end="\n\n")
    for i, r in enumerate(results, 1):
        print(f"{i}. {r['title']}\n   {r['url']}")
        if r["snippet"]:
            print(f"   {r['snippet']}")


if __name__ == "__main__":
    main()
