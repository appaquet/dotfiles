# Labels the current Herdr terminal with its workspace URL, so Herdr mods can show a link to it.
# The URL is the value of the first non-empty variable among those given to hc_space_url_watch,
# typically exported by a repo's direnv setup. The label is `space.url=<url>`; an empty value
# removes it.

# Watches the given variable names, in priority order, and keeps the label in sync with them.
function hc_space_url_watch --description 'Label this Herdr terminal with the first set URL variable'
    set -g __hc_space_url_vars $argv
    set -g __hc_space_url_last ''

    # direnv sets and erases variables, which fires this handler on load, change and unload.
    function __hc_space_url_on_change --on-variable=$__hc_space_url_vars
        __hc_space_url_sync
    end

    # The variables may already be inherited when the shell starts.
    __hc_space_url_sync
end

# Sends the current URL to Herdr when it differs from the last one sent. Always succeeds: a
# variable handler's status leaks into the shell's $status after the `set` that fired it.
function __hc_space_url_sync
    set -q HC_TERMINAL_ID; or return 0
    command -q hc; or return 0

    set -l url ''
    for var in $__hc_space_url_vars
        if test -n "$$var"
            set url "$$var"
            break
        end
    end

    test "$url" = "$__hc_space_url_last"; and return 0
    set -g __hc_space_url_last $url
    command hc label $HC_TERMINAL_ID "space.url=$url" >/dev/null 2>&1
    return 0
end
