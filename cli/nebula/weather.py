#!/usr/bin/env python3
import json
import math
import os
import sys
import tempfile
import urllib.parse
import urllib.request
from datetime import datetime, timezone

CACHE = os.path.expanduser("~/.cache/quickshell/weather.json")
DEFAULT_GEO_FILE = os.path.expanduser("~/.cache/quickshell/geo")
GEO_URL = "https://geocoding-api.open-meteo.com/v1/search?"
REVERSE_GEO_URL = "https://api.bigdatacloud.net/data/reverse-geocode-client?"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast?"
TIMEOUT = 15

WMO = {
    0: ("113", "Sunny"),
    1: ("116", "Mainly clear"),
    2: ("116", "Partly cloudy"),
    3: ("122", "Overcast"),
    45: ("248", "Fog"),
    48: ("260", "Freezing fog"),
    51: ("263", "Light drizzle"),
    53: ("266", "Drizzle"),
    55: ("266", "Dense drizzle"),
    56: ("281", "Freezing drizzle"),
    57: ("284", "Heavy freezing drizzle"),
    61: ("296", "Light rain"),
    63: ("302", "Moderate rain"),
    65: ("308", "Heavy rain"),
    66: ("311", "Light freezing rain"),
    67: ("314", "Freezing rain"),
    71: ("326", "Light snow"),
    73: ("332", "Moderate snow"),
    75: ("338", "Heavy snow"),
    77: ("179", "Snow grains"),
    80: ("353", "Light rain shower"),
    81: ("356", "Rain shower"),
    82: ("359", "Torrential rain shower"),
    85: ("368", "Light snow shower"),
    86: ("371", "Heavy snow shower"),
    95: ("386", "Thunderstorm"),
    96: ("389", "Thunderstorm with hail"),
    99: ("389", "Thunderstorm with heavy hail"),
}

COMPASS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
           "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]


def get(url, params):
    with urllib.request.urlopen(url + urllib.parse.urlencode(params), timeout=TIMEOUT) as r:
        return json.load(r)


def load_cache():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(obj):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE), suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, CACHE)


def load_settings():
    try:
        from nebula import settings as s
        return s.section("weather")
    except Exception:
        return {}


def get_geo_file(settings=None):
    if settings is None:
        settings = load_settings()
    f = settings.get("geoFile") if isinstance(settings, dict) else None
    if f:
        return os.path.expanduser(str(f))
    return os.environ.get("NEBULA_GEO_FILE") or DEFAULT_GEO_FILE


def parse_coords(text):
    if not text:
        return None
    text = text.strip()
    if text.startswith("{"):
        try:
            d = json.loads(text)
            lat_v = d.get("lat") if "lat" in d else d.get("latitude")
            lon_v = d.get("lon") if "lon" in d else d.get("longitude")
            if lat_v is not None and lon_v is not None:
                lat = float(lat_v)
                lon = float(lon_v)
                label = str(d.get("city") or d.get("name") or d.get("area") or "")
                if -90 <= lat <= 90 and -180 <= lon <= 180:
                    return lat, lon, label
        except (ValueError, TypeError, json.JSONDecodeError):
            pass
    parts = text.replace(",", " ").split()
    if len(parts) >= 2:
        try:
            lat = float(parts[0])
            lon = float(parts[1])
            if -90 <= lat <= 90 and -180 <= lon <= 180:
                label = " ".join(parts[2:]).strip()
                return lat, lon, label
        except ValueError:
            pass
    return None


def read_geo_file(path=None):
    path = path or get_geo_file()
    path = os.path.expanduser(str(path))
    try:
        with open(path) as f:
            content = f.read()
    except OSError:
        return None
    return parse_coords(content)


def reverse_geocode(lat, lon):
    try:
        data = get(REVERSE_GEO_URL, {"latitude": lat, "longitude": lon, "localityLanguage": "en"})
        city = data.get("city") or data.get("locality") or data.get("principalSubdivision")
        country = data.get("countryName") or ""
        region = data.get("principalSubdivision") or ""
        return city or "", country, region
    except Exception:
        return "", "", ""


