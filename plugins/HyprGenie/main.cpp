#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/output/MonitorResources.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/helpers/math/Math.hpp>
#include <hyprland/src/render/Texture.hpp>
#include <hyprland/src/render/Framebuffer.hpp>
#include <hyprland/src/render/transformer/Transformer.hpp>
#include <hyprland/src/render/pass/PassElement.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>
#include <hyprland/src/render/pass/ClearPassElement.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <algorithm>
#include <array>
#include <unordered_map>
#include <chrono>
#include <cmath>
#include <sstream>
#include <string>
#include <vector>

using Clock = std::chrono::steady_clock;

static HANDLE PHANDLE = nullptr;

namespace {

    struct SConfig {
        bool  open    = true;
        bool  close    = true;
        bool  minimize = true;
        bool  tiled    = true;
        bool  ws       = true;
        bool  move     = true;
        float wsMs     = 500.F;
        float moveMs   = 450.F;
        float openMs   = 600.F;
        float closeMs  = 520.F;
        int   strips   = 0;
        int   style    = 0;
        CHyprColor container{0.16, 0.16, 0.15, 1.0};
        CHyprColor accent{0.8, 0.75, 0.9, 1.0};
    } g_cfg;

    struct SIcon {
        std::vector<std::string> keys;
        CBox                     rect;
    };

    struct SArm {
        std::vector<std::string> keys;
        CBox                     rect;
        Clock::time_point        at;
        bool                     fromDock = true;
    };

    struct SOrigin {
        PHLWINDOWREF             window;
        std::vector<std::string> keys;
        CBox                     rect;
        bool                     fromDock = true;
    };

    enum eSide : uint8_t {
        SIDE_BOTTOM = 0,
        SIDE_TOP,
        SIDE_LEFT,
        SIDE_RIGHT,
    };

    struct SAnim;

    class CGenieTransformer;

    struct SCorner {
        double radius = 0.0;
        double power  = 2.0;
        double border = 0.0;
    };

    struct SAnim {
        bool                     opening = true;
        PHLWINDOWREF             window;
        PHLMONITORREF            monitor;
        CBox                     icon;
        CBox                     source;
        SP<Render::IFramebuffer>    snapshot;
        Render::IWindowTransformer* transformer = nullptr;
        Render::IWindowTransformer* hider       = nullptr;
        Clock::time_point           start;
        Clock::time_point           warpUntil;
        float                    durationMs = 600.F;
        double                   c          = 1.0;
        double                   t          = 0.0;
        int                      style      = 0;
        CBox                     geoPx;
        SCorner                  corner;
        bool                     ws = false;
        CBox                     lastDamage;
        bool                     done = false;
    };

    std::vector<SIcon>     g_icons;
    std::vector<SArm>      g_arms;
    std::vector<SOrigin>   g_origins;
    std::vector<SP<SAnim>> g_anims;

    std::vector<CHyprSignalListener> g_listeners;
    SP<SHyprCtlCommand>              g_command;

    double                           clamp01(double v) {
        return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    }

    double lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }

    struct SBezier {
        double x1, y1, x2, y2;

        double bx(double t) const {
            return 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t;
        }
        double by(double t) const {
            return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t;
        }
        double operator()(double x) const {
            if (x <= 0)
                return 0;
            if (x >= 1)
                return 1;
            double lo = 0, hi = 1, t = 0.5;
            for (int i = 0; i < 28; ++i) {
                if (bx(t) < x)
                    lo = t;
                else
                    hi = t;
                t = (lo + hi) / 2;
            }
            return by(t);
        }
    };

    const SBezier STANDARD{0.2, 0.0, 0.0, 1.0};
    const SBezier EMPH_DECEL{0.05, 0.7, 0.1, 1.0};
    const SBezier INOUT{0.45, 0.0, 0.55, 1.0};

    std::string   lower(std::string s) {
        std::ranges::transform(s, s.begin(), [](unsigned char ch) { return std::tolower(ch); });
        return s;
    }

    bool keyMatches(const std::string& key, const std::string& cls) {
        if (key.empty() || cls.empty())
            return false;
        if (key == cls)
            return true;
        if (cls.size() > key.size() && cls.ends_with("." + key))
            return true;
        if (key.size() > cls.size() && key.ends_with("." + cls))
            return true;
        return false;
    }

    bool windowMatches(const PHLWINDOW& w, const std::vector<std::string>& keys) {
        const auto CLS  = lower(w->m_class);
        const auto INIT = lower(w->m_initialClass);
        for (auto const& k : keys) {
            if (keyMatches(k, CLS) || keyMatches(k, INIT))
                return true;
        }
        return false;
    }

    bool sameKeys(const std::vector<std::string>& a, const std::vector<std::string>& b) {
        for (auto const& x : a) {
            for (auto const& y : b) {
                if (x == y)
                    return true;
            }
        }
        return false;
    }

    CBox monitorLogical(const PHLMONITOR& m) {
        return CBox{m->m_position, m->m_size};
    }

    bool iconOnMonitor(const CBox& icon, const PHLMONITOR& m) {
        return monitorLogical(m).containsPoint(icon.middle());
    }

    CBox toMonitorPixels(const CBox& global, const PHLMONITOR& m) {
        CBox b = global.copy();
        b.translate(-m->m_position);
        b.scale(m->m_scale);
        return b;
    }

    CBox windowPixelBox(const PHLWINDOW& w, const PHLMONITOR& m) {
        CBox b = w->getFullWindowBoundingBox();
        const auto OFFSET = (w->m_pinned || !w->m_workspace ? Vector2D{} : w->m_workspace->m_renderOffset->value()) + w->m_floatingOffset - m->m_position;
        b.translate(OFFSET);
        b.scale(m->m_scale);
        return b;
    }

    eSide sideFor(const CBox& iconPx, const PHLMONITOR& m) {
        const auto   C    = iconPx.middle();
        const auto   SIZE = m->m_transformedSize;
        const double dB = SIZE.y - C.y, dT = C.y, dL = C.x, dR = SIZE.x - C.x;
        const double best = std::min({dB, dT, dL, dR});
        if (best == dB)
            return SIDE_BOTTOM;
        if (best == dT)
            return SIDE_TOP;
        if (best == dL)
            return SIDE_LEFT;
        return SIDE_RIGHT;
    }

    struct SRow {
        double a, lo, hi;
    };

    SRow rowAt(double winA, double winLen, double winLo, double winHi, double icA, double icLen, double icLo, double icHi, double c, double v, bool leadAtEnd) {
        const double LEAD = leadAtEnd ? v : 1.0 - v;
        const double EA   = INOUT(clamp01(c * 1.7 - (1.0 - LEAD) * 0.7));
        const double EW   = INOUT(clamp01(c * 2.0 - (1.0 - LEAD) * 0.9));
        return {lerp(winA + v * winLen, icA + v * icLen, EA), lerp(winLo, icLo, EW), lerp(winHi, icHi, EW)};
    }

    CBox genieBounds(const CBox& win, const CBox& icon) {
        const double X0 = std::min(win.x, icon.x), Y0 = std::min(win.y, icon.y);
        const double X1 = std::max(win.x + win.w, icon.x + icon.w), Y1 = std::max(win.y + win.h, icon.y + icon.h);
        return CBox{X0, Y0, X1 - X0, Y1 - Y0}.expand(std::max(8.0, 0.04 * std::max(win.w, win.h)));
    }


    const std::string VERT_SRC = R"(#version 300 es
uniform mat3 proj;
in vec2 pos;
out vec2 v_pos;
void main() {
    gl_Position = vec4(proj * vec3(pos, 1.0), 1.0);
    v_pos = pos;
}
)";

    const std::string FRAG_HEAD = R"(#version 300 es
precision highp float;
uniform sampler2D tex;
uniform vec2 texSize;
uniform vec4 box;
uniform float alpha;
in vec2 v_pos;
layout(location = 0) out vec4 fragColor;

vec4 sampleArea(vec2 px, vec2 foot) {
    vec2 n = clamp(ceil(foot), vec2(1.0), vec2(4.0));
    vec2 st = foot / n;
    vec4 acc = vec4(0.0);
    for (int i = 0; i < 4; ++i) {
        if (float(i) >= n.x)
            break;
        for (int j = 0; j < 4; ++j) {
            if (float(j) >= n.y)
                break;
            vec2 o = (vec2(float(i), float(j)) + 0.5) * st - foot * 0.5;
            acc += texture(tex, (px + o) / texSize);
        }
    }
    return acc / (n.x * n.y);
}
)";

    const std::string GENIE_SRC = FRAG_HEAD + R"(
uniform vec4 win;
uniform vec4 icon;
uniform vec2 edges;
uniform vec3 funnel;
uniform int vertical;

void main() {
    vec2  p    = box.xy + v_pos * box.zw;
    float a    = vertical == 1 ? p.y : p.x;
    float x    = vertical == 1 ? p.x : p.y;
    float span = funnel.y - funnel.x;
    float u    = clamp((a - funnel.x) / span, 0.0, 1.0);
    float s    = u * u * (3.0 - 2.0 * u);
    float ds   = 6.0 * u * (1.0 - u) / span;
    float k    = funnel.z * s;
    float lo   = mix(win.z, icon.z, k);
    float hi   = mix(win.w, icon.w, k);
    float dlo  = (icon.z - win.z) * funnel.z * ds;
    float dhi  = (icon.w - win.w) * funnel.z * ds;
    float cov  = clamp((x - lo) / sqrt(1.0 + dlo * dlo) + 0.5, 0.0, 1.0) * clamp((hi - x) / sqrt(1.0 + dhi * dhi) + 0.5, 0.0, 1.0);
    cov *= clamp(a - edges.x + 0.5, 0.0, 1.0) * clamp(edges.y - a + 0.5, 0.0, 1.0);
    if (cov <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float len  = max(edges.y - edges.x, 0.001);
    float wid  = max(hi - lo, 0.001);
    float v    = clamp((a - edges.x) / len, 0.0, 1.0);
    float w    = clamp((x - lo) / wid, 0.0, 1.0);
    float ta   = mix(win.x, win.y, v);
    float tc   = mix(win.z, win.w, w);
    vec2  foot = vec2((win.w - win.z) / wid, (win.y - win.x) / len);
    vec2  px   = vertical == 1 ? vec2(tc, ta) : vec2(ta, tc);
    fragColor  = sampleArea(px, vertical == 1 ? foot : foot.yx) * (cov * alpha);
}
)";

    const std::string SHAPE_SRC = FRAG_HEAD + R"(
uniform vec4 shapeBox;
uniform vec4 dst;
uniform vec4 src;
uniform vec4 shape;
uniform vec4 container;
uniform vec4 accent;
uniform int matte;
uniform vec4 rbox;
uniform vec3 corner;
uniform float outside;

