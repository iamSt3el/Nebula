#!/usr/bin/env python3
import hashlib
import html
import json
import os
import posixpath
import re
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser

CACHE = os.path.expanduser("~/.cache/quickshell/books")
LOCAL_DIRS = [os.path.expanduser("~/Books")]
GUTENDEX = "https://gutendex.com/books/?"
ASURA_SITE = "https://asurascans.com"
ASURA_API = "https://api.asurascans.com/api/"
ASURA_PAGE = 20
ASURA_REFRESH = 6 * 3600
ASURA_SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")
ASURA_PARA = re.compile(r'<p data-para="\d+"[^>]*>(.*?)</p>', re.S)
ASURA_INLINE = {"em": "i", "i": "i", "strong": "b", "b": "b"}
UA = {"User-Agent": "nebula-reading/1.0 (+https://github.com/iamSt3el)"}
TIMEOUT = 40
LIST_TTL = 24 * 3600
SKIP_TITLES = re.compile(r"project gutenberg|license|^contents$|table of contents|^the full project", re.I)


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.flush()


def fail(msg):
    out({"ok": False, "error": msg})
    sys.exit(0)


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f, ensure_ascii=False)
    os.replace(tmp, path)


def fetch(url, dest=None):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        data = r.read()
    if dest:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest + ".part", "wb") as f:
            f.write(data)
        os.replace(dest + ".part", dest)
    return data


def person(name):
    if "," in name:
        last, first = name.split(",", 1)
        return (first.strip() + " " + last.strip()).strip()
    return name.strip()


def gutendex_item(r):
    authors = r.get("authors") or []
    fmt = r.get("formats") or {}
    return {
        "source": "gutenberg",
        "id": str(r["id"]),
        "title": re.sub(r"\s+", " ", (r.get("title") or "").split(";")[0]).strip(),
        "author": person(authors[0]["name"]) if authors else "",
        "cover": fmt.get("image/jpeg", ""),
        "subjects": [s.split(" -- ")[0] for s in (r.get("subjects") or [])][:3],
        "epub": bool(fmt.get("application/epub+zip")),
    }


def cached_list(url, cache_name, build, site):
    path = os.path.join(CACHE, "lists", cache_name + ".json")
    try:
        if time.time() - os.path.getmtime(path) < LIST_TTL:
            with open(path) as f:
                return json.load(f)
    except OSError:
        pass
    try:
        data = json.loads(fetch(url))
    except Exception as e:
        try:
            with open(path) as f:
                return json.load(f)
        except OSError:
            fail("Could not reach " + site + ": " + str(e))
    res = build(data)
    write_json(path, res)
    return res


def gutendex(params, cache_name):
    def build(data):
        return {"ok": True, "count": data.get("count", 0), "next": bool(data.get("next")),
                "items": [gutendex_item(r) for r in data.get("results", []) if r.get("media_type") == "Text"]}
    return cached_list(GUTENDEX + urllib.parse.urlencode(params), cache_name, build, "Project Gutenberg")


def cmd_popular(args):
    page = int(args[0]) if args else 1
    out(gutendex({"languages": "en", "page": page}, "popular-%d" % page))


def cmd_search(args):
    if not args:
        fail("search needs a query")
    q = " ".join(args[:-1]) if len(args) > 1 and args[-1].isdigit() else " ".join(args)
    page = int(args[-1]) if len(args) > 1 and args[-1].isdigit() else 1
    key = "search-" + hashlib.sha1(q.lower().encode()).hexdigest()[:12] + "-%d" % page
    out(gutendex({"search": q, "languages": "en", "page": page}, key))


def asura_cover(url):
    return re.sub(r"\.webp$", "-400.webp", url)


def asura_item(r):
    return {
        "source": "asura",
        "id": r["slug"],
        "title": r.get("title") or r["slug"],
        "author": r.get("author") or "",
        "cover": asura_cover(r.get("cover_url") or ""),
        "subjects": (r.get("genres") or [])[:3],
        "chapters": r.get("chapter_count") or 0,
        "status": r.get("status") or "",
    }


