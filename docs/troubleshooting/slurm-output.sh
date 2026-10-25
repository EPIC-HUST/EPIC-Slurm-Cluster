# Slurm table output defaults. Source from Bash login/interactive shells.
export SPRIO_FORMAT='%.10i %32r %.10Y %.10S %.10A %.10F %.10Q %T'
export SQUEUE_FORMAT='%.18i %.32P %.28j %.16u %.10T %.12M %.12l %.6D %R'
export SINFO_FORMAT='%32P %5a %12l %6D %12t %N'
export SACCT_FORMAT='JobID%24,JobName%28,Partition%32,User%16,State%24,Elapsed%14,AllocCPUS%10,ExitCode%10,NodeList%40'

# Functions below are for interactive Bash only.
[ -n "${BASH_VERSION:-}" ] || return 0
case $- in *i*) ;; *) return 0 ;; esac

# Respect explicit formats and alternate output modes.
_slurm_has_output_option() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -o*|--format*|[Ff][Oo][Rr][Mm][Aa][Tt]=*|-p|-P|--parsable*|--json*|--yaml*|-h|--help*|-V|--version|-l|--long)
                return 0 ;;
        esac
    done
    return 1
}

sshare() {
    if _slurm_has_output_option "$@"; then
        command sshare "$@"
    else
        command sshare --format='Account%32,User%16,RawShares%12,NormShares%12,RawUsage%16,NormUsage%12,EffectvUsage%14,FairShare%12' "$@"
    fi
}

sstat() {
    if _slurm_has_output_option "$@"; then
        command sstat "$@"
    else
        command sstat --format='JobID%24,NTasks%10,AveCPU%16,AveRSS%14,MaxRSS%14,MaxRSSNode%40' "$@"
    fi
}

sacctmgr() {
    local fmt=''
    if _slurm_has_output_option "$@"; then
        command sacctmgr "$@"
        return $?
    fi
    # Apply only to full, direct "show/list entity" commands.
    case "${1-}:${2-}" in
        show:tres|list:tres)
            fmt='Type%16,Name%40,ID%8' ;;
        show:assoc|list:assoc|show:association|list:association)
            fmt='Cluster%24,Account%24,User%16,Partition%32,Share%10,Priority%10,GrpTRES%60,MaxTRES%60,QOS%40,DefaultQOS%24' ;;
        show:user|list:user)
            fmt='User%16,DefaultAccount%24,AdminLevel%16' ;;
        show:account|list:account)
            fmt='Account%24,Descr%40,Org%24' ;;
        show:qos|list:qos)
            fmt='Name%24,Priority%10,UsageFactor%12,GrpTRES%60,MaxTRESPJ%60,MaxTRESPU%60,Flags%40' ;;
        show:cluster|list:cluster)
            fmt='Cluster%24,ControlHost%40,ControlPort%12,TRES%80' ;;
    esac
    if [ -n "$fmt" ]; then
        command sacctmgr "$@" "format=$fmt"
    else
        command sacctmgr "$@"
    fi
}

sreport() {
    local fmt=''
    if _slurm_has_output_option "$@"; then
        command sreport "$@"
        return $?
    fi
    case "${1-}:${2-}" in
        cluster:utilization)
            fmt='Cluster%24,TresName%20,Allocated%16,Down%16,Idle%16,Reported%16' ;;
        cluster:accountutilizationbyuser)
            fmt='Cluster%24,Accounts%24,Login%16,Proper%24,Used%16' ;;
        cluster:userutilizationbyaccount)
            fmt='Cluster%24,Login%16,Accounts%24,Used%16' ;;
        user:topusage|user:top)
            fmt='Cluster%24,Login%16,Account%24,Used%16' ;;
    esac
    if [ -n "$fmt" ]; then
        command sreport "$@" "format=$fmt"
    else
        command sreport "$@"
    fi
}