void main() {
    vec2  p  = box.xy + v_pos * box.zw;
    vec2  d  = p - (shapeBox.xy + shapeBox.zw * 0.5);
    float m  = max(shapeBox.z, shapeBox.w) * 0.5;
    float ra = shapeBox.z * 0.5 / m;
    float rb = shapeBox.w * 0.5 / m;
    float th = atan(d.y, d.x);
    float n  = shape.x;
    float r  = m * ra * rb / pow(pow(abs(cos(th)) * rb, n) + pow(abs(sin(th)) * ra, n), 1.0 / n) * (1.0 + shape.y * cos(9.0 * (th + shape.z)));
    float f  = length(d) - r;
    if (corner.z > 0.0) {
        vec2  hs  = rbox.zw * 0.5;
        vec2  q   = abs(p - (rbox.xy + hs));
        float rad = min(corner.x, min(hs.x, hs.y));
        vec2  k   = q - (hs - rad);
        vec2  km  = max(k, 0.0);
        float lp  = km.x + km.y > 0.0 ? pow(pow(km.x, corner.y) + pow(km.y, corner.y), 1.0 / corner.y) : 0.0;
        f         = mix(f, lp + min(max(k.x, k.y), 0.0) - rad, corner.z);
    }
    float g   = length(vec2(dFdx(f), dFdy(f)));
    float cov = clamp(0.5 - f / max(g, 0.0001), 0.0, 1.0);
    if (cov <= 0.0 && outside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float ca      = shape.w;
    vec4  content = ca > 0.0 || outside > 0.0 ? sampleArea(src.xy + (p - dst.xy) * src.zw / dst.zw, src.zw / dst.zw) : vec4(0.0);
    vec4  fill    = mix(accent, container, corner.z);
    vec4  col     = matte == 1 ? (ca > 0.0 ? content : vec4(0.0)) : content * ca + fill * (1.0 - ca);
    fragColor     = (col * cov + content * (outside * (1.0 - cov))) * alpha;
}
)";

    struct SGLProg {
        GLuint                                 prog   = 0;
        GLuint                                 vao    = 0;
        GLuint                                 vbo    = 0;
        bool                                   failed = false;
        std::unordered_map<std::string, GLint> locs;

        GLint                                  u(const std::string& name) {
            const auto IT = locs.find(name);
            if (IT != locs.end())
                return IT->second;
            const GLint L = glGetUniformLocation(prog, name.c_str());
            locs[name]    = L;
            return L;
        }
    };

    SGLProg     g_genieProg, g_shapeProg;
    std::string g_glError;

    GLuint      compileShader(GLenum type, const std::string& src) {
        const GLuint SH  = glCreateShader(type);
        const char*  PTR = src.c_str();
        glShaderSource(SH, 1, &PTR, nullptr);
        glCompileShader(SH);
        GLint ok = 0;
        glGetShaderiv(SH, GL_COMPILE_STATUS, &ok);
        if (!ok) {
            std::array<char, 2048> log{};
            glGetShaderInfoLog(SH, log.size(), nullptr, log.data());
            g_glError = log.data();
            glDeleteShader(SH);
            return 0;
        }
        return SH;
    }

    bool ensureProg(SGLProg& P, const std::string& frag, const std::string& vert = VERT_SRC) {
        if (P.prog)
            return true;
        if (P.failed)
            return false;
        const GLuint VS = compileShader(GL_VERTEX_SHADER, vert);
        const GLuint FS = VS ? compileShader(GL_FRAGMENT_SHADER, frag) : 0;
        if (!VS || !FS) {
            if (VS)
                glDeleteShader(VS);
            P.failed = true;
            return false;
        }
        P.prog = glCreateProgram();
        glAttachShader(P.prog, VS);
        glAttachShader(P.prog, FS);
        glBindAttribLocation(P.prog, 0, "pos");
        glLinkProgram(P.prog);
        glDetachShader(P.prog, VS);
        glDetachShader(P.prog, FS);
        glDeleteShader(VS);
        glDeleteShader(FS);
        GLint ok = 0;
        glGetProgramiv(P.prog, GL_LINK_STATUS, &ok);
        if (!ok) {
            std::array<char, 2048> log{};
            glGetProgramInfoLog(P.prog, log.size(), nullptr, log.data());
            g_glError = log.data();
            glDeleteProgram(P.prog);
            P.prog   = 0;
            P.failed = true;
            return false;
        }

        constexpr std::array<float, 8> QUAD = {0.F, 0.F, 0.F, 1.F, 1.F, 0.F, 1.F, 1.F};
        glGenVertexArrays(1, &P.vao);
        glBindVertexArray(P.vao);
        glGenBuffers(1, &P.vbo);
        glBindBuffer(GL_ARRAY_BUFFER, P.vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof(QUAD), QUAD.data(), GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        return true;
    }

    void destroyProg(SGLProg& P) {
        if (P.vbo)
            glDeleteBuffers(1, &P.vbo);
        if (P.vao)
            glDeleteVertexArrays(1, &P.vao);
        if (P.prog)
            glDeleteProgram(P.prog);
        P = SGLProg{};
    }

    template <typename F>
    bool drawProgV(SGLProg& P, const std::string& vert, const std::string& frag, SP<Render::ITexture> tex, const CBox& box, float alpha, bool flip, const PHLMONITOR& m,
                   F&& uniforms) {
        if (!tex || !Render::GL::g_pHyprOpenGL || box.w < 1 || box.h < 1 || !ensureProg(P, frag, vert))
            return false;

        g_pHyprRenderer->pushMonitorTransformEnabled(flip);
        eTransform TR = tex->m_transform;
        if (g_pHyprRenderer->monitorTransformEnabled())
            TR = Math::composeTransform(Math::wlTransformToHyprutils(Math::invertTransform(m->m_transform)), TR);
        const auto MAT = g_pHyprRenderer->projectBoxToTarget(box, TR);
        g_pHyprRenderer->popMonitorTransformEnabled();

        GLint prev = 0;
        glGetIntegerv(GL_CURRENT_PROGRAM, &prev);
        Render::GL::g_pHyprOpenGL->blend(true);
        Render::GL::g_pHyprOpenGL->scissor(sc<const pixman_box32*>(nullptr));

        glUseProgram(P.prog);
        glUniformMatrix3fv(P.u("proj"), 1, GL_TRUE, MAT.getMatrix().data());
        glUniform1i(P.u("tex"), 0);
        glUniform2f(P.u("texSize"), tex->m_size.x, tex->m_size.y);
        glUniform4f(P.u("box"), box.x, box.y, box.w, box.h);
        glUniform1f(P.u("alpha"), alpha);
        uniforms(P);

        glActiveTexture(GL_TEXTURE0);
        tex->bind();
        tex->setTexParameter(GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        tex->setTexParameter(GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        tex->setTexParameter(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        tex->setTexParameter(GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindVertexArray(P.vao);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        glBindVertexArray(0);
        tex->unbind();
        glUseProgram(prev);
        return true;
    }

    template <typename F>
    bool drawProg(SGLProg& P, const std::string& frag, SP<Render::ITexture> tex, const CBox& box, float alpha, bool flip, const PHLMONITOR& m, F&& uniforms) {
        return drawProgV(P, VERT_SRC, frag, tex, box, alpha, flip, m, std::forward<F>(uniforms));
    }

    const std::string PERSP_VERT = R"(#version 300 es
uniform mat3 proj;
uniform vec2 c00;
uniform vec2 c10;
uniform vec2 c01;
uniform vec2 c11;
uniform vec4 ws;
uniform vec4 box;
in vec2 pos;
out vec2 v_uv;
void main() {
    vec2  p = mix(mix(c00, c10, pos.x), mix(c01, c11, pos.x), pos.y);
    float w = mix(mix(ws.x, ws.y, pos.x), mix(ws.z, ws.w, pos.x), pos.y);
    vec3  n = proj * vec3((p - box.xy) / box.zw, 1.0);
    gl_Position = vec4(n.xy * w, 0.0, w);
    v_uv = pos;
}
)";

    const std::string PERSP_SRC = R"(#version 300 es
precision highp float;
uniform sampler2D tex;
uniform vec2 texSize;
uniform vec4 src;
uniform float alpha;
uniform float dim;
in vec2 v_uv;
layout(location = 0) out vec4 fragColor;

void main() {
    vec2 px   = src.xy + v_uv * src.zw;
    vec2 foot = clamp(fwidth(px), vec2(1.0), vec2(4.0));
    vec2 n    = ceil(foot);
    vec2 st   = foot / n;
    vec4 acc  = vec4(0.0);
    for (int i = 0; i < 4; ++i) {
        if (float(i) >= n.x)
            break;
        for (int j = 0; j < 4; ++j) {
            if (float(j) >= n.y)
                break;
            vec2 o = (vec2(float(i), float(j)) + 0.5) * st - foot * 0.5;
            acc += texture(tex, (px + o) / texSize);
        }
    }
    vec4 c    = acc / (n.x * n.y);
    fragColor = vec4(c.rgb * dim, c.a) * alpha;
}
)";

    SGLProg g_perspProg;

    bool drawGenieShader(SP<Render::ITexture> tex, const CBox& win, const CBox& icon, double c, const PHLMONITOR& m, bool flip, bool vertical, bool leadEnd, double alpha) {
        const double WA0 = vertical ? win.y : win.x, WA1 = vertical ? win.y + win.h : win.x + win.w;
        const double WLO = vertical ? win.x : win.y, WHI = vertical ? win.x + win.w : win.y + win.h;
        const double IA0 = vertical ? icon.y : icon.x, IA1 = vertical ? icon.y + icon.h : icon.x + icon.w;
        const double ILO = vertical ? icon.x : icon.y, IHI = vertical ? icon.x + icon.w : icon.y + icon.h;

        const double LEAD  = INOUT(clamp01(c / 0.6));
        const double TRAIL = INOUT(clamp01((c - 0.28) / 0.72));
        const double BEND  = INOUT(clamp01(c / 0.42));

        double       fs = leadEnd ? WA0 : WA1, fe = leadEnd ? IA0 : IA1;
        if (std::abs(fe - fs) < 1.0)
            fe = fs + (leadEnd ? 1.0 : -1.0);
        const double E0 = lerp(WA0, IA0, leadEnd ? TRAIL : LEAD);
        const double E1 = lerp(WA1, IA1, leadEnd ? LEAD : TRAIL);

        return drawProg(g_genieProg, GENIE_SRC, tex, genieBounds(win, icon), sc<float>(alpha), flip, m, [&](SGLProg& P) {
            glUniform4f(P.u("win"), WA0, WA1, WLO, WHI);
            glUniform4f(P.u("icon"), IA0, IA1, ILO, IHI);
            glUniform2f(P.u("edges"), E0, E1);
            glUniform3f(P.u("funnel"), fs, fe, BEND);
            glUniform1i(P.u("vertical"), vertical ? 1 : 0);
        });
    }

    void drawGenie(SP<Render::ITexture> tex, const CBox& win, const CBox& icon, double c, const PHLMONITOR& m, bool flip) {
        if (!tex || win.w < 1 || win.h < 1)
            return;

        const auto   TEXSIZE  = tex->m_size;
        const auto   SIDE     = sideFor(icon, m);
        const bool   VERTICAL = SIDE == SIDE_BOTTOM || SIDE == SIDE_TOP;
        const bool   LEADEND  = SIDE == SIDE_BOTTOM || SIDE == SIDE_RIGHT;
        const double LEN      = VERTICAL ? win.h : win.w;
        const double SPAN     = VERTICAL ? std::abs((icon.y + icon.h) - win.y) : std::abs((icon.x + icon.w) - win.x);
        const int    N        = g_cfg.strips > 0 ? g_cfg.strips : std::clamp(sc<int>(std::max(LEN, SPAN) / 2.0), 64, 420);
        const double ALPHA    = clamp01((1.0 - c) / 0.12);
        if (ALPHA <= 0.0)
            return;

        if (drawGenieShader(tex, win, icon, c, m, flip, VERTICAL, LEADEND, ALPHA))
            return;

        const CRegion FULL{0.0, 0.0, m->m_transformedSize.x, m->m_transformedSize.y};

        auto          row = [&](double v) {
            if (VERTICAL)
                return rowAt(win.y, win.h, win.x, win.x + win.w, icon.y, icon.h, icon.x, icon.x + icon.w, c, v, LEADEND);
            return rowAt(win.x, win.w, win.y, win.y + win.h, icon.x, icon.w, icon.y, icon.y + icon.h, c, v, LEADEND);
        };

        auto& rd = g_pHyprRenderer->m_renderData;

        SRow  prev = row(0.0);
        for (int i = 0; i < N; ++i) {
            const double V0 = sc<double>(i) / N, V1 = sc<double>(i + 1) / N;
            const SRow   cur = row(V1);
            const double LO = (prev.lo + cur.lo) / 2.0, HI = (prev.hi + cur.hi) / 2.0;
            const double A0 = prev.a, A1 = cur.a;
            prev            = cur;

            if (HI - LO < 0.5 || A1 - A0 <= 0.0)
                continue;

            CBox     dest;
            Vector2D uvTL, uvBR;
            if (VERTICAL) {
                dest = CBox{LO, A0, HI - LO, A1 - A0 + 1.0};
                uvTL = {win.x / TEXSIZE.x, (win.y + V0 * win.h) / TEXSIZE.y};
                uvBR = {(win.x + win.w) / TEXSIZE.x, (win.y + V1 * win.h) / TEXSIZE.y};
            } else {
                dest = CBox{A0, LO, A1 - A0 + 1.0, HI - LO};
                uvTL = {(win.x + V0 * win.w) / TEXSIZE.x, win.y / TEXSIZE.y};
                uvBR = {(win.x + V1 * win.w) / TEXSIZE.x, (win.y + win.h) / TEXSIZE.y};
            }

            rd.primarySurfaceUVTopLeft     = uvTL;
            rd.primarySurfaceUVBottomRight = uvBR;

            CTexPassElement::SRenderData data;
            data.tex           = tex;
            data.box           = dest;
            data.a             = sc<float>(ALPHA);
            data.allowCustomUV = true;
            data.damage        = FULL;
            data.flipEndFrame  = flip;
            g_pHyprRenderer->draw(data, FULL);
        }

        rd.primarySurfaceUVTopLeft     = Vector2D(-1, -1);
        rd.primarySurfaceUVBottomRight = Vector2D(-1, -1);
    }

    std::unordered_map<void*, std::array<SP<Render::IFramebuffer>, 2>> g_fbs;

    struct SFullDamage {
        CRegion saved;
        explicit SFullDamage(const PHLMONITOR& m) : saved(g_pHyprRenderer->m_renderData.damage.copy()) {
            g_pHyprRenderer->m_renderData.damage = CRegion{0.0, 0.0, m->m_transformedSize.x, m->m_transformedSize.y};
        }
        ~SFullDamage() {
            g_pHyprRenderer->m_renderData.damage = saved;
        }
    };

    SP<Render::IFramebuffer> ownFB(const PHLMONITOR& m, int pass, const Vector2D& size) {
        auto& slot = g_fbs[m.get()][std::clamp(pass, 0, 1)];
        if (!slot)
            slot = g_pHyprRenderer->createFB("genie");
        if (!slot)
            return nullptr;
        if (!slot->isAllocated() || slot->m_size != size) {
            slot->alloc(sc<int>(size.x), sc<int>(size.y), DRM_FORMAT_ABGR8888);
            slot->setImageDescription(m->workBufferImageDescription());
        }
        return slot;
    }

    void drawShape(SP<Render::ITexture> tex, const CBox& fullPx, const CBox& geoPx, const CBox& iconPx, double t, bool opening, const PHLMONITOR& m, bool flip, bool matte,
                   const SCorner& corner);
    SCorner cornerOf(const PHLWINDOW& w, const PHLMONITOR& m) {
        return SCorner{.radius = w->rounding() * m->m_scale, .power = std::max(1.0F, w->roundingPower()), .border = w->getRealBorderSize() * m->m_scale};
    }
    CBox windowGeoPx(const PHLWINDOW& w, const PHLMONITOR& m);

    class CGenieTransformer : public Render::IWindowTransformer {
      public:
        explicit CGenieTransformer(WP<SAnim> anim) : m_anim(anim) {}
        virtual ~CGenieTransformer() = default;

        virtual void preWindowRender(CSurfacePassElement::SRenderData* rd) override;

        virtual SP<Render::IFramebuffer> transform(SP<Render::IFramebuffer> in) override {
            const auto ANIM = m_anim.lock();
            if (m_pass || !ANIM || ANIM->done || !in || !in->getTexture())
                return in;

            const auto WINDOW  = ANIM->window.lock();
            const auto MONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (!WINDOW || !MONITOR)
                return in;

            const auto OUT = ownFB(MONITOR, m_calls++, in->m_size);
            if (!OUT)
                return in;

            const CBox WIN  = windowPixelBox(WINDOW, MONITOR);
            const CBox ICON = toMonitorPixels(ANIM->icon, MONITOR);

            {
                SFullDamage full(MONITOR);
                auto        guard = g_pHyprRenderer->bindTempFB(OUT);
                g_pHyprRenderer->draw(CClearPassElement::SClearData{CHyprColor(0, 0, 0, 0)});
                if (ANIM->style == 1)
                    drawShape(in->getTexture(), WIN, windowGeoPx(WINDOW, MONITOR), ICON, ANIM->t, true, MONITOR, false, m_calls > 1, cornerOf(WINDOW, MONITOR));
                else
                    drawGenie(in->getTexture(), WIN, ICON, ANIM->c, MONITOR, false);
            }

            return OUT;
        }

      private:
        WP<SAnim>                m_anim;
        bool                     m_pass = false;
        int                      m_calls = 0;
    };

    class CGenieCloseElement : public IPassElement {
      public:
        explicit CGenieCloseElement(WP<SAnim> anim) : m_anim(anim) {}
        virtual ~CGenieCloseElement() = default;

        virtual std::vector<UP<IPassElement>> draw() override {
            const auto ANIM    = m_anim.lock();
            const auto MONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (ANIM && !ANIM->done && ANIM->snapshot && MONITOR && ANIM->monitor == MONITOR)
            {
                if (ANIM->style == 1)
                    drawShape(ANIM->snapshot->getTexture(), ANIM->source, ANIM->geoPx, toMonitorPixels(ANIM->icon, MONITOR), ANIM->t, false, MONITOR, true, false, ANIM->corner);
                else
                    drawGenie(ANIM->snapshot->getTexture(), ANIM->source, toMonitorPixels(ANIM->icon, MONITOR), ANIM->c, MONITOR, true);
            }
            return {};
        }

        virtual bool needsLiveBlur() override {
            return false;
        }
        virtual bool needsPrecomputeBlur() override {
            return false;
        }
        virtual const char* passName() override {
            return "CGenieCloseElement";
        }
        virtual ePassElementType type() override {
            return EK_CUSTOM;
        }
        virtual bool disableSimplification() override {
            return true;
        }

      private:
        WP<SAnim> m_anim;
    };

    bool standaloneRender(const CSurfacePassElement::SRenderData* rd, const PHLWINDOW& w);

    class CHideTransformer : public Render::IWindowTransformer {
      public:
        explicit CHideTransformer(PHLWINDOWREF w) : m_w(w) {}
        virtual ~CHideTransformer() = default;

        virtual void preWindowRender(CSurfacePassElement::SRenderData* rd) override {
            m_calls = 0;
            m_pass  = standaloneRender(rd, m_w.lock());
        }

        virtual SP<Render::IFramebuffer> transform(SP<Render::IFramebuffer> in) override {
            if (m_pass)
                return in;
            const auto MONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (!MONITOR)
                return in;
            const auto OUT = ownFB(MONITOR, m_calls++, in->m_size);
            if (!OUT)
                return in;
            SFullDamage full(MONITOR);
            auto        guard = g_pHyprRenderer->bindTempFB(OUT);
            g_pHyprRenderer->draw(CClearPassElement::SClearData{CHyprColor(0, 0, 0, 0)});
            return OUT;
        }

      private:
        PHLWINDOWREF m_w;
        bool         m_pass  = false;
        int          m_calls = 0;
    };

    void removeTransformer(const PHLWINDOWREF& window, Render::IWindowTransformer*& ptr) {
        if (!ptr)
            return;
        if (const auto W = window.lock()) {
            const auto P = ptr;
            std::erase_if(W->m_transformers, [P](const auto& t) { return t.get() == P; });
            g_pHyprRenderer->damageWindow(W);
        }
        ptr = nullptr;
    }

    void detachTransformer(SAnim& anim) {
        removeTransformer(anim.window, anim.transformer);
        removeTransformer(anim.window, anim.hider);
    }

    void warpWindow(const PHLWINDOW& w) {
        w->finishAnimation();
        for (int i = 0; i < Desktop::View::WINDOW_ALPHA_LAST; ++i)
            w->alpha(sc<Desktop::View::eWindowAlpha>(i))->warp();
    }

    std::string windowAddress(const PHLWINDOW& w) {
        return std::format("0x{:x}", rc<uintptr_t>(w.get()));
    }

    PHLWINDOW windowByAddress(const std::string& s) {
        uintptr_t addr = 0;
        try {
            addr = std::stoull(s, nullptr, 16);
        } catch (...) { return nullptr; }
        for (auto const& w : Desktop::windowState()->windows()) {
            if (rc<uintptr_t>(w.get()) == addr)
                return w;
        }
        return nullptr;
    }

    void damageAnim(SAnim& anim, const PHLMONITOR& m) {
        CBox win;
        if (anim.opening) {
            const auto W = anim.window.lock();
            if (!W)
                return;
            win = W->getFullWindowBoundingBox();
        } else {
            win = anim.source.copy().scale(1.0 / m->m_scale).translate(m->m_position);
        }

        const CBox NOW = genieBounds(win, anim.icon);
        if (!anim.lastDamage.empty())
            g_pHyprRenderer->damageBox(anim.lastDamage);
        g_pHyprRenderer->damageBox(NOW);
        anim.lastDamage = NOW;
    }

    std::optional<CBox> iconForKeys(const std::vector<std::string>& keys) {
        for (auto const& ic : g_icons) {
            if (sameKeys(ic.keys, keys))
                return ic.rect;
        }
        return std::nullopt;
    }

    std::optional<CBox> iconForWindow(const PHLWINDOW& w) {
        for (auto const& o : g_origins) {
            if (o.window.lock() == w) {
                if (auto r = iconForKeys(o.keys))
                    return r;
                if (o.fromDock)
                    return o.rect;
                break;
            }
        }
        for (auto const& ic : g_icons) {
            if (windowMatches(w, ic.keys))
                return ic.rect;
        }
        return std::nullopt;
    }

    bool animatable(const PHLWINDOW& w) {
        if (!w || !w->m_workspace || !w->m_workspace->isVisible())
            return false;
        if (w->isX11OverrideRedirect() || w->parent())
            return false;
        if (Fullscreen::controller()->isFullscreen(w))
            return false;
        if (w->m_ruleApplicator->noAnim().valueOrDefault())
            return false;
        return true;
    }

    SP<SAnim> animFor(const PHLWINDOW& w, bool opening) {
        for (auto const& a : g_anims) {
            if (!a->done && a->opening == opening && a->window.lock() == w)
                return a;
        }
        return nullptr;
    }

    SP<SAnim> startOpen(const PHLWINDOW& w, const CBox& icon, const PHLMONITOR& monitor, int warpMs);

    void openTiledFromDock(const PHLWINDOW& w) {
        const auto MONITOR = w->m_monitor.lock();
        if (!MONITOR)
            return;
        for (auto const& ic : g_icons) {
            if (!windowMatches(w, ic.keys) || !iconOnMonitor(ic.rect, MONITOR))
                continue;
            g_origins.push_back({w, ic.keys, ic.rect, true});
            startOpen(w, ic.rect, MONITOR, 0);
            return;
        }
    }

    void onWindowOpen(PHLWINDOW w) {
        const auto NOW = Clock::now();
        std::erase_if(g_arms, [&](const SArm& a) { return NOW - a.at > std::chrono::seconds(10); });
        std::erase_if(g_origins, [](const SOrigin& o) { return !o.window.lock(); });

        if (!g_cfg.open || !animatable(w))
            return;

        auto it = std::ranges::find_if(g_arms, [&](const SArm& a) { return windowMatches(w, a.keys); });
        if (it == g_arms.end() && g_arms.size() == 1 && g_arms.front().fromDock && NOW - g_arms.front().at < std::chrono::milliseconds(3000))
            it = g_arms.begin();
        if (it == g_arms.end()) {
            if (g_cfg.tiled && !w->m_isFloating)
                openTiledFromDock(w);
            return;
        }

        const SArm ARM = *it;
        g_arms.erase(it);

        const auto MONITOR = w->m_monitor.lock();
        if (!MONITOR || !iconOnMonitor(ARM.rect, MONITOR))
            return;

        g_origins.push_back({w, ARM.keys, ARM.rect, ARM.fromDock});
        startOpen(w, ARM.rect, MONITOR, 0);
    }

    SP<SAnim> startOpen(const PHLWINDOW& w, const CBox& icon, const PHLMONITOR& monitor, int warpMs) {
        warpWindow(w);

        auto anim        = makeShared<SAnim>();
        anim->opening    = true;
        anim->window     = w;
        anim->monitor    = monitor;
        anim->icon       = icon;
        anim->start      = Clock::now();
        anim->warpUntil  = anim->start + std::chrono::milliseconds(warpMs);
        anim->durationMs = g_cfg.openMs;
        anim->c          = 1.0;
        anim->style      = g_cfg.style;

        auto transformer  = makeUnique<CGenieTransformer>(anim);
        anim->transformer = transformer.get();
        w->m_transformers.emplace_back(std::move(transformer));

        g_anims.push_back(anim);
        g_pHyprRenderer->damageMonitor(monitor);
        return anim;
    }

    std::string dispatchLua(const std::string& lua) {
        return HyprlandAPI::invokeHyprctlCommand("dispatch", lua);
    }

    std::string minimizeWindow(const PHLWINDOW& w) {
        if (!w || !w->m_isMapped || !w->m_workspace)
            return "no such window";
        if (w->m_workspace->m_isSpecialWorkspace)
            return "already hidden";

        if (const auto OPENING = animFor(w, true)) {
            detachTransformer(*OPENING);
            OPENING->done = true;
        }

        const auto MONITOR = w->m_monitor.lock();
        const auto ICON    = iconForWindow(w);
        const bool ANIMATE = g_cfg.minimize && ICON && MONITOR && iconOnMonitor(*ICON, MONITOR) && animatable(w);

        if (ANIMATE) {
            const auto SNAPSHOT = g_pHyprRenderer->makeSnapshotFB(w);
            if (SNAPSHOT && SNAPSHOT->getTexture()) {
                auto anim        = makeShared<SAnim>();
                anim->opening    = false;
                anim->window     = w;
                anim->monitor    = MONITOR;
                anim->icon       = *ICON;
                anim->source     = windowPixelBox(w, MONITOR);
                anim->geoPx      = windowGeoPx(w, MONITOR);
                anim->corner     = cornerOf(w, MONITOR);
                anim->snapshot   = SNAPSHOT;
                anim->start      = Clock::now();
                anim->durationMs = g_cfg.closeMs;
                anim->c          = 0.0;
                anim->style      = g_cfg.style;

                auto hider  = makeUnique<CHideTransformer>(w);
                anim->hider = hider.get();
                w->m_transformers.emplace_back(std::move(hider));

                g_anims.push_back(anim);
                g_pHyprRenderer->damageMonitor(MONITOR);
            }
        }

        return dispatchLua(std::format("hl.dsp.window.move({{ window = \"address:{}\", workspace = \"special:minimized\", follow = false }})", windowAddress(w)));
    }

    std::string restoreWindow(const PHLWINDOW& w) {
        if (!w || !w->m_isMapped)
            return "no such window";

        for (auto const& a : g_anims) {
            if (!a->done && a->window.lock() == w) {
                detachTransformer(*a);
                a->done = true;
            }
        }

        const auto TARGET = Desktop::focusState()->monitor();
        if (!TARGET || !TARGET->m_activeWorkspace)
            return "no monitor";

        const auto ADDR = windowAddress(w);
        dispatchLua(std::format("hl.dsp.window.move({{ window = \"address:{}\", workspace = {}, follow = true }})", ADDR, TARGET->m_activeWorkspace->m_id));
        dispatchLua(std::format("hl.dsp.focus({{ window = \"address:{}\" }})", ADDR));

        const auto MONITOR = w->m_monitor.lock();
        const auto ICON    = iconForWindow(w);
        if (g_cfg.minimize && ICON && MONITOR && iconOnMonitor(*ICON, MONITOR) && animatable(w))
            startOpen(w, *ICON, MONITOR, 120);

        return "ok";
    }

    const SBezier DECEL{0.05, 0.7, 0.1, 1.0};

    struct SFlightCfg {
        float flyMs     = 560.F;
        float backMs    = 460.F;
        float recedeMs  = 440.F;
        float returnMs  = 420.F;
        float scale     = 0.86F;
        float alpha     = 0.5F;
    } g_fly;

    CBox lerpBox(const CBox& a, const CBox& b, double t) {
        return CBox{lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.w, b.w, t), lerp(a.h, b.h, t)};
    }

    Vector2D windowOffset(const PHLWINDOW& w) {
        return (w->m_pinned || !w->m_workspace ? Vector2D{} : w->m_workspace->m_renderOffset->value()) + w->m_floatingOffset;
    }

    CBox windowGeoLogical(const PHLWINDOW& w) {
        return CBox{w->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT) + windowOffset(w), w->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT)};
    }

    CBox windowFullLogical(const PHLWINDOW& w) {
        return w->getFullWindowBoundingBox().translate(windowOffset(w));
    }

    CBox mapFull(const CBox& geo, const CBox& full, const CBox& target) {
        const double SX = target.w / std::max(1.0, geo.w), SY = target.h / std::max(1.0, geo.h);
        return CBox{target.x + (full.x - geo.x) * SX, target.y + (full.y - geo.y) * SY, full.w * SX, full.h * SY};
    }

    void drawSub(SP<Render::ITexture> tex, const CBox& srcPx, const CBox& destPx, float alpha, bool flip, const PHLMONITOR& m) {
        if (!tex || srcPx.w < 1 || srcPx.h < 1 || destPx.w < 0.5 || destPx.h < 0.5 || alpha <= 0.F)
            return;
        const auto    SIZE = tex->m_size;
        const CRegion FULL{0.0, 0.0, m->m_transformedSize.x, m->m_transformedSize.y};
        auto&         rd               = g_pHyprRenderer->m_renderData;
        rd.primarySurfaceUVTopLeft     = {srcPx.x / SIZE.x, srcPx.y / SIZE.y};
        rd.primarySurfaceUVBottomRight = {(srcPx.x + srcPx.w) / SIZE.x, (srcPx.y + srcPx.h) / SIZE.y};
        CTexPassElement::SRenderData data;
        data.tex           = tex;
        data.box           = destPx;
        data.a             = alpha;
        data.allowCustomUV = true;
        data.damage        = FULL;
        data.flipEndFrame  = flip;
        g_pHyprRenderer->draw(data, FULL);
        rd.primarySurfaceUVTopLeft     = Vector2D(-1, -1);
        rd.primarySurfaceUVBottomRight = Vector2D(-1, -1);
    }

    bool standaloneRender(const CSurfacePassElement::SRenderData* rd, const PHLWINDOW& w) {
        if (!rd || !w)
            return false;
        const auto MON = rd->pMonitor.lock();
        if (!MON)
            return false;
        const auto AT  = rd->pos - MON->m_position;
        const auto EXP = w->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT) + windowOffset(w) - MON->m_position;
        return std::abs(AT.x) < 0.5 && std::abs(AT.y) < 0.5 && (std::abs(EXP.x) >= 0.5 || std::abs(EXP.y) >= 0.5);
    }

    void CGenieTransformer::preWindowRender(CSurfacePassElement::SRenderData* rd) {
        m_calls         = 0;
        const auto ANIM = m_anim.lock();
        m_pass          = ANIM && standaloneRender(rd, ANIM->window.lock());
    }

    CBox windowGeoPx(const PHLWINDOW& w, const PHLMONITOR& m) {
        return windowGeoLogical(w).translate(-m->m_position).scale(m->m_scale);
    }

    double springAt(double sec, double z, double k) {
        const double W0 = std::sqrt(k);
        if (z >= 1.0)
            return 1.0 - std::exp(-W0 * sec) * (1.0 + W0 * sec);
        const double WD = W0 * std::sqrt(1.0 - z * z);
        return 1.0 - std::exp(-z * W0 * sec) * (std::cos(WD * sec) + z * W0 / WD * std::sin(WD * sec));
    }

    void drawShape(SP<Render::ITexture> tex, const CBox& fullPx, const CBox& geoPx, const CBox& iconPx, double t, bool opening, const PHLMONITOR& m, bool flip, bool matte,
                   const SCorner& corner) {
        if (!tex || geoPx.w < 1 || geoPx.h < 1)
            return;

        if (!opening && t >= 1.0)
            return;

        const double   U     = opening ? clamp01(t) : 1.0 - clamp01(t);
        const double   A     = EMPH_DECEL(clamp01(U / 0.42));
        const double   BT    = clamp01((U - 0.24) / 0.76);
        const double   B     = springAt(BT, 0.72, 110.0);
        const Vector2D IC    = iconPx.middle(), WC = geoPx.middle();
        const double   D0    = std::min(iconPx.w, iconPx.h) * 0.8;
        const double   D1    = std::max(D0 * 1.5, 0.42 * std::min(geoPx.w, geoPx.h));
        const Vector2D SCN   = IC + (WC - IC) * A;
        const double   SD    = lerp(D0, D1, A);
        const CBox     SQ{SCN.x - SD / 2.0, SCN.y - SD / 2.0, SD, SD};
        const CBox     BOX   = lerpBox(SQ, geoPx, B);
        if (BOX.w < 1 || BOX.h < 1)
            return;
        const double   RR0      = clamp01((B - 0.05) / 0.7);
        const double   RR       = RR0 * RR0 * (3.0 - 2.0 * RR0);
        const double   contentA = clamp01((U - 0.45) / 0.3);
        const double   outsideA = clamp01((U - 0.7) / 0.3) * RR;
        const double   ALPHA    = clamp01(U / 0.06);
        const CBox     DST      = mapFull(geoPx, fullPx, BOX);
        const double   N        = 2.0, AMP = 0.085, ROT = -1.6 * (1.0 - A) - 0.25 * (1.0 - RR);
        const double CX = BOX.x + BOX.w / 2.0, CY = BOX.y + BOX.h / 2.0, RA = BOX.w / 2.0, RB = BOX.h / 2.0;

        const double BS   = corner.border * BOX.w / std::max(1.0, geoPx.w);
        const CBox   RBOX = BOX.copy().expand(BS);
        CBox         QUAD = BOX.copy().expand(0.1 * std::max(BOX.w, BOX.h) + 2.0);
        if (outsideA > 0.0) {
            const double X0 = std::min(QUAD.x, DST.x), Y0 = std::min(QUAD.y, DST.y);
            const double X1 = std::max(QUAD.x + QUAD.w, DST.x + DST.w), Y1 = std::max(QUAD.y + QUAD.h, DST.y + DST.h);
            QUAD            = CBox{X0, Y0, X1 - X0, Y1 - Y0};
        }
        const bool DREW = drawProg(g_shapeProg, SHAPE_SRC, tex, QUAD, sc<float>(ALPHA), flip, m, [&](SGLProg& P) {
            const auto& K  = g_cfg.container;
            const auto& AC = g_cfg.accent;
            glUniform4f(P.u("accent"), AC.r * AC.a, AC.g * AC.a, AC.b * AC.a, AC.a);
            glUniform4f(P.u("shapeBox"), BOX.x, BOX.y, BOX.w, BOX.h);
            glUniform4f(P.u("dst"), DST.x, DST.y, std::max(1.0, DST.w), std::max(1.0, DST.h));
            glUniform4f(P.u("src"), fullPx.x, fullPx.y, fullPx.w, fullPx.h);
            glUniform4f(P.u("shape"), N, AMP, ROT, contentA);
            glUniform4f(P.u("container"), K.r * K.a, K.g * K.a, K.b * K.a, K.a);
            glUniform1i(P.u("matte"), matte ? 1 : 0);
            glUniform4f(P.u("rbox"), RBOX.x, RBOX.y, RBOX.w, RBOX.h);
            glUniform3f(P.u("corner"), corner.radius + BS, corner.power, RR);
            glUniform1f(P.u("outside"), outsideA);
        });
        if (DREW)
            return;

        constexpr int         PTS = 160;
        std::array<Vector2D, PTS> poly;
        for (int i = 0; i < PTS; ++i) {
            const double TH = sc<double>(i) / PTS * 2.0 * M_PI;
            const double C = std::abs(std::cos(TH)), S = std::abs(std::sin(TH));
            const double R = std::pow(std::pow(C / RA, N) + std::pow(S / RB, N), -1.0 / N) * (1.0 + AMP * std::cos(9.0 * (TH + ROT)));
            poly[i]        = {CX + std::cos(TH) * R, CY + std::sin(TH) * R};
        }

        double minY = poly[0].y, maxY = poly[0].y;
        for (auto const& p : poly) {
            minY = std::min(minY, p.y);
            maxY = std::max(maxY, p.y);
        }

        const CRegion FULL{0.0, 0.0, m->m_transformedSize.x, m->m_transformedSize.y};
        const double  RH   = std::max(1.0, (maxY - minY) / 260.0);
        const auto    SIZE = tex->m_size;
        auto&         rd   = g_pHyprRenderer->m_renderData;

        auto emit = [&](double x0, double x1, double y0, double y1) {
            const CBox R{x0, y0, x1 - x0, y1 - y0};
            if (R.w < 0.5 || R.h < 0.5)
                return;
            if (!matte && contentA < 1.0)
                g_pHyprRenderer->draw(CRectPassElement::SRectData{.box = R, .color = g_cfg.container}, FULL);
            if (contentA <= 0.0)
                return;
            const double SX = fullPx.w / std::max(1.0, DST.w), SY = fullPx.h / std::max(1.0, DST.h);
            const double U0 = fullPx.x + (R.x - DST.x) * SX, V0 = fullPx.y + (R.y - DST.y) * SY;
            rd.primarySurfaceUVTopLeft     = {U0 / SIZE.x, V0 / SIZE.y};
            rd.primarySurfaceUVBottomRight = {(U0 + R.w * SX) / SIZE.x, (V0 + R.h * SY) / SIZE.y};
            CTexPassElement::SRenderData data;
            data.tex           = tex;
            data.box           = R;
            data.a             = matte ? 1.F : sc<float>(contentA);
            data.allowCustomUV = true;
            data.damage        = FULL;
            data.flipEndFrame  = flip;
            g_pHyprRenderer->draw(data, FULL);
            rd.primarySurfaceUVTopLeft     = Vector2D(-1, -1);
            rd.primarySurfaceUVBottomRight = Vector2D(-1, -1);
        };

        bool   open = false;
        double runX0 = 0, runX1 = 0, runY = 0;
        std::vector<double> xs;
        for (double y = minY; y < maxY; y += RH) {
            const double YC = y + RH / 2.0;
            xs.clear();
            for (int i = 0; i < PTS; ++i) {
                const auto& A = poly[i];
                const auto& B = poly[(i + 1) % PTS];
                if ((A.y <= YC && YC < B.y) || (B.y <= YC && YC < A.y))
                    xs.push_back(A.x + (YC - A.y) * (B.x - A.x) / (B.y - A.y));
            }
            std::ranges::sort(xs);
            if (xs.size() == 2) {
                if (open && std::abs(xs[0] - runX0) < 0.6 && std::abs(xs[1] - runX1) < 0.6)
                    continue;
                if (open)
                    emit(runX0, runX1, runY, y);
                open  = true;
                runX0 = xs[0];
                runX1 = xs[1];
                runY  = y;
                continue;
            }
            if (open) {
                emit(runX0, runX1, runY, y);
                open = false;
            }
            for (size_t i = 0; i + 1 < xs.size(); i += 2)
                emit(xs[i], xs[i + 1], y, y + RH);
        }
        if (open)
            emit(runX0, runX1, runY, maxY);
    }



    bool busyElsewhere(const PHLWINDOW& w);

    struct SMove {
        PHLWINDOWREF                window;
        PHLMONITORREF               monitor;
        CBox                        fromFull;
        CBox                        fromGeo;
        Clock::time_point           start;
        float                       durMs = 450.F;
        int                         style = 0;
        double                      u     = 0.0;
        Render::IWindowTransformer* transformer = nullptr;
        CBox                        lastDamage;
        bool                        done = false;
    };
    std::vector<SP<SMove>> g_moves;

    struct SGoal {
        PHLWINDOWREF    window;
        CBox            goal;
        PHLWORKSPACEREF workspace;
    };
    std::unordered_map<uintptr_t, SGoal> g_goals;

    SP<SMove> moveFor(const PHLWINDOW& w) {
        for (auto const& mv : g_moves) {
            if (!mv->done && mv->window.lock() == w)
                return mv;
        }
        return nullptr;
    }

    CBox moveGeoAt(const SMove& mv, const CBox& toGeo) {
        if (mv.style == 1)
            return lerpBox(mv.fromGeo, toGeo, springAt(mv.u, 0.75, 70.0));
        return lerpBox(mv.fromGeo, toGeo, INOUT(mv.u));
    }

    void drawMove(SP<Render::ITexture> tex, const SMove& mv, const PHLWINDOW& w, const PHLMONITOR& m, bool matte) {
        const CBox TOFULL   = windowPixelBox(w, m);
        const CBox TOGEO    = windowGeoPx(w, m);
        const CBox FROMFULL = toMonitorPixels(mv.fromFull, m);
        const CBox FROMGEO  = toMonitorPixels(mv.fromGeo, m);

        if (mv.style != 1) {
            const auto   C = TOFULL.middle(), I = FROMFULL.middle();
            const double DX = std::abs(I.x - C.x) - TOFULL.w / 2.0, DY = std::abs(I.y - C.y) - TOFULL.h / 2.0;
            const bool   VERT = DY >= DX;
            const bool   LEAD = VERT ? I.y > C.y : I.x > C.x;
            if (drawGenieShader(tex, TOFULL, FROMFULL, 1.0 - mv.u, m, false, VERT, LEAD, 1.0))
                return;
            drawSub(tex, TOFULL, lerpBox(FROMFULL, TOFULL, INOUT(mv.u)), 1.F, false, m);
            return;
        }

        const double P    = springAt(mv.u, 0.75, 70.0);
        const double BUMP = std::sin(M_PI * clamp01(P));
        const CBox   B0   = lerpBox(FROMGEO, TOGEO, P);
        const double SCL  = 1.0 - 0.14 * BUMP;
        const CBox   BOX{B0.middle().x - B0.w * SCL / 2.0, B0.middle().y - B0.h * SCL / 2.0, B0.w * SCL, B0.h * SCL};
        if (BOX.w < 1 || BOX.h < 1)
            return;
        const double RR   = 1.0 - 0.45 * BUMP;
        const double DIRX = TOGEO.middle().x - FROMGEO.middle().x, DIRY = TOGEO.middle().y - FROMGEO.middle().y;
        const double DIR  = (std::abs(DIRX) >= std::abs(DIRY) ? DIRX : DIRY) >= 0 ? -1.0 : 1.0;
        const double ROT  = DIR * 1.4 * clamp01(P);
        const CBox   DST  = mapFull(TOGEO, TOFULL, BOX);
        const SCorner CR  = cornerOf(w, m);
        const CBox   QUAD = BOX.copy().expand(0.1 * std::max(BOX.w, BOX.h) + 2.0);
        const bool   DREW = drawProg(g_shapeProg, SHAPE_SRC, tex, QUAD, 1.F, false, m, [&](SGLProg& PR) {
            const auto& K  = g_cfg.container;
            const auto& AC = g_cfg.accent;
            glUniform4f(PR.u("accent"), AC.r * AC.a, AC.g * AC.a, AC.b * AC.a, AC.a);
            glUniform4f(PR.u("shapeBox"), BOX.x, BOX.y, BOX.w, BOX.h);
            glUniform4f(PR.u("dst"), DST.x, DST.y, std::max(1.0, DST.w), std::max(1.0, DST.h));
            glUniform4f(PR.u("src"), TOFULL.x, TOFULL.y, TOFULL.w, TOFULL.h);
            glUniform4f(PR.u("shape"), 2.0, 0.06, ROT, 1.0);
            glUniform4f(PR.u("container"), K.r * K.a, K.g * K.a, K.b * K.a, K.a);
            glUniform1i(PR.u("matte"), matte ? 1 : 0);
            glUniform4f(PR.u("rbox"), BOX.x, BOX.y, BOX.w, BOX.h);
            glUniform3f(PR.u("corner"), CR.radius, CR.power, RR);
            glUniform1f(PR.u("outside"), 0.0);
        });
        if (!DREW)
            drawSub(tex, TOFULL, DST, 1.F, false, m);
    }

    class CMoveTransformer : public Render::IWindowTransformer {
      public:
        explicit CMoveTransformer(WP<SMove> mv) : m_move(mv) {}
        virtual ~CMoveTransformer() = default;

        virtual void preWindowRender(CSurfacePassElement::SRenderData* rd) override {
            m_calls         = 0;
            const auto MV   = m_move.lock();
            m_pass          = MV && standaloneRender(rd, MV->window.lock());
        }

        virtual SP<Render::IFramebuffer> transform(SP<Render::IFramebuffer> in) override {
            const auto MV = m_move.lock();
            if (m_pass || !MV || MV->done || !in || !in->getTexture())
                return in;
            const auto WINDOW  = MV->window.lock();
            const auto MONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (!WINDOW || !MONITOR)
                return in;
            const auto OUT = ownFB(MONITOR, m_calls++, in->m_size);
            if (!OUT)
                return in;
            {
                SFullDamage full(MONITOR);
                auto        guard = g_pHyprRenderer->bindTempFB(OUT);
                g_pHyprRenderer->draw(CClearPassElement::SClearData{CHyprColor(0, 0, 0, 0)});
                drawMove(in->getTexture(), *MV, WINDOW, MONITOR, m_calls > 1);
            }
            return OUT;
        }

      private:
        WP<SMove> m_move;
        bool      m_pass  = false;
        int       m_calls = 0;
    };

    void endMove(SMove& mv) {
        if (mv.transformer)
            removeTransformer(mv.window, mv.transformer);
        mv.done = true;
        if (!mv.lastDamage.empty())
            g_pHyprRenderer->damageBox(mv.lastDamage);
    }

    bool dragging() {
        return g_layoutManager && g_layoutManager->dragController() && g_layoutManager->dragController()->mode() != MBIND_INVALID;
    }

    void startMove(const PHLWINDOW& w, const PHLMONITOR& m, const CBox& prevGoal) {
        const CBox CURGEO  = windowGeoLogical(w);
        const CBox CURFULL = windowFullLogical(w);
        const auto OFF     = windowOffset(w);
        CBox       fromGeo = w->positionAnimation()->isBeingAnimated() ? CURGEO : prevGoal.copy().translate(OFF);
        CBox       fromFull = mapFull(CURGEO, CURFULL, fromGeo);
        if (const auto OLD = moveFor(w)) {
            const CBox TOGEO = windowGeoLogical(w);
            fromGeo          = moveGeoAt(*OLD, TOGEO);
            fromFull         = mapFull(windowGeoLogical(w), windowFullLogical(w), fromGeo);
            endMove(*OLD);
        }
        w->positionAnimation()->warp();
        w->sizeAnimation()->warp();

        auto mv      = makeShared<SMove>();
        mv->window   = w;
        mv->monitor  = m;
        mv->fromGeo  = fromGeo;
        mv->fromFull = fromFull;
        mv->start    = Clock::now();
        mv->durMs    = g_cfg.moveMs;
        mv->style    = g_cfg.style;

        auto tr         = makeUnique<CMoveTransformer>(mv);
        mv->transformer = tr.get();
        w->m_transformers.emplace_back(std::move(tr));
        g_moves.push_back(mv);
        g_pHyprRenderer->damageMonitor(m);
    }

    void scanMoves(const PHLMONITOR& m) {
        if (!g_cfg.move) {
            if (!g_goals.empty())
                g_goals.clear();
            return;
        }
        const bool DRAG = dragging();
        for (auto const& w : Desktop::windowState()->windows()) {
            if (!w->m_isMapped || w->isHidden() || !w->m_workspace || w->m_monitor.lock() != m)
                continue;
            const CBox GOAL = w->geometricBox(Desktop::View::IGeometric::GEOMETRIC_GOAL);
            const auto KEY  = rc<uintptr_t>(w.get());
            auto       it   = g_goals.find(KEY);
            if (it == g_goals.end() || it->second.window.lock() != w) {
                g_goals[KEY] = {w, GOAL, w->m_workspace};
                continue;
            }
            auto&      g      = it->second;
            const CBox PREV   = g.goal;
            const bool SAMEWS = g.workspace.lock() == w->m_workspace;
            g.goal            = GOAL;
            g.workspace       = w->m_workspace;
            if (!SAMEWS)
                continue;
            const double D = std::hypot(GOAL.x - PREV.x, GOAL.y - PREV.y);
            if (D < 24.0)
                continue;
            if (DRAG || w->m_isFloating || w->m_pinned || !w->m_workspace->isVisible() || w->m_workspace->m_renderOffset->isBeingAnimated() || !animatable(w))
                continue;
            if (animFor(w, true) || busyElsewhere(w))
                continue;
            startMove(w, m, PREV);
        }
        if (g_goals.size() > 256)
            std::erase_if(g_goals, [](const auto& kv) { return !kv.second.window.lock(); });
    }

    void tickMoves(const PHLMONITOR& m, Clock::time_point now) {
        for (auto const& mv : g_moves) {
            if (mv->done || mv->monitor.lock() != m)
                continue;
            const auto W = mv->window.lock();
            if (!W) {
                mv->done = true;
                continue;
            }
            mv->u           = clamp01(std::chrono::duration<double, std::milli>(now - mv->start).count() / std::max(1.F, mv->durMs));
            const CBox TO   = windowFullLogical(W);
            const double X0 = std::min(TO.x, mv->fromFull.x), Y0 = std::min(TO.y, mv->fromFull.y);
            const double X1 = std::max(TO.x + TO.w, mv->fromFull.x + mv->fromFull.w), Y1 = std::max(TO.y + TO.h, mv->fromFull.y + mv->fromFull.h);
            const CBox   DMG = CBox{X0, Y0, X1 - X0, Y1 - Y0}.expand(0.08 * std::max(X1 - X0, Y1 - Y0));
            if (!mv->lastDamage.empty())
                g_pHyprRenderer->damageBox(mv->lastDamage);
            g_pHyprRenderer->damageBox(DMG);
            mv->lastDamage = DMG;
            if (mv->u >= 1.0)
                endMove(*mv);
        }
        std::erase_if(g_moves, [](const SP<SMove>& mv) { return mv->done; });
    }

    struct SFlight {
        PHLWINDOWREF                window;
        PHLMONITORREF               monitor;
        SP<Render::IFramebuffer>    snapshot;
        CBox                        srcPx;
        CBox                        geo;
        CBox                        full;
        CBox                        fromGeo;
        CBox                        toGeo;
        bool                        toTile = true;
        Clock::time_point           start;
        float                       delayMs = 0.F;
        float                       durMs   = 560.F;
        double                      e       = 0.0;
        bool                        flying  = true;
        Render::IWindowTransformer* hider   = nullptr;
        CBox                        lastDamage;
        bool                        done = false;
    };
    std::vector<SP<SFlight>> g_flights;

    CBox flightRect(const SFlight& f) {
        CBox geoNow = lerpBox(f.fromGeo, f.toGeo, f.e);
        if (f.toTile) {
            const auto MON = f.monitor.lock();
            if (MON)
                geoNow.y -= MON->m_size.y * 0.04 * std::sin(M_PI * f.e);
        }
        return mapFull(f.geo, f.full, geoNow);
    }

    class CFlightElement : public IPassElement {
      public:
        explicit CFlightElement(WP<SFlight> f) : m_f(f) {}
        virtual ~CFlightElement() = default;

        virtual std::vector<UP<IPassElement>> draw() override {
            const auto F   = m_f.lock();
            const auto MON = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (F && F->flying && !F->done && F->snapshot && MON && F->monitor == MON)
                drawSub(F->snapshot->getTexture(), F->srcPx, toMonitorPixels(flightRect(*F), MON), 1.F, true, MON);
            return {};
        }
        virtual bool needsLiveBlur() override {
            return false;
        }
        virtual bool needsPrecomputeBlur() override {
            return false;
        }
        virtual const char* passName() override {
            return "CGenieFlightElement";
        }
        virtual ePassElementType type() override {
            return EK_CUSTOM;
        }
        virtual bool disableSimplification() override {
            return true;
        }

      private:
        WP<SFlight> m_f;
    };

    SP<SFlight> flightFor(const PHLWINDOW& w) {
        for (auto const& f : g_flights) {
            if (!f->done && f->window.lock() == w)
                return f;
        }
        return nullptr;
    }

    void endFlight(SFlight& f) {
        removeTransformer(f.window, f.hider);
        if (!f.lastDamage.empty())
            g_pHyprRenderer->damageBox(f.lastDamage);
        if (const auto W = f.window.lock())
            g_pHyprRenderer->damageWindow(W);
        f.snapshot.reset();
        f.done = true;
    }

    void cancelGenieOn(const PHLWINDOW& w) {
        for (auto const& a : g_anims) {
            if (!a->done && a->opening && a->window.lock() == w) {
                detachTransformer(*a);
                a->done = true;
            }
        }
    }

    std::string startFlight(const PHLWINDOW& w, const CBox& tile, float delayMs, bool toTile) {
        if (!w || !w->m_isMapped || !w->m_workspace)
            return "no such window";

        cancelGenieOn(w);
        const auto OLD = flightFor(w);
        if (OLD)
            removeTransformer(OLD->window, OLD->hider);

        if (!toTile) {
            w->m_workspace->m_renderOffset->warp();
            w->m_workspace->m_alpha->warp();
            warpWindow(w);
        }

        const auto MON = w->m_monitor.lock();
        if (!MON)
            return "no monitor";

        auto snapshot = g_pHyprRenderer->makeSnapshotFB(w);
        if ((!snapshot || !snapshot->getTexture()) && OLD)
            snapshot = OLD->snapshot;
        if (OLD)
            OLD->done = true;
        if (!snapshot || !snapshot->getTexture())
            return "not visible";

        auto f      = makeShared<SFlight>();
        f->window   = w;
        f->monitor  = MON;
        f->snapshot = snapshot;
        f->srcPx    = OLD && OLD->snapshot == snapshot ? OLD->srcPx : windowPixelBox(w, MON);
        f->geo      = OLD && OLD->snapshot == snapshot ? OLD->geo : windowGeoLogical(w);
        f->full     = OLD && OLD->snapshot == snapshot ? OLD->full : windowFullLogical(w);
        f->toTile   = toTile;
        f->fromGeo  = toTile ? windowGeoLogical(w) : tile;
        f->toGeo    = toTile ? tile : windowGeoLogical(w);
        f->start    = Clock::now();
        f->delayMs  = delayMs;
        f->durMs    = toTile ? g_fly.flyMs : g_fly.backMs;

        auto hider = makeUnique<CHideTransformer>(w);
        f->hider   = hider.get();
        w->m_transformers.emplace_back(std::move(hider));

        g_flights.push_back(f);
        g_pHyprRenderer->damageMonitor(MON);
        return "ok";
    }

    void releaseFlights() {
        for (auto const& f : g_flights) {
            if (!f->done)
                endFlight(*f);
        }
        g_flights.clear();
    }

    void tickFlights(const PHLMONITOR& m, Clock::time_point now) {
        for (auto const& f : g_flights) {
            if (f->done || !f->flying || f->monitor.lock() != m)
                continue;
            if (!f->window.lock()) {
                f->done = true;
                continue;
            }
            const double MS = std::chrono::duration<double, std::milli>(now - f->start).count() - f->delayMs;
            const double T  = clamp01(MS / std::max(1.F, f->durMs));
            f->e            = f->toTile ? DECEL(T) : STANDARD(T);

            const CBox NOW = flightRect(*f).expand(4);
            if (!f->lastDamage.empty())
                g_pHyprRenderer->damageBox(f->lastDamage);
            g_pHyprRenderer->damageBox(NOW);
            f->lastDamage = NOW;

            if (T >= 1.0) {
                if (f->toTile) {
                    f->flying = false;
                    g_pHyprRenderer->damageBox(f->lastDamage);
                } else
                    endFlight(*f);
            }
        }
        std::erase_if(g_flights, [](const SP<SFlight>& f) { return f->done; });
    }

    struct SRecede;

    class CRecedeTransformer : public Render::IWindowTransformer {
      public:
        explicit CRecedeTransformer(WP<SRecede> r, PHLWINDOWREF w) : m_r(r), m_w(w) {}
        virtual ~CRecedeTransformer() = default;

        virtual void preWindowRender(CSurfacePassElement::SRenderData* rd) override {
            m_calls = 0;
            m_pass  = standaloneRender(rd, m_w.lock());
        }

        virtual SP<Render::IFramebuffer> transform(SP<Render::IFramebuffer> in) override;

      private:
        WP<SRecede>  m_r;
        PHLWINDOWREF m_w;
        bool         m_pass  = false;
        int          m_calls = 0;
    };

    struct SRecede {
        PHLWINDOWREF                window;
        PHLMONITORREF               monitor;
        Render::IWindowTransformer* transformer = nullptr;
        Clock::time_point           start;
        double                      eFrom = 0.0, eTo = 1.0, e = 0.0;
        float                       durMs = 440.F;
        CBox                        lastDamage;
        bool                        settled = false;
        bool                        done    = false;
    };
    std::vector<SP<SRecede>> g_recedes;

    SP<Render::IFramebuffer> CRecedeTransformer::transform(SP<Render::IFramebuffer> in) {
        const auto R = m_r.lock();
        const auto W = m_w.lock();
        if (m_pass || !R || !W || !in || !in->getTexture() || R->e <= 0.0005)
            return in;
        const auto MON = g_pHyprRenderer->m_renderData.pMonitor.lock();
        if (!MON)
            return in;
        const auto OUT = ownFB(MON, m_calls++, in->m_size);
        if (!OUT)
            return in;
        const CBox     SRC = windowPixelBox(W, MON);
        const Vector2D C   = MON->m_transformedSize / 2.0;
        const double   S   = lerp(1.0, g_fly.scale, R->e);
        const CBox     DST{C.x + (SRC.x - C.x) * S, C.y + (SRC.y - C.y) * S, SRC.w * S, SRC.h * S};
        {
            SFullDamage full(MON);
            auto        guard = g_pHyprRenderer->bindTempFB(OUT);
            g_pHyprRenderer->draw(CClearPassElement::SClearData{CHyprColor(0, 0, 0, 0)});
            drawSub(in->getTexture(), SRC, DST, sc<float>(lerp(1.0, g_fly.alpha, R->e)), false, MON);
        }
        return OUT;
    }

    SP<SRecede> recedeFor(const PHLWINDOW& w) {
        for (auto const& r : g_recedes) {
            if (!r->done && r->window.lock() == w)
                return r;
        }
        return nullptr;
    }

    void dropRecede(SRecede& r) {
        removeTransformer(r.window, r.transformer);
        if (!r.lastDamage.empty())
            g_pHyprRenderer->damageBox(r.lastDamage);
        r.done = true;
    }

    std::string recedeAll(bool in) {
        const auto NOW = Clock::now();
        int        n   = 0;
        if (in) {
            for (auto const& w : Desktop::windowState()->windows()) {
                if (!w->m_isMapped || !w->m_workspace || !w->m_workspace->isVisible() || w->isHidden())
                    continue;
                auto r = recedeFor(w);
                if (!r) {
                    r          = makeShared<SRecede>();
                    r->window  = w;
                    r->monitor = w->m_monitor;
                    auto t     = makeUnique<CRecedeTransformer>(r, w);
                    r->transformer = t.get();
                    w->m_transformers.emplace_back(std::move(t));
                    g_recedes.push_back(r);
                }
                r->eFrom   = r->e;
                r->eTo     = 1.0;
                r->start   = NOW;
                r->settled = false;
                r->durMs = g_fly.recedeMs;
                ++n;
            }
        } else {
            for (auto const& r : g_recedes) {
                if (r->done)
                    continue;
                r->eFrom   = r->e;
                r->eTo     = 0.0;
                r->start   = NOW;
                r->settled = false;
                r->durMs = g_fly.returnMs;
                ++n;
            }
        }
        for (auto const& m : State::monitorState()->monitors())
            g_pHyprRenderer->damageMonitor(m);
        return std::format("ok {}", n);
    }

    void tickRecedes(const PHLMONITOR& m, Clock::time_point now) {
        for (auto const& r : g_recedes) {
            if (r->done || r->monitor.lock() != m)
                continue;
            const auto W = r->window.lock();
            if (!W) {
                r->done = true;
                continue;
            }
            const double T  = clamp01(std::chrono::duration<double, std::milli>(now - r->start).count() / std::max(1.F, r->durMs));
            const double K  = r->eTo > r->eFrom ? DECEL(T) : STANDARD(T);
            r->e            = lerp(r->eFrom, r->eTo, K);
            if (T < 1.0 || !r->settled) {
                const CBox NOW = windowFullLogical(W).expand(4);
                if (!r->lastDamage.empty())
                    g_pHyprRenderer->damageBox(r->lastDamage);
                g_pHyprRenderer->damageBox(NOW);
                r->lastDamage = NOW;
            }
            r->settled = T >= 1.0;
            if (T >= 1.0 && r->eTo == 0.0)
                dropRecede(*r);
        }
        std::erase_if(g_recedes, [](const SP<SRecede>& r) { return r->done; });
    }

    void onWindowClose(PHLWINDOW w) {
        if (const auto OPENING = animFor(w, true)) {
            detachTransformer(*OPENING);
            OPENING->done = true;
        }
        if (const auto R = recedeFor(w))
            dropRecede(*R);
        if (const auto F = flightFor(w))
            endFlight(*F);
        if (const auto MV = moveFor(w))
            endMove(*MV);

        if (!g_cfg.close || !animatable(w))
            return;

        const auto ICON = iconForWindow(w);
        if (!ICON)
            return;

        const auto MONITOR = w->m_monitor.lock();
        if (!MONITOR || !iconOnMonitor(*ICON, MONITOR))
            return;

        const auto SNAPSHOT = g_pHyprRenderer->makeSnapshotFB(w);
        if (!SNAPSHOT || !SNAPSHOT->getTexture())
            return;

        w->m_ruleApplicator->noAnimOverride(Desktop::Types::COverridableVar<bool>(true, Desktop::Types::PRIORITY_SET_PROP));

        auto anim        = makeShared<SAnim>();
        anim->opening    = false;
        anim->monitor    = MONITOR;
        anim->icon       = *ICON;
        anim->source     = windowPixelBox(w, MONITOR);
        anim->geoPx      = windowGeoPx(w, MONITOR);
        anim->corner     = cornerOf(w, MONITOR);
        anim->snapshot   = SNAPSHOT;
        anim->start      = Clock::now();
        anim->durationMs = g_cfg.closeMs;
        anim->c          = 0.0;
        anim->style      = g_cfg.style;

        g_anims.push_back(anim);
        g_pHyprRenderer->damageMonitor(MONITOR);
    }


    bool busyElsewhere(const PHLWINDOW& w) {
        return flightFor(w) || recedeFor(w);
    }

    struct SWsBar {
        CBox rect;
        int  count = 1;
    };
    std::vector<SWsBar>                          g_wsBars;
    std::unordered_map<void*, PHLWORKSPACEREF>   g_lastWs;

    std::optional<CBox> dotFor(const PHLMONITOR& m, WORKSPACEID id) {
        for (auto const& b : g_wsBars) {
            if (!iconOnMonitor(b.rect, m))
                continue;
            const int  N    = std::max(1, b.count);
            const bool HORZ = b.rect.w >= b.rect.h;
            if (id < 1 || id > N) {
                const auto C = b.rect.middle();
                return CBox{C.x - 6, C.y - 6, 12, 12};
            }
            const double SLOT = (HORZ ? b.rect.w : b.rect.h) / N;
            const double I    = sc<double>(id - 1);
            if (HORZ)
                return CBox{b.rect.x + SLOT * I + SLOT * 0.2, b.rect.y + b.rect.h * 0.25, SLOT * 0.6, b.rect.h * 0.5};
            return CBox{b.rect.x + b.rect.w * 0.25, b.rect.y + SLOT * I + SLOT * 0.2, b.rect.w * 0.5, SLOT * 0.6};
        }
        return std::nullopt;
    }

    bool wsWindow(const PHLWINDOW& w, const PHLWORKSPACE& ws) {
        return w->m_isMapped && !w->isHidden() && w->m_workspace == ws && !w->m_pinned && !w->isX11OverrideRedirect() && !w->parent() &&
            !Fullscreen::controller()->isFullscreen(w) && !w->m_ruleApplicator->noAnim().valueOrDefault();
    }

    struct SWsCfg {
        int        style = 0;
        bool       lean  = true;
        float      zoom  = 0.27F;
        bool       cards = true;
        CHyprColor card{0.12, 0.13, 0.12, 1.0};
        CHyprColor label{0.89, 0.89, 0.87, 1.0};
    } g_wsCfg;

    struct SWsSwitch;

    struct SWsWin {
        PHLWINDOWREF                window;
        SP<Render::IFramebuffer>    snapshot;
        CBox                        src;
        bool                        old   = false;
        int                         order = 0;
        Render::IWindowTransformer* tr    = nullptr;
    };

    struct SWsSwitch {
        PHLMONITORREF       monitor;
        int                 style = 1;
        int                 dir   = 1;
        Clock::time_point   start;
        float               durMs = 500.F;
        double              u     = 0.0;
        std::vector<SWsWin> wins;
        int                 nOld = 0, nNew = 0;
        CBox                oldArea, newArea;
        WORKSPACEID         oldId = 0, newId = 0;
        bool                done  = false;
    };
    std::vector<SP<SWsSwitch>>                       g_wsSwitches;
    std::unordered_map<WORKSPACEID, SP<Render::ITexture>> g_wsLabels;

    struct SQuad {
        std::array<Vector2D, 4> p;
        std::array<double, 4>   w{1.0, 1.0, 1.0, 1.0};
    };

    double smooth01(double v) {
        v = clamp01(v);
        return v * v * (3.0 - 2.0 * v);
    }

    double springN(double u, double z, double w) {
        if (u <= 0.0)
            return 0.0;
        const double WD = w * std::sqrt(1.0 - z * z);
        return 1.0 - std::exp(-z * w * u) * (std::cos(WD * u) + z * w / WD * std::sin(WD * u));
    }

    SQuad flatQuad(const CBox& r) {
        return SQuad{.p = {Vector2D{r.x, r.y}, Vector2D{r.x + r.w, r.y}, Vector2D{r.x, r.y + r.h}, Vector2D{r.x + r.w, r.y + r.h}}};
    }

    SQuad tiltQuad(const CBox& r, double s, double ry, double tx, double f) {
        const Vector2D C  = r.middle();
        const Vector2D O  = C + Vector2D{tx, 0.0};
        const double   CS = std::cos(ry), SN = std::sin(ry);
        const std::array<Vector2D, 4> L = {Vector2D{r.x, r.y}, Vector2D{r.x + r.w, r.y}, Vector2D{r.x, r.y + r.h}, Vector2D{r.x + r.w, r.y + r.h}};
        SQuad q;
        for (size_t i = 0; i < 4; ++i) {
            const double X = (L[i].x - C.x) * s, Y = (L[i].y - C.y) * s;
            const double X2 = X * CS, Z = -X * SN;
            const double K  = f / std::max(1.0, f + Z);
            q.p[i]          = {O.x + X2 * K, O.y + Y * K};
            q.w[i]          = 1.0 / K;
        }
        return q;
    }

    struct SCarousel {
        double S = 1.0, cam = 0.0, span = 0.0, hump = 0.0;
        Vector2D C;
    };

    SCarousel carouselAt(const SWsSwitch& sw, const PHLMONITOR& m) {
        SCarousel c;
        const Vector2D SIZE = m->m_transformedSize;
        c.hump = std::min(smooth01(sw.u / 0.36), smooth01((1.0 - sw.u) / 0.36));
        c.S    = 1.0 - g_wsCfg.zoom * c.hump;
        c.span = SIZE.x * 1.1;
        c.cam  = sw.dir * c.span * INOUT(clamp01((sw.u - 0.14) / 0.72));
        c.C    = SIZE / 2.0;
        return c;
    }

    CBox carouselPlace(const SCarousel& c, const CBox& r, int k) {
        return CBox{c.C.x + (r.x + k * c.span - c.C.x - c.cam) * c.S, c.C.y + (r.y - c.C.y) * c.S, r.w * c.S, r.h * c.S};
    }

    SQuad wsQuad(const SWsSwitch& sw, const SWsWin& win, const CBox& r, const PHLMONITOR& m) {
        if (sw.style == 2)
            return flatQuad(carouselPlace(carouselAt(sw, m), r, win.old ? 0 : sw.dir));

        const int    N    = std::max(1, win.old ? sw.nOld : sw.nNew);
        const double D    = N > 1 ? std::min(0.09, 0.3 / (N - 1)) : 0.0;
        const double LEN  = 1.0 - D * (N - 1);
        const double P    = springN(clamp01((sw.u - win.order * D) / LEN), 0.84, 10.5);
        const double BUMP = g_wsCfg.lean ? std::sin(M_PI * clamp01(P)) : 0.0;
        const double X    = m->m_transformedSize.x + 60.0 * m->m_scale;
        const double TX   = win.old ? -sw.dir * X * P : sw.dir * X * (1.0 - P);
        return tiltQuad(r, 1.0 - 0.07 * BUMP, -sw.dir * 7.0 * M_PI / 180.0 * BUMP, TX, m->m_transformedSize.x * 1.5);
    }

    bool drawQuad(SP<Render::ITexture> tex, const CBox& src, const SQuad& q, double alpha, double dim, bool flip, const PHLMONITOR& m) {
        const CBox FULLBOX{0.0, 0.0, m->m_transformedSize.x, m->m_transformedSize.y};
        return drawProgV(g_perspProg, PERSP_VERT, PERSP_SRC, tex, FULLBOX, sc<float>(alpha), flip, m, [&](SGLProg& P) {
            glUniform2f(P.u("c00"), q.p[0].x, q.p[0].y);
            glUniform2f(P.u("c10"), q.p[1].x, q.p[1].y);
            glUniform2f(P.u("c01"), q.p[2].x, q.p[2].y);
            glUniform2f(P.u("c11"), q.p[3].x, q.p[3].y);
            glUniform4f(P.u("ws"), q.w[0], q.w[1], q.w[2], q.w[3]);
            glUniform4f(P.u("src"), src.x, src.y, src.w, src.h);
            glUniform1f(P.u("dim"), dim);
        });
    }

    void drawWsWin(SP<Render::ITexture> tex, const SWsSwitch& sw, const SWsWin& win, const CBox& r, const PHLMONITOR& m, bool flip) {
        const SQuad Q = wsQuad(sw, win, r, m);
        if (drawQuad(tex, r, Q, 1.0, 1.0, flip, m))
            return;
        const double X0 = std::min({Q.p[0].x, Q.p[2].x}), X1 = std::max({Q.p[1].x, Q.p[3].x});
        const double Y0 = std::min({Q.p[0].y, Q.p[1].y}), Y1 = std::max({Q.p[2].y, Q.p[3].y});
        drawSub(tex, r, CBox{X0, Y0, X1 - X0, Y1 - Y0}, 1.F, flip, m);
    }

    class CWsTransformer : public Render::IWindowTransformer {
      public:
        CWsTransformer(WP<SWsSwitch> sw, size_t idx) : m_sw(sw), m_idx(idx) {}
        virtual ~CWsTransformer() = default;

        virtual void preWindowRender(CSurfacePassElement::SRenderData* rd) override {
            m_calls       = 0;
            const auto SW = m_sw.lock();
            m_pass        = SW && m_idx < SW->wins.size() && standaloneRender(rd, SW->wins[m_idx].window.lock());
        }

        virtual SP<Render::IFramebuffer> transform(SP<Render::IFramebuffer> in) override {
            const auto SW = m_sw.lock();
            if (m_pass || !SW || SW->done || m_idx >= SW->wins.size() || !in || !in->getTexture())
                return in;
            const auto W   = SW->wins[m_idx].window.lock();
            const auto MON = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (!W || !MON || SW->monitor.lock() != MON)
                return in;
            const auto OUT = ownFB(MON, m_calls++, in->m_size);
            if (!OUT)
                return in;
            {
                SFullDamage full(MON);
                auto        guard = g_pHyprRenderer->bindTempFB(OUT);
                g_pHyprRenderer->draw(CClearPassElement::SClearData{CHyprColor(0, 0, 0, 0)});
                drawWsWin(in->getTexture(), *SW, SW->wins[m_idx], windowPixelBox(W, MON), MON, false);
            }
            return OUT;
        }

      private:
        WP<SWsSwitch> m_sw;
        size_t        m_idx   = 0;
        bool          m_pass  = false;
        int           m_calls = 0;
    };

    SP<Render::ITexture> wsLabel(WORKSPACEID id, const PHLMONITOR& m) {
        auto& t = g_wsLabels[id];
        if (!t)
            t = g_pHyprRenderer->renderText(std::format("Workspace {}", id), g_wsCfg.label, sc<int>(std::round(15.0 * m->m_scale)), false, "Rubik", 0, 600);
        return t;
    }

    class CWsCardElement : public IPassElement {
      public:
        explicit CWsCardElement(WP<SWsSwitch> sw) : m_sw(sw) {}
        virtual ~CWsCardElement() = default;

        virtual std::vector<UP<IPassElement>> draw() override {
            const auto SW  = m_sw.lock();
            const auto MON = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (!SW || SW->done || !MON || SW->monitor.lock() != MON || SW->style != 2 || !g_wsCfg.cards)
                return {};
            const auto C = carouselAt(*SW, MON);
            if (C.hump <= 0.001)
                return {};
            const CRegion FULL{0.0, 0.0, MON->m_transformedSize.x, MON->m_transformedSize.y};
            const double  PAD = 12.0 * MON->m_scale;
            for (int k = 0; k < 2; ++k) {
                const CBox AREA = (k == 0 ? SW->oldArea : SW->newArea).copy().expand(PAD);
                const CBox CARD = carouselPlace(C, AREA, k == 0 ? 0 : SW->dir);
                auto       col  = g_wsCfg.card;
                col.a           = 0.82 * C.hump;
                g_pHyprRenderer->draw(CRectPassElement::SRectData{.box = CARD, .color = col, .round = sc<int>(std::round(34.0 * C.S * MON->m_scale)), .roundingPower = 2.F},
                                      FULL);
            }
            return {};
        }

        virtual bool needsLiveBlur() override {
            return false;
        }
        virtual bool needsPrecomputeBlur() override {
            return false;
        }
        virtual const char* passName() override {
            return "CGenieWsCardElement";
        }
        virtual ePassElementType type() override {
            return EK_CUSTOM;
        }
        virtual bool disableSimplification() override {
            return true;
        }

      private:
        WP<SWsSwitch> m_sw;
    };

    class CWsOldElement : public IPassElement {
      public:
        explicit CWsOldElement(WP<SWsSwitch> sw) : m_sw(sw) {}
        virtual ~CWsOldElement() = default;

        virtual std::vector<UP<IPassElement>> draw() override {
            const auto SW  = m_sw.lock();
            const auto MON = g_pHyprRenderer->m_renderData.pMonitor.lock();
            if (!SW || SW->done || !MON || SW->monitor.lock() != MON)
                return {};
            for (auto const& w : SW->wins) {
                if (w.old && w.snapshot && w.snapshot->getTexture())
                    drawWsWin(w.snapshot->getTexture(), *SW, w, w.src, MON, true);
            }
            if (SW->style == 2 && g_wsCfg.cards)
                drawLabels(*SW, MON);
            return {};
        }

        virtual bool needsLiveBlur() override {
            return false;
        }
        virtual bool needsPrecomputeBlur() override {
            return false;
        }
        virtual const char* passName() override {
            return "CGenieWsOldElement";
        }
        virtual ePassElementType type() override {
            return EK_CUSTOM;
        }
        virtual bool disableSimplification() override {
            return true;
        }

      private:
        WP<SWsSwitch> m_sw;

        void          drawLabels(const SWsSwitch& sw, const PHLMONITOR& mon) {
            const auto   C = carouselAt(sw, mon);
            const double A = smooth01((C.hump - 0.5) / 0.4);
            if (A <= 0.001)
                return;
            const CRegion FULL{0.0, 0.0, mon->m_transformedSize.x, mon->m_transformedSize.y};
            const double  SC  = mon->m_scale;
            const double  PAD = 12.0 * SC;
            for (int k = 0; k < 2; ++k) {
                const auto TEX = wsLabel(k == 0 ? sw.oldId : sw.newId, mon);
                if (!TEX)
                    continue;
                const CBox   CARD = carouselPlace(C, (k == 0 ? sw.oldArea : sw.newArea).copy().expand(PAD), k == 0 ? 0 : sw.dir);
                const double PW = TEX->m_size.x + 40.0 * SC, PH = TEX->m_size.y + 12.0 * SC;
                const CBox   PILL{CARD.x + 24.0 * SC, CARD.y - PH - 14.0 * SC, PW, PH};
                if (PILL.y < 0 || PILL.x + PILL.w < 0 || PILL.x > mon->m_transformedSize.x)
                    continue;
                auto bg = g_cfg.container;
                bg.a    = A;
                g_pHyprRenderer->draw(CRectPassElement::SRectData{.box = PILL, .color = bg, .round = sc<int>(PH / 2.0), .roundingPower = 2.F}, FULL);
                drawSub(TEX, CBox{0.0, 0.0, TEX->m_size.x, TEX->m_size.y}, CBox{PILL.x + 20.0 * SC, PILL.y + 6.0 * SC, TEX->m_size.x, TEX->m_size.y}, sc<float>(A), true, mon);
            }
        }
    };

    void endWs(SWsSwitch& sw) {
        for (auto& w : sw.wins) {
            if (w.tr)
                removeTransformer(w.window, w.tr);
            w.snapshot.reset();
        }
        sw.done = true;
        if (const auto M = sw.monitor.lock())
            g_pHyprRenderer->damageMonitor(M);
    }

    void cancelWs(const PHLMONITOR& m) {
        for (auto const& sw : g_wsSwitches) {
            if (!sw->done && sw->monitor.lock() == m)
                endWs(*sw);
        }
        std::erase_if(g_wsSwitches, [](const SP<SWsSwitch>& sw) { return sw->done; });
    }

    CBox unionBox(const std::vector<CBox>& boxes, const PHLMONITOR& m) {
        if (boxes.empty())
            return CBox{0.0, 0.0, m->m_transformedSize.x, m->m_transformedSize.y}.expand(-24.0 * m->m_scale);
        double X0 = boxes[0].x, Y0 = boxes[0].y, X1 = boxes[0].x + boxes[0].w, Y1 = boxes[0].y + boxes[0].h;
        for (auto const& b : boxes) {
            X0 = std::min(X0, b.x);
            Y0 = std::min(Y0, b.y);
            X1 = std::max(X1, b.x + b.w);
            Y1 = std::max(Y1, b.y + b.h);
        }
        return CBox{X0, Y0, X1 - X0, Y1 - Y0};
    }

    void startWsSwitch(const PHLMONITOR& MON, const PHLWORKSPACE& OLD, const PHLWORKSPACE& ws) {
        std::vector<PHLWINDOW> olds, news;
        for (auto const& w : Desktop::windowState()->windows()) {
            if (wsWindow(w, OLD))
                olds.push_back(w);
            else if (wsWindow(w, ws) && !animFor(w, true))
                news.push_back(w);
        }

        auto sw     = makeShared<SWsSwitch>();
        sw->monitor = MON;
        sw->style   = g_wsCfg.style;
        sw->dir     = ws->m_id >= OLD->m_id ? 1 : -1;
        sw->durMs   = g_cfg.wsMs;
        sw->oldId   = OLD->m_id;
        sw->newId   = ws->m_id;

        std::vector<CBox> oldBoxes, newBoxes;
        for (auto const& w : olds) {
            const auto SNAPSHOT = g_pHyprRenderer->makeSnapshotFB(w);
            if (!SNAPSHOT || !SNAPSHOT->getTexture())
                continue;
            SWsWin win;
            win.window   = w;
            win.snapshot = SNAPSHOT;
            win.src      = windowPixelBox(w, MON);
            win.old      = true;
            oldBoxes.push_back(win.src);
            sw->wins.push_back(std::move(win));
        }

        OLD->m_renderOffset->warp();
        OLD->m_alpha->warp();
        ws->m_renderOffset->warp();
        ws->m_alpha->warp();

        for (auto const& w : news) {
            SWsWin win;
            win.window = w;
            win.src    = windowPixelBox(w, MON);
            newBoxes.push_back(win.src);
            sw->wins.push_back(std::move(win));
        }

        if (sw->wins.empty() && sw->style != 2)
            return;

        for (int pass = 0; pass < 2; ++pass) {
            std::vector<SWsWin*> group;
            for (auto& w : sw->wins) {
                if (w.old == (pass == 0))
                    group.push_back(&w);
            }
            std::ranges::sort(group, [&](const SWsWin* a, const SWsWin* b) { return sw->dir * (a->src.x - b->src.x) < 0; });
            for (size_t i = 0; i < group.size(); ++i)
                group[i]->order = sc<int>(i);
            (pass == 0 ? sw->nOld : sw->nNew) = sc<int>(group.size());
        }

        sw->oldArea = unionBox(oldBoxes, MON);
        sw->newArea = unionBox(newBoxes, MON);

        for (size_t i = 0; i < sw->wins.size(); ++i) {
            auto& win = sw->wins[i];
            if (win.old)
                continue;
            const auto W  = win.window.lock();
            auto       tr = makeUnique<CWsTransformer>(sw, i);
            win.tr        = tr.get();
            W->m_transformers.emplace_back(std::move(tr));
        }

        sw->start = Clock::now();
        g_wsSwitches.push_back(sw);
        g_pHyprRenderer->damageMonitor(MON);
    }

    void tickWs(const PHLMONITOR& m, Clock::time_point now) {
        for (auto const& sw : g_wsSwitches) {
            if (sw->done || sw->monitor.lock() != m)
                continue;
            sw->u = clamp01(std::chrono::duration<double, std::milli>(now - sw->start).count() / std::max(1.F, sw->durMs));
            g_pHyprRenderer->damageMonitor(m);
            if (sw->u >= 1.0)
                endWs(*sw);
        }
        std::erase_if(g_wsSwitches, [](const SP<SWsSwitch>& sw) { return sw->done; });
    }

    void onWorkspaceActive(PHLWORKSPACE ws) {
        if (!ws || ws->m_isSpecialWorkspace)
            return;
        const auto MON = ws->m_monitor.lock();
        if (!MON)
            return;
        auto&      last = g_lastWs[MON.get()];
        const auto OLD  = last.lock();
        last            = ws;
        if (!g_cfg.ws || !OLD || OLD == ws || OLD->m_isSpecialWorkspace || OLD->m_monitor.lock() != MON)
            return;

        cancelWs(MON);
        for (auto const& a : g_anims) {
            if (a->ws && !a->done && a->monitor.lock() == MON) {
                detachTransformer(*a);
                a->snapshot.reset();
                a->done = true;
            }
        }

        if (g_wsCfg.style != 0) {
            startWsSwitch(MON, OLD, ws);
            return;
        }

        const auto OLDDOT = dotFor(MON, OLD->m_id), NEWDOT = dotFor(MON, ws->m_id);
        if (!OLDDOT || !NEWDOT)
            return;

        const auto NOW     = Clock::now();
        const auto STAGGER = std::chrono::duration<double, std::milli>(g_cfg.wsMs * 0.08);
        const auto DIST    = [](const CBox& b, const CBox& d) { return std::hypot(b.middle().x - d.middle().x, b.middle().y - d.middle().y); };

        std::vector<PHLWINDOW> olds, news;
        for (auto const& w : Desktop::windowState()->windows()) {
            if (wsWindow(w, OLD))
                olds.push_back(w);
            else if (wsWindow(w, ws))
                news.push_back(w);
        }
        std::ranges::sort(olds, [&](const PHLWINDOW& a, const PHLWINDOW& b) { return DIST(windowFullLogical(a), *OLDDOT) < DIST(windowFullLogical(b), *OLDDOT); });
        std::ranges::sort(news, [&](const PHLWINDOW& a, const PHLWINDOW& b) { return DIST(windowFullLogical(a), *NEWDOT) < DIST(windowFullLogical(b), *NEWDOT); });

        int i = 0;
        for (auto const& w : olds) {
            const auto SNAPSHOT = g_pHyprRenderer->makeSnapshotFB(w);
            if (!SNAPSHOT || !SNAPSHOT->getTexture())
                continue;
            auto anim        = makeShared<SAnim>();
            anim->opening    = false;
            anim->ws         = true;
            anim->monitor    = MON;
            anim->icon       = *OLDDOT;
            anim->source     = windowPixelBox(w, MON);
            anim->geoPx      = windowGeoPx(w, MON);
            anim->corner     = cornerOf(w, MON);
            anim->snapshot   = SNAPSHOT;
            anim->start      = NOW + std::chrono::duration_cast<Clock::duration>(STAGGER * i++);
            anim->durationMs = g_cfg.wsMs;
            anim->c          = 0.0;
            anim->style      = g_cfg.style;
            g_anims.push_back(anim);
        }

        OLD->m_renderOffset->warp();
        OLD->m_alpha->warp();
        ws->m_renderOffset->warp();
        ws->m_alpha->warp();

        const auto ENTER = std::chrono::duration<double, std::milli>(olds.empty() ? 0.0 : g_cfg.wsMs * 0.35);
        i                = 0;
        for (auto const& w : news) {
            if (animFor(w, true))
                continue;
            const auto A = startOpen(w, *NEWDOT, MON, 0);
            A->ws         = true;
            A->start      = NOW + std::chrono::duration_cast<Clock::duration>(ENTER + STAGGER * i++);
            A->durationMs = g_cfg.wsMs;
        }
        g_pHyprRenderer->damageMonitor(MON);
    }

    void onFrame(PHLMONITOR m) {
        scanMoves(m);
        if (g_anims.empty() && g_flights.empty() && g_recedes.empty() && g_moves.empty() && g_wsSwitches.empty())
            return;

        const auto NOW = Clock::now();
        tickWs(m, NOW);
        tickMoves(m, NOW);
        tickFlights(m, NOW);
        tickRecedes(m, NOW);
        for (auto const& a : g_anims) {
            if (a->done || a->monitor.lock() != m)
                continue;

            const auto WINDOW = a->window.lock();
            if (a->opening && !WINDOW) {
                a->done = true;
                continue;
            }

            if (a->opening && NOW < a->warpUntil)
                warpWindow(WINDOW);

            const double T = clamp01(std::chrono::duration<double, std::milli>(NOW - a->start).count() / std::max(1.F, a->durationMs));
            a->c           = a->opening ? 1.0 - T : T;
            a->t           = T;

            damageAnim(*a, m);

            if (T >= 1.0) {
                if (!a->opening && a->hider && WINDOW)
                    warpWindow(WINDOW);
                detachTransformer(*a);
                a->snapshot.reset();
                a->done = true;
                if (!a->lastDamage.empty())
                    g_pHyprRenderer->damageBox(a->lastDamage);
            }
        }

        std::erase_if(g_anims, [](const SP<SAnim>& a) { return a->done; });
    }

    void onRenderStage(eRenderStage stage) {
        const auto MONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();
        if (!MONITOR)
            return;

        if (stage == RENDER_LAST_MOMENT) {
            if (!g_fbs.empty() && g_anims.empty() && g_flights.empty() && g_recedes.empty() && g_moves.empty() && g_wsSwitches.empty())
                g_fbs.clear();
            for (auto const& f : g_flights) {
                if (f->flying && !f->done && f->monitor.lock() == MONITOR)
                    g_pHyprRenderer->addPassElement(makeUnique<CFlightElement>(f));
            }
            return;
        }

        if (stage == RENDER_PRE_WINDOWS) {
            for (auto const& sw : g_wsSwitches) {
                if (!sw->done && sw->style == 2 && sw->monitor.lock() == MONITOR)
                    g_pHyprRenderer->addPassElement(makeUnique<CWsCardElement>(sw));
            }
            return;
        }

        if (stage != RENDER_POST_WINDOWS)
            return;

        for (auto const& sw : g_wsSwitches) {
            if (!sw->done && sw->monitor.lock() == MONITOR)
                g_pHyprRenderer->addPassElement(makeUnique<CWsOldElement>(sw));
        }

        for (auto const& a : g_anims) {
            if (!a->opening && !a->done && a->monitor.lock() == MONITOR)
                g_pHyprRenderer->addPassElement(makeUnique<CGenieCloseElement>(a));
        }
    }

    std::vector<std::string> splitWords(const std::string& s) {
        std::istringstream       in(s);
        std::vector<std::string> out;
        std::string              w;
        while (in >> w)
            out.push_back(w);
        return out;
    }

    std::optional<std::pair<CBox, std::vector<std::string>>> parseRectKeys(const std::vector<std::string>& a, size_t from) {
        if (a.size() < from + 5)
            return std::nullopt;
        try {
            CBox                     r{std::stod(a[from]), std::stod(a[from + 1]), std::stod(a[from + 2]), std::stod(a[from + 3])};
            std::vector<std::string> keys;
            for (size_t i = from + 4; i < a.size(); ++i)
                keys.push_back(lower(a[i]));
            if (r.w <= 0 || r.h <= 0)
                return std::nullopt;
            return std::make_pair(r, keys);
        } catch (...) { return std::nullopt; }
    }

    std::string status() {
        std::ostringstream o;
        o << "open " << g_cfg.open << " (" << g_cfg.openMs << " ms), close " << g_cfg.close << " (" << g_cfg.closeMs << " ms), minimize " << g_cfg.minimize << ", strips "
          << (g_cfg.strips > 0 ? std::to_string(g_cfg.strips) : std::string("auto")) << ", tiled " << g_cfg.tiled << ", workspace " << g_cfg.ws << " (" << g_cfg.wsMs
          << " ms), move " << g_cfg.move << " (" << g_cfg.moveMs << " ms), wsbars " << g_wsBars.size() << ", ws_style "
          << (g_wsCfg.style == 1 ? "glide" : (g_wsCfg.style == 2 ? "carousel" : "dot")) << "\n";
        if (!g_glError.empty())
            o << "shader error: " << g_glError << "\n";
        o << "armed " << g_arms.size() << ", running " << g_anims.size() << ", icons " << g_icons.size() << "\n";
        for (auto const& b : g_wsBars)
            o << "  wsbar " << b.rect.x << "," << b.rect.y << " " << b.rect.w << "x" << b.rect.h << " n=" << b.count << "\n";
        for (auto const& ic : g_icons) {
            o << "  " << ic.rect.x << "," << ic.rect.y << " " << ic.rect.w << "x" << ic.rect.h << " ";
            for (auto const& k : ic.keys)
                o << k << " ";
            o << "\n";
        }
        return o.str();
    }

    std::string onCommand(eHyprCtlOutputFormat, std::string request) {
        const auto A = splitWords(request);
        if (A.size() < 2 || A[0] != "genie")
            return "usage: genie launch|icon|icons|set|status ...";

        const auto& SUB = A[1];
        if (SUB == "status")
            return status();

        if (SUB == "launch" || SUB == "from") {
            const auto P = parseRectKeys(A, 2);
            if (!P)
                return "usage: genie " + SUB + " X Y W H KEY...";
            g_arms.push_back({P->second, P->first, Clock::now(), SUB == "launch"});
            return "ok";
        }

        if (SUB == "minimize") {
            const auto W = A.size() >= 3 ? windowByAddress(A[2]) : Desktop::focusState()->window();
            return minimizeWindow(W);
        }

        if (SUB == "flyto" || SUB == "flyfrom") {
            if (A.size() < 7)
                return "usage: genie " + SUB + " ADDRESS X Y W H [DELAY_MS]";
            try {
                const CBox  R{std::stod(A[3]), std::stod(A[4]), std::stod(A[5]), std::stod(A[6])};
                const float D = A.size() >= 8 ? std::stof(A[7]) : 0.F;
                return startFlight(windowByAddress(A[2]), R, D, SUB == "flyto");
            } catch (...) { return "bad number"; }
        }

        if (SUB == "release") {
            releaseFlights();
            return "ok";
        }

        if (SUB == "recede")
            return recedeAll(true);

        if (SUB == "unrecede")
            return recedeAll(false);

        if (SUB == "restore") {
            if (A.size() < 3)
                return "usage: genie restore ADDRESS";
            return restoreWindow(windowByAddress(A[2]));
        }

        if (SUB == "icon") {
            const auto P = parseRectKeys(A, 2);
            if (!P)
                return "usage: genie icon X Y W H KEY...";
            std::erase_if(g_icons, [&](const SIcon& i) { return !i.keys.empty() && i.keys.front() == P->second.front(); });
            g_icons.push_back({P->second, P->first});
            return "ok";
        }

        if (SUB == "wsbars" && A.size() >= 3 && A[2] == "clear") {
            g_wsBars.clear();
            return "ok";
        }

        if (SUB == "wsbar" && A.size() >= 7) {
            try {
                g_wsBars.push_back({CBox{std::stod(A[2]), std::stod(A[3]), std::stod(A[4]), std::stod(A[5])}, std::max(1, std::stoi(A[6]))});
                return "ok";
            } catch (...) { return "bad wsbar"; }
        }

        if (SUB == "icons" && A.size() >= 3 && A[2] == "clear") {
            g_icons.clear();
            return "ok";
        }

        if (SUB == "set" && A.size() >= 4 && A[2] == "style") {
            g_cfg.style = A[3] == "shape" ? 1 : 0;
            return "ok";
        }

        if (SUB == "set" && A.size() >= 4 && A[2] == "ws_style") {
            g_wsCfg.style = A[3] == "glide" ? 1 : (A[3] == "carousel" ? 2 : 0);
            return "ok";
        }

        if (SUB == "set" && A.size() >= 4 && (A[2] == "card" || A[2] == "label")) {
            try {
                const auto V   = std::stoul(A[3], nullptr, 16);
                const auto COL = CHyprColor(((V >> 16) & 0xFF) / 255.0, ((V >> 8) & 0xFF) / 255.0, (V & 0xFF) / 255.0, 1.0);
                if (A[2] == "card")
                    g_wsCfg.card = COL;
                else {
                    g_wsCfg.label = COL;
                    g_wsLabels.clear();
                }
                return "ok";
            } catch (...) { return "bad colour"; }
        }

        if (SUB == "set" && A.size() >= 4 && A[2] == "accent") {
            try {
                const auto V = std::stoul(A[3], nullptr, 16);
                g_cfg.accent = CHyprColor(((V >> 16) & 0xFF) / 255.0, ((V >> 8) & 0xFF) / 255.0, (V & 0xFF) / 255.0, 1.0);
                return "ok";
            } catch (...) { return "bad colour"; }
        }

        if (SUB == "set" && A.size() >= 4 && A[2] == "container") {
            try {
                const auto V = std::stoul(A[3], nullptr, 16);
                g_cfg.container = CHyprColor(((V >> 16) & 0xFF) / 255.0, ((V >> 8) & 0xFF) / 255.0, (V & 0xFF) / 255.0, 1.0);
                return "ok";
            } catch (...) { return "bad colour"; }
        }

        if (SUB == "set" && A.size() >= 4) {
            try {
                const auto& K = A[2];
                const auto  V = std::stod(A[3]);
                if (K == "open")
                    g_cfg.open = V != 0;
                else if (K == "close")
                    g_cfg.close = V != 0;
                else if (K == "minimize")
                    g_cfg.minimize = V != 0;
                else if (K == "tiled")
                    g_cfg.tiled = V != 0;
                else if (K == "workspace")
                    g_cfg.ws = V != 0;
                else if (K == "move")
                    g_cfg.move = V != 0;
                else if (K == "ws_ms")
                    g_cfg.wsMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "move_ms")
                    g_cfg.moveMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "open_ms")
                    g_cfg.openMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "close_ms")
                    g_cfg.closeMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "fly_ms")
                    g_fly.flyMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "back_ms")
                    g_fly.backMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "recede_ms")
                    g_fly.recedeMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "return_ms")
                    g_fly.returnMs = std::clamp(sc<float>(V), 50.F, 5000.F);
                else if (K == "recede_scale")
                    g_fly.scale = std::clamp(sc<float>(V), 0.3F, 1.F);
                else if (K == "recede_alpha")
                    g_fly.alpha = std::clamp(sc<float>(V), 0.F, 1.F);
                else if (K == "glide_lean")
                    g_wsCfg.lean = V != 0;
                else if (K == "carousel_zoom")
                    g_wsCfg.zoom = std::clamp(sc<float>(V), 0.F, 0.6F);
                else if (K == "carousel_cards")
                    g_wsCfg.cards = V != 0;
                else if (K == "strips")
                    g_cfg.strips = std::clamp(sc<int>(V), 0, 600);
                else
                    return "unknown setting " + K;
                return "ok";
            } catch (...) { return "bad value"; }
        }

        return "usage: genie launch|from|minimize|restore|flyto|flyfrom|release|recede|unrecede|icon|icons clear|set KEY VALUE|status";
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();
    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(PHANDLE, "[genie] built for a different Hyprland, rebuild the plugin", CHyprColor{1.0, 0.3, 0.3, 1.0}, 6000);
        throw std::runtime_error("[genie] version mismatch");
    }

    auto& ev = Event::bus()->m_events;
    g_listeners.push_back(ev.window.openLate.listen([](PHLWINDOW w) { onWindowOpen(w); }));
    g_listeners.push_back(ev.window.close.listen([](PHLWINDOW w) { onWindowClose(w); }));
    g_listeners.push_back(ev.render.preChecks.listen([](PHLMONITOR m) { onFrame(m); }));
    g_listeners.push_back(ev.render.stage.listen([](eRenderStage s) { onRenderStage(s); }));
    g_listeners.push_back(ev.workspace.active.listen([](PHLWORKSPACE ws) { onWorkspaceActive(ws); }));
    for (auto const& m : State::monitorState()->monitors()) {
        if (m && m->m_activeWorkspace)
            g_lastWs[m.get()] = m->m_activeWorkspace;
    }

    g_command = HyprlandAPI::registerHyprCtlCommand(PHANDLE, SHyprCtlCommand{.name = "genie", .exact = false, .fn = onCommand});

    return {"genie", "Windows open from and close into their dock icon", "Nebula", "0.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    for (auto const& mv : g_moves)
        endMove(*mv);
    g_moves.clear();
    g_goals.clear();
    for (auto const& sw : g_wsSwitches)
        endWs(*sw);
    g_wsSwitches.clear();
    g_wsLabels.clear();
    for (auto const& a : g_anims)
        detachTransformer(*a);
    g_anims.clear();
    releaseFlights();
    for (auto const& r : g_recedes)
        removeTransformer(r->window, r->transformer);
    g_recedes.clear();
    g_fbs.clear();
    if (Render::GL::g_pHyprOpenGL) {
        Render::GL::g_pHyprOpenGL->makeEGLCurrent();
        destroyProg(g_genieProg);
        destroyProg(g_shapeProg);
        destroyProg(g_perspProg);
    }
    g_listeners.clear();
    if (g_command)
        HyprlandAPI::unregisterHyprCtlCommand(PHANDLE, g_command);
    g_command.reset();
    g_icons.clear();
    g_arms.clear();
    g_origins.clear();
}