def asura_list(params, cache_name):
    def build(data):
        items = [asura_item(r) for r in data.get("data") or []]
        return {"ok": True, "next": len(items) >= params["limit"], "items": items}
    return cached_list(ASURA_API + "novel-series?" + urllib.parse.urlencode(params), cache_name, build, "the novel library")


def cmd_asura(args):
    page = int(args[0]) if args else 1
    out(asura_list({"sort": "popular", "limit": ASURA_PAGE, "offset": (page - 1) * ASURA_PAGE}, "asura-popular-%d" % page))


def cmd_asura_search(args):
    if not args:
        fail("asura-search needs a query")
    q = " ".join(args[:-1]) if len(args) > 1 and args[-1].isdigit() else " ".join(args)
    page = int(args[-1]) if len(args) > 1 and args[-1].isdigit() else 1
    key = "asura-search-" + hashlib.sha1(q.lower().encode()).hexdigest()[:12] + "-%d" % page
    out(asura_list({"search": q, "limit": ASURA_PAGE, "offset": (page - 1) * ASURA_PAGE}, key))


def asura_cover_file(url, folder):
    if not url:
        return ""
    dest = os.path.join(folder, "cover" + (os.path.splitext(urllib.parse.urlparse(url).path)[1] or ".webp"))
    if os.path.exists(dest):
        return dest
    for candidate in (asura_cover(url), url):
        try:
            fetch(candidate, dest)
            return dest
        except Exception:
            continue
    return ""


def asura_text(raw):
    parts = []
    open_tags = []
    for tok in re.split(r"(<[^>]+>)", raw):
        if not tok.startswith("<"):
            parts.append(html.escape(html.unescape(tok), quote=False))
            continue
        m = re.match(r"<(/?)([a-z0-9]+)", tok, re.I)
        if not m:
            continue
        name = m.group(2).lower()
        if name == "br":
            parts.append("<br>")
        elif name in ASURA_INLINE:
            tag = ASURA_INLINE[name]
            if not m.group(1):
                open_tags.append(tag)
                parts.append("<%s>" % tag)
            elif tag in open_tags:
                open_tags.remove(tag)
                parts.append("</%s>" % tag)
    for tag in reversed(open_tags):
        parts.append("</%s>" % tag)
    text = re.sub(r"[ \t\r\n\f]+", " ", "".join(parts))
    text = re.sub(r" ?<br> ?", "<br>", text).strip()
    return re.sub(r"^(<br>)+|(<br>)+$", "", text).strip()


def asura_chapter(slug, number):
    path = os.path.join(CACHE, "asura-" + slug, "ch", "%d.json" % number)
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        pass
    err = None
    raw = ""
    for attempt in range(3):
        try:
            raw = fetch("%s/novels/%s/chapter/%d" % (ASURA_SITE, slug, number)).decode("utf-8", "replace")
            break
        except Exception as e:
            err = e
            time.sleep(1 + attempt)
    else:
        raise err
    paras = []
    for inner in ASURA_PARA.findall(raw):
        text = asura_text(inner)
        if re.sub(r"<[^>]+>", "", text).strip():
            paras.append({"t": text})
    if not paras:
        raise ValueError("chapter %d has no readable text" % number)
    write_json(path, paras)
    return paras