def geocode(name, cache, geo_file=None):
    if name == "auto":
        parsed = read_geo_file(geo_file)
        if parsed:
            lat, lon, label = parsed
            if not label:
                label, country, region = reverse_geocode(lat, lon)
                area = {"country": country, "region": region}
            else:
                area = {"country": "", "region": ""}
            if label:
                area["name"] = label
            return lat, lon, area
        fallback = timezone_city()
        if fallback and fallback != "auto":
            return geocode(fallback, cache, geo_file=geo_file)
        raise LookupError("auto")

    coords = parse_coords(name)
    if coords:
        lat, lon, label = coords
        if not label:
            label, country, region = reverse_geocode(lat, lon)
            area = {"country": country, "region": region}
        else:
            area = {"country": "", "region": ""}
        if label:
            area["name"] = label
        return lat, lon, area

    expanded = os.path.expanduser(name)
    if os.path.isfile(expanded):
        parsed = read_geo_file(expanded)
        if parsed:
            lat, lon, label = parsed
            if not label:
                label, country, region = reverse_geocode(lat, lon)
                area = {"country": country, "region": region}
            else:
                area = {"country": "", "region": ""}
            if label:
                area["name"] = label
            return lat, lon, area

    if cache.get("location") == name and "lat" in cache and "lon" in cache:
        return cache["lat"], cache["lon"], cache.get("area", {})
    query = name.split(",")[0].strip()
    results = get(GEO_URL, {"name": query, "count": 1, "language": "en", "format": "json"}).get("results") or []
    if not results:
        raise LookupError(name)
    r = results[0]
    return r["latitude"], r["longitude"], {"country": r.get("country", ""), "region": r.get("admin1", "")}


def num(v, default=0):
    return default if v is None else v


def fahrenheit(c):
    return str(round(c * 9 / 5 + 32))


def whole(v):
    return str(round(v))


def clock(iso):
    return datetime.fromisoformat(iso).strftime("%I:%M %p")


def condition(code, is_day):
    wttr, desc = WMO.get(int(num(code)), ("113", "Unknown"))
    if int(num(code)) == 0 and not is_day:
        desc = "Clear"
    return wttr, desc


SYNODIC = 29.530588853
NEW_REF = datetime(2000, 1, 6, 18, 14, tzinfo=timezone.utc)
PHASES = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
          "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]


def moon(date):
    noon = datetime.fromisoformat(date + "T12:00").astimezone(timezone.utc)
    age = ((noon - NEW_REF).total_seconds() / 86400) % SYNODIC
    illum = (1 - math.cos(2 * math.pi * age / SYNODIC)) / 2
    return {"moon_phase": PHASES[int(age / SYNODIC * 8 + 0.5) % 8],
            "moon_illumination": str(round(illum * 100))}


def hourly_entry(h, i, sunrise, sunset):
    t = datetime.fromisoformat(h["time"][i])
    temp = num(h["temperature_2m"][i])
    feel = num(h["apparent_temperature"][i], temp)
    code, desc = condition(h["weather_code"][i], sunrise <= t < sunset)
    return {
        "time": str(t.hour * 100),
        "tempC": whole(temp),
        "tempF": fahrenheit(temp),
        "FeelsLikeC": whole(feel),
        "FeelsLikeF": fahrenheit(feel),
        "humidity": whole(num(h["relative_humidity_2m"][i])),
        "weatherCode": code,
        "weatherDesc": [{"value": desc}],
        "chanceofrain": whole(num(h["precipitation_probability"][i])),
        "windspeedKmph": whole(num(h["wind_speed_10m"][i])),
        "uvIndex": whole(num(h["uv_index"][i])),
    }


