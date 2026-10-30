import argparse
import json
import select
import socket
import subprocess
import sys
import time

PORT = 38899
SKIP = ("lo", "docker", "virbr", "br-", "veth", "tun", "wg", "tailscale")
SEND_GAP = 0.05
CONFIRM_DELAY = 0.4
LOST_AFTER = 3
RESCAN_EVERY = 30.0


def own_addresses() -> list:
    try:
        out = subprocess.run(["ip", "-4", "-o", "addr"], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    found = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 4 or parts[1].startswith(SKIP):
            continue
        found.append(parts[3].split("/")[0])
    return found


def scan(timeout: float = 2.5) -> list:
    own = own_addresses()
    targets = []
    for addr in own:
        base = addr.rsplit(".", 1)[0]
        targets.extend(f"{base}.{i}" for i in range(1, 255))
    targets = [t for t in dict.fromkeys(targets) if t not in own]
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    msg = json.dumps({"method": "getPilot", "params": {}}).encode()
    for target in ["255.255.255.255", *targets]:
        try:
            sock.sendto(msg, (target, PORT))
        except OSError:
            pass
    sock.settimeout(0.25)
    bulbs = {}
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            data, (addr, _) = sock.recvfrom(4096)
        except (socket.timeout, OSError):
            continue
        try:
            reply = json.loads(data)
        except ValueError:
            continue
        if reply.get("method") == "getPilot" and "result" in reply:
            bulbs[addr] = reply["result"]
    sock.close()
    return [{"ip": ip, "mac": r.get("mac", ""), "pilot": r} for ip, r in sorted(bulbs.items())]


def request(ip: str, method: str, params: dict, timeout: float = 1.5) -> dict:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(json.dumps({"id": 1, "method": method, "params": params}).encode(), (ip, PORT))
        return json.loads(sock.recvfrom(4096)[0])
    finally:
        sock.close()


class Server:
    def __init__(self, ip: str, poll: float):
        self.ip = ip
        self.poll = poll
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setblocking(False)
        self.pending = None
        self.last_send = 0.0
        self.confirm_at = 0.0
        self.next_poll = 0.0
        self.missed = 0
        self.lost = False
        self.next_scan = 0.0

    def emit(self, obj: dict) -> None:
        sys.stdout.write(json.dumps(obj) + "\n")
        sys.stdout.flush()

    def send(self, method: str, params: dict) -> None:
        if not self.ip:
            return
        try:
            self.sock.sendto(json.dumps({"id": 1, "method": method, "params": params}).encode(), (self.ip, PORT))
        except OSError as e:
            self.emit({"type": "error", "op": method, "code": -1, "message": str(e)})

    def find(self) -> None:
        self.emit({"type": "scanning"})
        bulbs = scan()
        self.next_scan = time.monotonic() + RESCAN_EVERY
        if not bulbs:
            self.emit({"type": "notfound"})
            return
        match = next((b for b in bulbs if b["ip"] == self.ip), bulbs[0])
        self.attach(match["ip"])
        self.emit({"type": "state", "ip": self.ip, "pilot": match["pilot"]})

    def attach(self, ip: str) -> None:
        self.ip = ip
        self.missed = 0
        self.lost = False
        self.emit({"type": "host", "ip": ip})
        self.send("getSystemConfig", {})
        self.send("getModelConfig", {})
        self.send("getPilot", {})
        self.next_poll = time.monotonic() + self.poll

    def command(self, line: str) -> None:
        try:
            msg = json.loads(line)
        except ValueError:
            return
        op = msg.get("op")
        if op == "pilot" and isinstance(msg.get("params"), dict):
            self.pending = msg["params"]
        elif op == "refresh":
            self.send("getPilot", {})
        elif op == "scan":
            self.find()
        elif op == "host" and msg.get("ip"):
            self.attach(msg["ip"])

    def receive(self) -> None:
        while True:
            try:
                data, (addr, _) = self.sock.recvfrom(4096)
            except (BlockingIOError, OSError):
                return
            if addr != self.ip:
                continue
            try:
                reply = json.loads(data)
            except ValueError:
                continue
            method = reply.get("method", "")
            if self.lost:
                self.lost = False
                self.emit({"type": "host", "ip": self.ip})
            self.missed = 0
            if "error" in reply:
                err = reply["error"]
                self.emit({"type": "error", "op": method, "code": err.get("code", 0), "message": err.get("message", "")})
            elif method == "getPilot":
                self.emit({"type": "state", "ip": self.ip, "pilot": reply.get("result", {})})
            elif method == "setPilot":
                self.emit({"type": "ok", "op": method})
                self.confirm_at = time.monotonic() + CONFIRM_DELAY
            elif method == "getSystemConfig":
                self.emit({"type": "system", "config": reply.get("result", {})})
            elif method == "getModelConfig":
                self.emit({"type": "model", "config": reply.get("result", {})})

    def tick(self) -> None:
        now = time.monotonic()
        if self.pending is not None and now - self.last_send >= SEND_GAP:
            self.send("setPilot", self.pending)
            self.pending = None
            self.last_send = now
        if self.confirm_at and now >= self.confirm_at:
            self.confirm_at = 0.0
            self.send("getPilot", {})
        if self.ip and now >= self.next_poll:
            self.next_poll = now + self.poll
            self.missed += 1
            if self.missed > LOST_AFTER and not self.lost:
                self.lost = True
                self.emit({"type": "lost", "ip": self.ip})
            self.send("getPilot", {})
        if (self.lost or not self.ip) and now >= self.next_scan:
            self.find()

    def wait(self) -> float:
        now = time.monotonic()
        waits = [max(0.0, self.next_poll - now)] if self.ip else [1.0]
        if self.pending is not None:
            waits.append(max(0.0, self.last_send + SEND_GAP - now))
        if self.confirm_at:
            waits.append(max(0.0, self.confirm_at - now))
        return min(waits)

    def run(self) -> None:
        if self.ip:
            self.attach(self.ip)
            self.next_scan = time.monotonic() + 3.0
            self.missed = LOST_AFTER
        else:
            self.find()
        stdin = sys.stdin
        while True:
            ready, _, _ = select.select([stdin, self.sock], [], [], self.wait())
            if stdin in ready:
                line = stdin.readline()
                if not line:
                    return
                self.command(line)
            if self.sock in ready:
                self.receive()
            self.tick()


def main():
    parser = argparse.ArgumentParser(prog="nebula wiz", description="WiZ smart bulbs on the local network")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_serve = sub.add_parser("serve", help="JSON lines in on stdin, bulb state out on stdout")
    p_serve.add_argument("--ip", default="")
    p_serve.add_argument("--poll", type=float, default=4.0)
    sub.add_parser("scan", help="list bulbs on the network")
    p_state = sub.add_parser("state", help="print one bulb's state")
    p_state.add_argument("--ip", default="")
    p_set = sub.add_parser("set", help='send setPilot params, e.g. \'{"dimming": 40}\'')
    p_set.add_argument("params")
    p_set.add_argument("--ip", default="")
    args = parser.parse_args()

    if args.cmd == "serve":
        try:
            Server(args.ip, max(1.0, args.poll)).run()
        except KeyboardInterrupt:
            pass
        return 0
    if args.cmd == "scan":
        print(json.dumps(scan(), indent=2))
        return 0
    ip = args.ip
    if not ip:
        bulbs = scan()
        if not bulbs:
            print("no WiZ bulb found", file=sys.stderr)
            return 1
        ip = bulbs[0]["ip"]
    try:
        if args.cmd == "state":
            print(json.dumps(request(ip, "getPilot", {}), indent=2))
        else:
            print(json.dumps(request(ip, "setPilot", json.loads(args.params)), indent=2))
    except (OSError, ValueError) as e:
        print(f"{ip}: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