def open_asura(slug):
    if not ASURA_SLUG.match(slug):
        fail("bad novel id")
    key = "asura-" + slug
    folder = os.path.join(CACHE, key)
    book_path = os.path.join(folder, "book.json")
    try:
        if time.time() - os.path.getmtime(book_path) < ASURA_REFRESH:
            out({"ok": True, "key": key, "path": book_path})
            return
    except OSError:
        pass
    try:
        meta = json.loads(fetch(ASURA_API + "novel-series/" + slug))
    except Exception as e:
        if os.path.exists(book_path):
            out({"ok": True, "key": key, "path": book_path})
            return
        fail("Could not reach the novel library: " + str(e))
        return
    series = meta.get("series") or {}
    free = sorted((c for c in meta.get("chapters") or [] if not c.get("is_locked")), key=lambda c: c["number"])
    if not free:
        fail("This novel has no free chapters")
        return
    try:
        with ThreadPoolExecutor(max_workers=6) as pool:
            bodies = list(pool.map(lambda c: asura_chapter(slug, c["number"]), free))
    except Exception as e:
        fail("Download failed: " + str(e))
        return
    chapters = []
    for c, paras in zip(free, bodies):
        title = "Chapter %d" % c["number"] + (" - " + c["title"].strip() if c.get("title") else "")
        chapters.append({"title": title, "paras": paras, "words": sum(words(p["t"]) for p in paras)})
    cover = asura_cover_file(series.get("cover_url") or "", folder)
    book = {"v": 1, "key": key, "source": "asura", "id": slug,
            "title": series.get("title") or slug, "author": series.get("author") or "",
            "cover": cover, "start": 0, "chapters": chapters,
            "words": sum(c["words"] for c in chapters)}
    write_json(book_path, book)
    out({"ok": True, "key": key, "path": book_path})


NS = {
    "c": "urn:oasis:names:tc:opendocument:xmlns:container",
    "opf": "http://www.idpf.org/2007/opf",
    "dc": "http://purl.org/dc/elements/1.1/",
    "ncx": "http://www.daisy.org/z3986/2005/ncx/",
    "x": "http://www.w3.org/1999/xhtml",
    "epub": "http://www.idpf.org/2007/ops",
}


class Package:
    def __init__(self, path):
        self.z = zipfile.ZipFile(path)
        cont = ET.fromstring(self.z.read("META-INF/container.xml"))
        rf = cont.find(".//c:rootfile", NS)
        self.opf_path = rf.get("full-path")
        self.base = posixpath.dirname(self.opf_path)
        self.opf = ET.fromstring(self.z.read(self.opf_path))
        self.manifest = {}
        for it in self.opf.findall(".//opf:manifest/opf:item", NS):
            self.manifest[it.get("id")] = {
                "href": self.join(self.base, it.get("href")),
                "type": it.get("media-type", ""),
                "props": (it.get("properties") or "").split(),
            }
        spine = self.opf.find(".//opf:spine", NS)
        self.spine_toc = spine.get("toc") if spine is not None else None
        self.spine = [self.manifest[i.get("idref")]["href"] for i in self.opf.findall(".//opf:spine/opf:itemref", NS)
                      if i.get("idref") in self.manifest]

    @staticmethod
    def join(base, href):
        href = urllib.parse.unquote(href.split("#")[0])
        return posixpath.normpath(posixpath.join(base, href)) if base else posixpath.normpath(href)

    def meta(self, tag):
        el = self.opf.find(".//dc:" + tag, NS)
        return re.sub(r"\s+", " ", el.text).strip() if el is not None and el.text else ""

    def cover(self):
        for it in self.manifest.values():
            if "cover-image" in it["props"]:
                return it["href"]
        for m in self.opf.findall(".//opf:metadata/opf:meta", NS):
            if m.get("name") == "cover" and m.get("content") in self.manifest:
                return self.manifest[m.get("content")]["href"]
        for it in self.manifest.values():
            if it["type"].startswith("image/") and "cover" in it["href"].lower():
                return it["href"]
        return ""

    def toc(self):
        entries = []
        nav = next((it for it in self.manifest.values() if "nav" in it["props"]), None)
        if nav:
            try:
                root = ET.fromstring(self.z.read(nav["href"]))
                navs = root.findall(".//x:nav", NS)
                toc = next((n for n in navs if n.get("{%s}type" % NS["epub"]) == "toc"), navs[0] if navs else None)
                if toc is not None:
                    base = posixpath.dirname(nav["href"])
                    for a in toc.iter("{%s}a" % NS["x"]):
                        href = a.get("href") or ""
                        title = re.sub(r"\s+", " ", "".join(a.itertext())).strip()
                        if href and title:
                            entries.append((title, self.join(base, href), urllib.parse.unquote(href.split("#", 1)[1]) if "#" in href else ""))
            except (KeyError, ET.ParseError):
                entries = []
        if not entries and self.spine_toc in self.manifest:
            ncx = self.manifest[self.spine_toc]["href"]
            try:
                root = ET.fromstring(self.z.read(ncx))
                base = posixpath.dirname(ncx)
                for np in root.iter("{%s}navPoint" % NS["ncx"]):
                    lab = np.find("ncx:navLabel/ncx:text", NS)
                    con = np.find("ncx:content", NS)
                    if lab is None or con is None:
                        continue
                    src = con.get("src") or ""
                    entries.append((re.sub(r"\s+", " ", lab.text or "").strip(), self.join(base, src),
                                    urllib.parse.unquote(src.split("#", 1)[1]) if "#" in src else ""))
            except (KeyError, ET.ParseError):
                pass
        return entries


