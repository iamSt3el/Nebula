.pragma library

const KINDS = [
    { word: "Archive",  icon: "folder_zip",   exts: ["zip", "7z", "rar", "tar", "tar.gz", "tar.xz", "tar.zst", "tar.bz2", "gz", "xz", "zst", "bz2", "tgz"] },
    { word: "Document", icon: "description",  exts: ["pdf", "doc", "docx", "odt", "txt", "md", "epub", "rtf", "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp"] },
    { word: "Image",    icon: "image",        exts: ["png", "jpg", "jpeg", "webp", "gif", "svg", "avif", "heic", "bmp"] },
    { word: "Video",    icon: "movie",        exts: ["mp4", "mkv", "webm", "mov", "avi"] },
    { word: "Audio",    icon: "music_note",   exts: ["mp3", "flac", "ogg", "opus", "wav", "m4a"] },
    { word: "Package",  icon: "package_2",    exts: ["deb", "rpm", "appimage", "exe", "msi", "dmg", "apk", "pkg.tar.zst", "flatpak"] }
]

const FILE_TEXT = /\b(download(ed)?\s+(is\s+)?(complete|completed|finished|done)|finished\s+downloading|file\s+(received|saved|transferred)|received\s+(a\s+)?file|transfer\s+(complete|completed|finished))\b/i

function plain(s) {
    return String(s ?? "").replace(/<[^>]*>/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/\s+/g, " ").trim()
}

function extOf(name) {
    const m = /\.(pkg\.tar\.zst|tar\.(?:gz|xz|zst|bz2)|[A-Za-z0-9]{1,8})$/.exec(name)
    return m ? m[1].toLowerCase() : ""
}

function kindOf(ext) {
    for (const k of KINDS)
        if (k.exts.indexOf(ext) >= 0)
            return k
    return { word: ext !== "" ? "File" : "Download", icon: "draft" }
}

function fileInfo(n) {
    const empty = { isFile: false, name: "", path: "", ext: "", word: "", icon: "" }
    if (!n)
        return empty
    const hints = n.notification?.hints ?? {}
    const cat = String(hints.category ?? "")
    const summary = plain(n.summary)
    const rawBody = String(n.body ?? "")
    const body = plain(rawBody)
    if (cat === "transfer.error")
        return empty
    if (!cat.startsWith("transfer") && !FILE_TEXT.test(summary + " " + body))
        return empty

    let path = ""
    const href = /href=["']file:\/\/([^"']+)["']/i.exec(rawBody)
    if (href)
        path = decodeURIComponent(href[1])
    else {
        const abs = /(?:file:\/\/)?(\/[^\s"'<>]+\.[A-Za-z0-9]{1,8})/.exec(body)
        if (abs)
            path = decodeURIComponent(abs[1])
    }

    let name = path !== "" ? path.slice(path.lastIndexOf("/") + 1) : ""
    if (name === "") {
        const all = (body + " " + summary).match(/[^\s\/"'<>:]+\.(?:pkg\.tar\.zst|tar\.(?:gz|xz|zst|bz2)|[A-Za-z0-9]{1,8})\b/g) ?? []
        name = all.length ? all[0] : ""
    }
    const ext = extOf(name)
    const k = kindOf(ext)
    return { isFile: true, name: name, path: path, ext: ext, word: k.word, icon: k.icon }
}

function humanBytes(b) {
    if (!(b > 0))
        return ""
    const units = ["B", "KB", "MB", "GB", "TB"]
    let i = 0
    let v = b
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024
        i++
    }
    return (v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)) + " " + units[i]
}