def build(name, lat, lon, area):
    d = get(FORECAST_URL, {
        "latitude": lat,
        "longitude": lon,
        "timezone": "auto",
        "forecast_days": 7,
        "current": "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,"
                   "wind_speed_10m,wind_direction_10m,cloud_cover,uv_index,visibility,"
                   "precipitation,pressure_msl,is_day",
        "hourly": "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,"
                  "precipitation_probability,wind_speed_10m,uv_index",
        "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset",
    })
    c, h, dl = d["current"], d["hourly"], d["daily"]

    days = []
    for n, date in enumerate(dl["time"]):
        sunrise = datetime.fromisoformat(dl["sunrise"][n])
        sunset = datetime.fromisoformat(dl["sunset"][n])
        hours = [hourly_entry(h, i, sunrise, sunset)
                 for i, t in enumerate(h["time"])
                 if t.startswith(date) and datetime.fromisoformat(t).hour % 3 == 0]
        hi, lo = num(dl["temperature_2m_max"][n]), num(dl["temperature_2m_min"][n])
        days.append({
            "date": date,
            "maxtempC": whole(hi), "maxtempF": fahrenheit(hi),
            "mintempC": whole(lo), "mintempF": fahrenheit(lo),
            "avgtempC": whole((hi + lo) / 2), "avgtempF": fahrenheit((hi + lo) / 2),
            "astronomy": [{"sunrise": clock(dl["sunrise"][n]), "sunset": clock(dl["sunset"][n]), **moon(date)}],
            "hourly": hours,
        })

    now_hour = c["time"][:13]
    rain_now = next((num(p) for t, p in zip(h["time"], h["precipitation_probability"])
                     if t.startswith(now_hour)), 0)
    temp = num(c["temperature_2m"])
    feel = num(c["apparent_temperature"], temp)
    code, desc = condition(c["weather_code"], bool(num(c["is_day"], 1)))
    precip = num(c["precipitation"])
    pressure = num(c["pressure_msl"])
    deg = num(c["wind_direction_10m"])

    current = {
        "temp_C": whole(temp), "temp_F": fahrenheit(temp),
        "FeelsLikeC": whole(feel), "FeelsLikeF": fahrenheit(feel),
        "humidity": whole(num(c["relative_humidity_2m"])),
        "weatherCode": code,
        "weatherDesc": [{"value": desc}],
        "windspeedKmph": whole(num(c["wind_speed_10m"])),
        "winddirDegree": whole(deg),
        "winddir16Point": COMPASS[int((deg % 360) / 22.5 + 0.5) % 16],
        "cloudcover": whole(num(c["cloud_cover"])),
        "uvIndex": whole(num(c["uv_index"])),
        "visibility": whole(num(c["visibility"]) / 1000),
        "precipMM": str(round(precip, 1)),
        "precipInches": str(round(precip / 25.4, 1)),
        "pressure": whole(pressure),
        "pressureInches": whole(pressure * 0.02953),
        "chanceofrain": whole(rain_now),
    }

    display_name = area.get("name") or (name.split(",")[0].strip() if name != "auto" else timezone_city() or "Auto")

    return {
        "current_condition": [current],
        "nearest_area": [{
            "areaName": [{"value": display_name}],
            "country": [{"value": area.get("country", "")}],
            "region": [{"value": area.get("region", "")}],
            "latitude": str(lat),
            "longitude": str(lon),
        }],
        "weather": days,
    }


def timezone_city():
    zone = os.environ.get("TZ", "").lstrip(":")
    if not zone:
        try:
            zone = os.path.realpath("/etc/localtime").split("zoneinfo/", 1)[1]
        except IndexError:
            zone = ""
    city = zone.rsplit("/", 1)[-1].replace("_", " ")
    return "" if city in ("", "UTC", "GMT", "Universal", "Zulu") else city


def main():
    geo_file = None
    args = sys.argv[1:]
    name = ""
    i = 0
    clean_args = []
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print("usage: nebula weather [<place> | auto | <coords> | <geo-file>] [--geo-file <path>]")
            sys.exit(0)
        elif arg == "--geo-file" and i + 1 < len(args):
            geo_file = args[i + 1]
            i += 2
            continue
        elif arg.startswith("--geo-file="):
            geo_file = arg.split("=", 1)[1]
            i += 1
            continue
        clean_args.append(arg)
        i += 1

    if clean_args:
        name = clean_args[0].strip()

    settings = load_settings()
    if not geo_file:
        geo_file = get_geo_file(settings)

    if geo_file and not name and ("--geo-file" in sys.argv[1:] or any(a.startswith("--geo-file=") for a in sys.argv[1:])):
        name = "auto"

    if not name:
        if settings.get("useGeoFile") or settings.get("location") == "auto":
            name = "auto"
        elif settings.get("location"):
            name = str(settings.get("location")).strip()

    if not name:
        name = timezone_city()

    if not name:
        name = "auto"

    cache = load_cache()
    try:
        lat, lon, area = geocode(name, cache, geo_file=geo_file)
        data = build(name, lat, lon, area)
    except (OSError, ValueError, KeyError, LookupError, TypeError, IndexError):
        sys.exit(1)
    save_cache({"location": name, "lat": lat, "lon": lon, "area": area, "data": data})
    json.dump(data, sys.stdout)


if __name__ == "__main__":
    main()
