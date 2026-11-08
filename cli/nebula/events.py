#!/usr/bin/env python3
import hashlib
import json
import os
import re
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

CACHE = os.path.expanduser("~/.cache/quickshell/events")
PAST = 7
AHEAD = 60
WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


def fetch(url):
    key = hashlib.sha1(url.encode()).hexdigest()[:16]
    path = os.path.join(CACHE, key + ".ics")
    if url.startswith("webcal://"):
        url = "https://" + url[len("webcal://"):]
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "quickshell-events"})
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read().decode("utf-8", "replace")
        if "BEGIN:VCALENDAR" in body:
            os.makedirs(CACHE, exist_ok=True)
            with open(path, "w") as f:
                f.write(body)
            return body, "ok"
        failure = "notCalendar"
    except Exception:
        failure = "unreachable"
    try:
        with open(path) as f:
            return f.read(), "cached"
    except OSError:
        return "", failure


def calendar_name(text):
    for line in unfold(text):
        if line.startswith("X-WR-CALNAME:"):
            return line.split(":", 1)[1].replace("\\,", ",").replace("\\;", ";").strip()
        if line == "BEGIN:VEVENT":
            break
    return ""


def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def parse_dt(value, params, local):
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        return datetime.strptime(value[:8], "%Y%m%d").date(), True
    if value.endswith("Z"):
        dt = datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    else:
        dt = datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
        tz = params.get("TZID")
        try:
            dt = dt.replace(tzinfo=ZoneInfo(tz)) if tz else dt.replace(tzinfo=local)
        except Exception:
            dt = dt.replace(tzinfo=local)
    return dt.astimezone(local), False


def events_of(text, local):
    out = []
    cur = None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur = {"exdates": []}
            continue
        if line == "END:VEVENT":
            if cur and "start" in cur:
                out.append(cur)
            cur = None
            continue
        if cur is None or ":" not in line:
            continue
        head, value = line.split(":", 1)
        parts = head.split(";")
        name = parts[0].upper()
        params = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
        if name == "DTSTART":
            cur["start"], cur["allDay"] = parse_dt(value, params, local)
        elif name == "DTEND":
            cur["end"], _ = parse_dt(value, params, local)
        elif name == "SUMMARY":
            cur["title"] = value.replace("\\,", ",").replace("\\;", ";").replace("\\n", " ")
        elif name == "LOCATION":
            cur["location"] = value.replace("\\,", ",").replace("\\;", ";")
        elif name == "RRULE":
            cur["rrule"] = dict(p.split("=", 1) for p in value.split(";") if "=" in p)
        elif name == "EXDATE":
            for v in value.split(","):
                try:
                    cur["exdates"].append(parse_dt(v, params, local)[0])
                except ValueError:
                    pass
        elif name == "STATUS" and value.upper() == "CANCELLED":
            cur["cancelled"] = True
    return [e for e in out if not e.get("cancelled")]


def as_date(x):
    return x.date() if isinstance(x, datetime) else x


def add_months(d, n):
    m = d.month - 1 + n
    y = d.year + m // 12
    m = m % 12 + 1
    day = min(d.day, [31, 29 if y % 4 == 0 and (y % 100 or y % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1])
    return d.replace(year=y, month=m, day=day)


def occurrences(ev, lo, hi):
    start = ev["start"]
    rule = ev.get("rrule")
    if not rule:
        yield start
        return
    freq = rule.get("FREQ", "")
    interval = int(rule.get("INTERVAL", "1") or 1)
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = None
    if "UNTIL" in rule:
        try:
            until = parse_dt(rule["UNTIL"], {}, start.tzinfo if isinstance(start, datetime) else None)[0]
        except Exception:
            until = None
    byday = [d[-2:] for d in rule.get("BYDAY", "").split(",") if d]
    n = 0
    step = 0
    while step < 5000:
        if freq == "DAILY":
            cands = [start + timedelta(days=step * interval)]
        elif freq == "WEEKLY":
            base = start + timedelta(weeks=step * interval)
            if byday:
                monday = base - timedelta(days=base.weekday())
                cands = sorted(monday + timedelta(days=WEEKDAYS.index(d)) for d in byday if d in WEEKDAYS)
                cands = [c for c in cands if c >= start]
            else:
                cands = [base]
        elif freq == "MONTHLY":
            cands = [add_months(start, step * interval)]
        elif freq == "YEARLY":
            cands = [add_months(start, 12 * step * interval)]
        else:
            yield start
            return
        step += 1
        for c in cands:
            if until is not None:
                if isinstance(c, datetime) and isinstance(until, datetime):
                    past = c > until
                else:
                    past = as_date(c) > as_date(until)
                if past:
                    return
            n += 1
            if count is not None and n > count:
                return
            cd = as_date(c)
            if cd > hi:
                return
            if cd >= lo and c not in ev["exdates"]:
                yield c


def main():
    urls = [u for u in sys.argv[1:] if u.strip()]
    local = datetime.now().astimezone().tzinfo
    today = date.today()
    lo = today - timedelta(days=PAST)
    hi = today + timedelta(days=AHEAD)
    out = []
    feeds = []
    for ci, url in enumerate(urls):
        text, status = fetch(url)
        before = len(out)
        for ev in events_of(text, local):
            start = ev["start"]
            end = ev.get("end")
            if end is None:
                end = start + (timedelta(days=1) if ev["allDay"] else timedelta(hours=1))
            dur = end - start
            for s in occurrences(ev, lo, hi):
                e = s + dur
                if as_date(e) < lo or as_date(s) > hi:
                    continue
                if ev["allDay"]:
                    out.append({"title": ev.get("title", "(no title)"), "allDay": True, "calendar": ci,
                                "start": s.isoformat(), "end": e.isoformat(),
                                "location": ev.get("location", "")})
                else:
                    out.append({"title": ev.get("title", "(no title)"), "allDay": False, "calendar": ci,
                                "start": int(s.timestamp() * 1000), "end": int(e.timestamp() * 1000),
                                "location": ev.get("location", "")})
        feeds.append({"url": url, "name": calendar_name(text), "status": status, "count": len(out) - before})
    def key(e):
        return e["start"] if not e["allDay"] else int(datetime.fromisoformat(e["start"]).timestamp() * 1000)
    out.sort(key=key)
    print(json.dumps({"events": out, "calendars": feeds}))


if __name__ == "__main__":
    main()
