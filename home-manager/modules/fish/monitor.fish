# `monitor` reports a command's lifecycle to Herdr through OSC 7501 status frames: `working` while it
# runs, then `done` (exit 0), `error` (other exits) or `idle` (interrupted or suspended again).
# `monitor <cmd> [args...]` runs a new command; `monitor fg [%N]` resumes a job stopped with Ctrl-Z.
# Outside an interactive Herdr pane (`HC_TERMINAL_ID` unset), it only runs or resumes the command.

function monitor --description 'Run or resume a command, reporting its status to Herdr'
    if not set -q argv[1]
        echo "usage: monitor <command> [args...] | monitor fg [%N]" >&2
        return 2
    end

    if test "$argv[1]" = fg
        __monitor_fg $argv[2..]
        return
    end

    # Ctrl-Z on a simple command returns here with a new stopped job; that is not completion.
    set -l stopped_before (count (__monitor_stopped_jobs))
    __monitor_start
    $argv
    set -l code $status

    if test (count (__monitor_stopped_jobs)) -gt $stopped_before
        __monitor_finish idle
    else
        __monitor_finish (__monitor_state_for $code)
    end
    return $code
end

# Ends a monitor that fish abandoned before it could report, which happens on Ctrl-C and on Ctrl-Z
# of a pipeline.
function __monitor_postexec --on-event fish_postexec
    set -q __monitor_active; and __monitor_finish idle
end

# Resumes a stopped job in the foreground under monitoring. `builtin fg` always returns 0, so the
# exit code comes from a process-exit handler on the job's last process.
function __monitor_fg
    set -l job (__monitor_select_job $argv); or return 1
    set -l pids (jobs -p %$job)

    set -g __monitor_exit_code
    function __monitor_on_exit --on-process-exit $pids[-1]
        set -g __monitor_exit_code $argv[3]
    end

    __monitor_start
    builtin fg $pids[1]
    set -l code $__monitor_exit_code

    if jobs -q %$job 2>/dev/null; or test -z "$code"
        # Stopped again, or the exit code is unknown: never report success.
        __monitor_finish idle
    else
        __monitor_finish (__monitor_state_for $code)
    end
end

# Prints the job ID to resume: the explicit `%N` when it names a stopped job, else the only
# stopped job. Explains and fails when the choice is missing or ambiguous.
function __monitor_select_job
    set -l stopped (__monitor_stopped_jobs)

    if set -q argv[1]
        set -l id (string replace -r '^%' '' -- $argv[1])
        if not contains -- $id $stopped
            echo "monitor: job $argv[1] is not a stopped job" >&2
            return 1
        end
        echo $id
        return
    end

    switch (count $stopped)
        case 0
            echo "monitor: no stopped job; press Ctrl-Z on a running command first" >&2
            return 1
        case 1
            echo $stopped
        case '*'
            echo "monitor: several stopped jobs; pick one with: monitor fg %N" >&2
            jobs >&2
            return 1
    end
end

# Prints the IDs of stopped jobs. `jobs` output is tab-separated: ID, group, CPU, state, command.
function __monitor_stopped_jobs
    LC_ALL=C jobs 2>/dev/null | string match -rg '^(\d+)\t[^\t]*\t[^\t]*\tstopped\t'
end

function __monitor_start
    set -g __monitor_active 1
    __monitor_emit working
end

function __monitor_finish --argument-names state
    set -e __monitor_active
    set -e __monitor_exit_code
    functions -e __monitor_on_exit
    __monitor_emit $state
end

# Maps an exit code to a status word; 130 is an interrupt (Ctrl-C), not a failure.
function __monitor_state_for --argument-names code
    switch $code
        case 0
            echo done
        case 130
            echo idle
        case '*'
            echo error
    end
end

# Writes an OSC 7501 frame to the terminal, not stdout, so a piped `monitor` stays clean.
function __monitor_emit --argument-names state
    status is-interactive; or return
    set -q HC_TERMINAL_ID; or return
    printf '\e]7501;state=%s:app=fish-job\e\\' $state >/dev/tty 2>/dev/null
end
