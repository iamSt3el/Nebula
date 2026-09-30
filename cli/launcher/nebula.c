#define _GNU_SOURCE
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

static int is_file(const char *path)
{
    struct stat st;
    return stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

static int is_exec(const char *path)
{
    return is_file(path) && access(path, X_OK) == 0;
}

static int has_cli(const char *dir)
{
    char path[PATH_MAX];
    snprintf(path, sizeof path, "%s/cli/nebula/__main__.py", dir);
    return is_file(path);
}

static const char *env_or_null(const char *name)
{
    const char *value = getenv(name);
    return value && *value ? value : NULL;
}

static int find_shell_dir(char *out, size_t size)
{
    const char *dir = env_or_null("NEBULA_DIR");
    const char *xdg = env_or_null("XDG_CONFIG_HOME");
    const char *home = env_or_null("HOME");

    if (dir) {
        snprintf(out, size, "%s", dir);
        return has_cli(out);
    }
    if (xdg) {
        snprintf(out, size, "%s/quickshell", xdg);
        if (has_cli(out))
            return 1;
    }
    if (home) {
        snprintf(out, size, "%s/.config/quickshell", home);
        return has_cli(out);
    }
    out[0] = '\0';
    return 0;
}

static int system_python_has(const char *module)
{
    char code[256];
    int status = 0;
    pid_t pid;

    snprintf(code, sizeof code,
             "import importlib.util,sys; sys.exit(importlib.util.find_spec('%s') is None)",
             module);
    pid = fork();
    if (pid < 0)
        return 0;
    if (pid == 0) {
        int null = open("/dev/null", O_RDWR);
        if (null >= 0) {
            dup2(null, STDOUT_FILENO);
            dup2(null, STDERR_FILENO);
        }
        execlp("python3", "python3", "-c", code, (char *)NULL);
        _exit(127);
    }
    if (waitpid(pid, &status, 0) < 0)
        return 0;
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static void pick_python(char *out, size_t size)
{
    const char *python = env_or_null("NEBULA_PYTHON");
    const char *venv = env_or_null("NEBULA_VENV");
    const char *state = env_or_null("XDG_STATE_HOME");
    const char *home = env_or_null("HOME");
    char candidate[PATH_MAX];

    if (python) {
        snprintf(out, size, "%s", python);
        return;
    }
    if (venv) {
        snprintf(candidate, sizeof candidate, "%s/bin/python", venv);
        if (is_exec(candidate)) {
            snprintf(out, size, "%s", candidate);
            return;
        }
    }
    snprintf(out, size, "python3");
    if (state)
        snprintf(candidate, sizeof candidate, "%s/quickshell/.venv/bin/python", state);
    else if (home)
        snprintf(candidate, sizeof candidate, "%s/.local/state/quickshell/.venv/bin/python", home);
    else
        return;
    if (is_exec(candidate) && !system_python_has("materialyoucolor"))
        snprintf(out, size, "%s", candidate);
}

int main(int argc, char **argv)
{
    char dir[PATH_MAX];
    char python[PATH_MAX];
    char path[PATH_MAX * 2];
    const char *old = env_or_null("PYTHONPATH");
    char **args;
    int i;

    if (!find_shell_dir(dir, sizeof dir)) {
        fprintf(stderr, "nebula: no Nebula shell in %s\n", dir[0] ? dir : "~/.config/quickshell");
        fprintf(stderr, "nebula: set NEBULA_DIR to the folder that holds shell.qml\n");
        return 1;
    }
    pick_python(python, sizeof python);

    if (old)
        snprintf(path, sizeof path, "%s/cli:%s", dir, old);
    else
        snprintf(path, sizeof path, "%s/cli", dir);
    setenv("PYTHONPATH", path, 1);

    args = calloc((size_t)argc + 3, sizeof *args);
    if (!args) {
        perror("nebula");
        return 1;
    }
    args[0] = python;
    args[1] = "-m";
    args[2] = "nebula";
    for (i = 1; i < argc; i++)
        args[i + 2] = argv[i];
    args[argc + 2] = NULL;

    execvp(python, args);
    fprintf(stderr, "nebula: cannot run %s: ", python);
    perror(NULL);
    return 127;
}