BLOCKS = {"p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "dt", "dd", "pre", "blockquote", "div", "tr"}
HEADS = {"h1", "h2", "h3", "h4", "h5", "h6"}
SKIP = {"script", "style", "head", "title", "svg", "math"}
SKIP_CLASS = re.compile(r"\b(fig\w*|illus\w*|caption|image|img\w*|pg-boilerplate|pgheader|pg-header|tnote|transnote)\b", re.I)
VOID = {"br", "img", "hr", "meta", "link", "input", "col", "area", "base", "wbr", "source"}
INLINE = {"i": "i", "em": "i", "cite": "i", "b": "b", "strong": "b"}


class Blocks(HTMLParser):
    def __init__(self, file):
        super().__init__(convert_charrefs=True)
        self.file = file
        self.blocks = []
        self.buf = []
        self.kind = None
        self.depth = 0
        self.skip = 0
        self.ids = []
        self.open_inline = []
        self.stack = []

    def flush(self):
        text = "".join(self.buf)
        text = re.sub(r"[ \t\r\n\f]+", " ", text)
        text = re.sub(r" ?<br> ?", "<br>", text).strip()
        text = re.sub(r"^(<br>)+|(<br>)+$", "", text).strip()
        plain = re.sub(r"<[^>]+>", "", text).strip()
        if plain:
            self.blocks.append({"h": self.kind in HEADS, "t": text, "file": self.file, "ids": self.ids})
            self.ids = []
        self.buf = []
        self.open_inline = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag not in VOID:
            hidden = tag in SKIP or bool(SKIP_CLASS.search(a.get("class") or ""))
            self.stack.append((tag, hidden))
            if hidden:
                if self.buf and not self.skip:
                    self.flush()
                self.skip += 1
                return
        if self.skip:
            return
        if a.get("id"):
            self.ids.append(a["id"])
        if tag in BLOCKS:
            if self.buf:
                self.flush()
            self.kind = tag
        elif tag == "br":
            self.buf.append("<br>")
        elif tag in INLINE:
            self.buf.append("<%s>" % INLINE[tag])
            self.open_inline.append(INLINE[tag])
        elif tag == "a" and a.get("name"):
            self.ids.append(a["name"])

    def handle_startendtag(self, tag, attrs):
        a = dict(attrs)
        if a.get("id") and not self.skip:
            self.ids.append(a["id"])
        if tag == "br" and not self.skip:
            self.buf.append("<br>")

    def handle_endtag(self, tag):
        if tag not in VOID and any(t == tag for t, _ in self.stack):
            while self.stack:
                t, hidden = self.stack.pop()
                if hidden:
                    self.skip = max(0, self.skip - 1)
                if t == tag:
                    break
            if self.skip:
                return
        elif self.skip:
            return
        if tag in INLINE and INLINE[tag] in self.open_inline:
            self.open_inline.remove(INLINE[tag])
            self.buf.append("</%s>" % INLINE[tag])
        elif tag in BLOCKS:
            for t in reversed(self.open_inline):
                self.buf.append("</%s>" % t)
            self.flush()
            self.kind = None

    def handle_data(self, data):
        if not self.skip:
            self.buf.append(html.escape(data, quote=False))

    def close(self):
        super().close()
        if self.buf:
            self.flush()


HEAD_WORD = re.compile(r"\b(chapter|letter|book|part|volume|stave|canto|act)\b.*$", re.I)
ROMAN = re.compile(r"^[IVXLCDM]+[.:]?$")


def clean_title(t):
    t = re.sub(r"\s+", " ", t).strip()
    m = HEAD_WORD.search(t)
    if m and m.start() > 0:
        t = m.group(0)
    t = t.strip().rstrip(".").strip()
    letters = re.sub(r"[^A-Za-z]", "", t)
    if letters and letters.isupper():
        parts = t.split(" ")
        t = " ".join(p if ROMAN.match(p) and i > 0 else p.capitalize() for i, p in enumerate(parts))
    return t


def words(text):
    return len(re.sub(r"<[^>]+>", " ", text).split())


def parse_epub(path):
    pkg = Package(path)
    stream = []
    for href in pkg.spine:
        try:
            raw = pkg.z.read(href).decode("utf-8", "replace")
        except KeyError:
            continue
        p = Blocks(href)
        p.feed(raw)
        p.close()
        if p.blocks:
            p.blocks[0]["start"] = True
        stream.extend(p.blocks)

    starts = []
    for title, file, frag in pkg.toc():
        idx = None
        for i, b in enumerate(stream):
            if b["file"] != file:
                continue
            if not frag and b.get("start"):
                idx = i
                break
            if frag and frag in b["ids"]:
                idx = i
                break
        if idx is None and frag:
            idx = next((i for i, b in enumerate(stream) if b["file"] == file), None)
        if idx is not None and all(s[1] != idx for s in starts):
            starts.append((title, idx))
    starts.sort(key=lambda s: s[1])

    chapters = []
    if len(starts) >= 2:
        for n, (title, idx) in enumerate(starts):
            end = starts[n + 1][1] if n + 1 < len(starts) else len(stream)
            chapters.append((title, stream[idx:end]))
    else:
        cur = None
        for b in stream:
            if b["h"] or cur is None:
                cur = (re.sub(r"<[^>]+>", "", b["t"]) if b["h"] else "Beginning", [])
                chapters.append(cur)
            cur[1].append(b)

    book = []
    for title, blocks in chapters:
        if SKIP_TITLES.search(title):
            continue
        paras = []
        for k, b in enumerate(blocks):
            if k == 0 and b["h"]:
                continue
            paras.append({"h": 1, "t": b["t"]} if b["h"] else {"t": b["t"]})
        if not any(not p.get("h") for p in paras):
            continue
        book.append({"title": clean_title(title), "paras": paras, "words": sum(words(p["t"]) for p in paras)})
    if not book:
        raise ValueError("no readable chapters")
    return pkg, book


def start_chapter(chapters):
    for i, c in enumerate(chapters):
        if re.match(r"^(chapter|letter|book|part|stave|canto|volume)\b", c["title"], re.I):
            return i
    return 0


def local_key(path):
    st = os.stat(path)
    return "local-" + hashlib.sha1(("%s|%d|%d" % (path, st.st_size, int(st.st_mtime))).encode()).hexdigest()[:16]


def extract_cover(pkg, dest_dir):
    href = pkg.cover()
    if not href:
        return ""
    ext = os.path.splitext(href)[1].lower() or ".jpg"
    dest = os.path.join(dest_dir, "cover" + ext)
    if not os.path.exists(dest):
        try:
            data = pkg.z.read(href)
        except KeyError:
            return ""
        os.makedirs(dest_dir, exist_ok=True)
        with open(dest, "wb") as f:
            f.write(data)
    return dest


def cmd_local(args):
    items = []
    for d in LOCAL_DIRS:
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for name in sorted(files):
                if not name.lower().endswith(".epub"):
                    continue
                path = os.path.join(root, name)
                try:
                    key = local_key(path)
                    meta_path = os.path.join(CACHE, key, "meta.json")
                    if os.path.exists(meta_path):
                        with open(meta_path) as f:
                            items.append(json.load(f))
                        continue
                    pkg = Package(path)
                    meta = {"source": "local", "id": path, "key": key,
                            "title": pkg.meta("title") or os.path.splitext(name)[0],
                            "author": pkg.meta("creator"),
                            "cover": extract_cover(pkg, os.path.join(CACHE, key))}
                    write_json(meta_path, meta)
                    items.append(meta)
                except Exception:
                    continue
    out({"ok": True, "dirs": LOCAL_DIRS, "items": items})


def cmd_open(args):
    if len(args) < 2:
        fail("open needs <source> <id>")
    source, ident = args[0], " ".join(args[1:])
    if source == "gutenberg":
        if not ident.isdigit():
            fail("bad Gutenberg id")
        key = "gb-" + ident
        folder = os.path.join(CACHE, key)
        book_path = os.path.join(folder, "book.json")
        if os.path.exists(book_path):
            out({"ok": True, "key": key, "path": book_path})
            return
        epub = os.path.join(folder, "book.epub")
        if not os.path.exists(epub):
            last = None
            for suffix in ("epub3.images", "epub.noimages", "epub.images"):
                try:
                    fetch("https://www.gutenberg.org/ebooks/%s.%s" % (ident, suffix), epub)
                    last = None
                    break
                except Exception as e:
                    last = e
            if last is not None:
                fail("Download failed: " + str(last))
        cover_url = "https://www.gutenberg.org/cache/epub/%s/pg%s.cover.medium.jpg" % (ident, ident)
    elif source == "local":
        path = os.path.expanduser(ident)
        if not os.path.isfile(path):
            fail("File not found: " + path)
        key = local_key(path)
        folder = os.path.join(CACHE, key)
        book_path = os.path.join(folder, "book.json")
        if os.path.exists(book_path):
            out({"ok": True, "key": key, "path": book_path})
            return
        epub = path
        cover_url = ""
    elif source == "asura":
        open_asura(ident)
        return
    else:
        fail("unknown source " + source)
        return
    try:
        pkg, chapters = parse_epub(epub)
    except Exception as e:
        fail("Could not read this book: " + str(e))
        return
    cover = extract_cover(pkg, folder)
    if not cover and cover_url:
        try:
            cover = os.path.join(folder, "cover.jpg")
            fetch(cover_url, cover)
        except Exception:
            cover = ""
    book = {"v": 1, "key": key, "source": source, "id": ident,
            "title": re.split(r";|:", pkg.meta("title"))[0].strip(), "author": person(pkg.meta("creator")),
            "cover": cover, "start": start_chapter(chapters), "chapters": chapters,
            "words": sum(c["words"] for c in chapters)}
    write_json(book_path, book)
    out({"ok": True, "key": key, "path": book_path})


def main():
    if len(sys.argv) < 2:
        fail("usage: books popular [page] | search <query> [page] | asura [page] | asura-search <query> [page] | local | open <gutenberg|asura|local> <id|path>")
    cmd, args = sys.argv[1], sys.argv[2:]
    {"popular": cmd_popular, "search": cmd_search, "asura": cmd_asura, "asura-search": cmd_asura_search,
     "local": cmd_local, "open": cmd_open}.get(
        cmd, lambda a: fail("unknown command " + cmd))(args)


if __name__ == "__main__":
    main()
