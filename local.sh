#!/usr/bin/env bash

log-parser () (

    date="${4:-%Y.%m.%d}"
    log_server="ssh eu02-web-logs"
    log_path="/logs-tdc/$(date +"${date}")"
    log_file="${1}.log"
    grep_cmd="grep --color=always -nE"
    actions_pipe="/tmp/tdc-log-actions.pipe"
    parser_cmd="${log_server} cat ${log_path}/${log_file} | sed 's/\\\\\\\"/\"/g'"

    in_tmux () {
        tmux kill-session -t tdc_log
        [[ -n "$(which gnome-terminal)" ]] && gnome-terminal --window --maximize --hide-menubar -- /usr/bin/tmux new -s tdc_log
        [[ -z "$(which gnome-terminal)" ]] && tmux new -s tdc_log
        tmux new-window -t tdc_log -n actions
        tmux new-window -t tdc_log -n errors
        tmux new-window -t tdc_log -n user-deleted
        tmux kill-window -t tdc_log:0
        sleep 0.5
        tmux send-keys -t tdc_log:actions "tdc-log-parser api-platform watch actions" 'C-m'
        tmux send-keys -t tdc_log:errors "tdc-log-parser api-platform watch errors" 'C-m'
        tmux send-keys -t tdc_log:user-deleted "tdc-log-parser api-platform watch user-deleted" 'C-m'
        tmux select-window -t tdc_log:actions


        tmux split-window -v -p 20
        sleep 0.5
        tmux pipe-pane -o -t "${session_name}":actions.0  "cat >> ${actions_pipe}"
        tmux select-pane -t "${session_name}":actions.1
        tmux send-keys -t "${session_name}":actions.1 "tdc-log-parser api-platform watch incomes" 'C-m'
    }

    in_tmux_2 () {
        # local session_name="tdc_log_2"
        # tmux kill-session -t "${session_name}"
        # [[ -n "$(which gnome-terminal)" ]] && gnome-terminal --window -- /usr/bin/tmux new -s "${session_name}"
        # [[ -z "$(which gnome-terminal)" ]] && tmux new -s "${session_name}"
        # tmux new-window -t "${session_name}" -n actions
        # tmux select-window -t "${session_name}":actions
        # tmux split-window -v -p 20
        # tmux kill-window -t "${session_name}":0
        # sleep 0.5
        # tmux select-pane -t "${session_name}":actions.0
        # tmux send-keys -t "${session_name}":actions "tdc-log-parser api-platform watch actions" 'C-m'
        # tmux select-pane -t "${session_name}":actions.1
        # tmux send-keys -t "${session_name}":actions "tdc-log-parser api-platform watch incomes" 'C-m'
        # tmux select-pane -t "${session_name}":actions.0

        # 2.1
        # local session_name="tdc_log_2"
        # tmux kill-session -t "${session_name}"
        # [[ -n "$(which gnome-terminal)" ]] && gnome-terminal --window -- /usr/bin/tmux new -s "${session_name}"
        # tmux rename-window -t "${session_name}":0 actions
        # tmux split-window -v -p 20
        #
        # sleep 0.5
        #
        # tmux send-keys -t "${session_name}":actions.0 "tdc-log-parser api-platform watch actions" 'C-m'
        # tmux pipe-pane -o -t "${session_name}":actions.0  'cat >> /tmp/tdc-api-actions.pipe'
        #
        # tmux select-pane -t "${session_name}":actions.1
        # tmux send-keys -t "${session_name}":actions.1 "tail -f /tmp/tdc-api-actions.pipe" 'C-m'

        # 2.2
        # local src_session_name="tdc_log"
        # local dst_session_name="tdc_log_summary"
        # tmux kill-session -t "${dst_session_name}"
        # [[ -n "$(which gnome-terminal)" ]] && gnome-terminal --window -- /usr/bin/tmux new -s "${dst_session_name}"
        # tmux rename-window -t "${dst_session_name}":0 actions
        # tmux split-window -v -p 20
        #
        # sleep 0.5
        # tmux capture-pane -p -t "${src_session_name}":actions.0  >/tmp/tdc-api-actions.pipe
        # tmux pipe-pane -o -t "${src_session_name}":actions.0  'cat >> /tmp/tdc-api-actions.pipe'
        # tmux select-pane -t "${dst_session_name}":actions.0
        # tmux send-keys -t "${dst_session_name}":actions.0 "tdc-log-parser api-platform watch incomes" 'C-m'

        # 2.3
        local session_name="tdc_log_summary"
        tmux kill-session -t "${session_name}"
        [[ -n "$(which gnome-terminal)" ]] && gnome-terminal --window -- /usr/bin/tmux new -s "${session_name}"
        tmux rename-window -t "${session_name}":0 actions
        tmux split-window -v -l 30 'tdc-log-parser api-platform watch incomes'

        sleep 0.5
        tmux capture-pane -p -t "${session_name}":actions.0  >/tmp/tdc-api-actions.pipe
        tmux pipe-pane -o -t "${session_name}":actions.0  'cat >> /tmp/tdc-api-actions.pipe'
        tmux send-keys -t "${session_name}":actions.0  'while :; do echo "preReadHandler camera_added"; sleep 3; done' 'C-m'
        tmux select-pane -t "${session_name}":actions.1
        # tmux send-keys -t "${session_name}":actions.1 "tdc-log-parser api-platform watch incomes" 'C-m'


    }

    tput_experimental() {
        tput sc; \
            tput cup $(($(tput lines)-2)) 0; \
            printf "Hello World"; \
            tput rc;
    }

    stats() {
        today="$(date +'%Y/%m/%d')"
        day_start="$(date +'%Y/%m/%d 00:00:00')"
        date_time_count=($(date +'%Y/%m/%d') $(cat /tmp/tdc-log-actions.pipe |
                grep -iE 'prereadhandler' |
                grep --color=never -ioE "[0-9]{2}:[0-9]{2}:[0-9]{2}" |
                tee >(printf "%s" "$(wc -l)") >(tail -1) >/dev/null |
                xargs -i printf '%s ' '{}'
        ))
        last_update="${date_time_count[@]::2}"
        events_count="${date_time_count[2]}"

        printf 'Period %s\x0a' "${day_start} - ${last_update}"
        # diff of timestamps would not change, therefore here's no conversion from UTC+0
        day_start_ts="$(date +%s -d "${day_start}")"
        last_update_ts="$(date +%s -d "${last_update}")"
        seconds_passed=$((${last_update_ts} - ${day_start_ts}))
        hours_passed=$(bc <<< "scale=2;${seconds_passed}/3600")

        events_per_hour=$(echo "${events_count} ${hours_passed}" | awk '{eps=$1 / $2; printf "%.2f", eps}')
        events_per_second=$(echo "${events_count} ${seconds_passed}" | awk '{eps=$1 / $2; printf "%.2f", eps}')
        printf 'Average for %d events %s\x0a' "${events_count}" "after ${seconds_passed} sec(${hours_passed} hr) ${events_per_second} events/sec(${events_per_hour} events/hr)"


        events_list=($( cat /tmp/tdc-log-actions.pipe |
                grep -iE 'prereadhandler' |
                grep --color=never -ioE "[0-9]{2}:[0-9]{2}:[0-9]{2}" |
                xargs -d '\n' -i printf '%s\x0a' '{}'
        ))

        echo "${#events_list[@]}"

        hourly_events_spread=()
        printf "Hourly spread size: %d \x0a" "${#hourly_events_spread[@]}"


        events_list=($( cat /tmp/tdc-log-actions.pipe |
                grep -iE 'prereadhandler' |
                grep --color=never -ioE "03:[0-9]{2}:[0-9]{2}" |
                xargs -d '\n' -i printf '%s\x0a' '{}'
        ))

        for ts in "${events_list[@]}"; do
            # cat /tmp/tdc-log-actions.pipe |
            # grep -iE 'prereadhandler' |
            # grep --color=never -i "${ts}" |
            # tee \
                #     >(grep -ioE '"action":"[^"]+"' | xargs -i printf '%s\x0a' "{}") \
                #     >(grep -ioE '"email":"[^"]+"' | xargs -i printf '%s ' "{}") \
                #     >/dev/null |
            # xargs -d '\n' -i printf '%s\x0a' '{}'

            cat /tmp/tdc-log-actions.pipe |
            grep --color=never -iE 'prereadhandler' |
            grep --color=never -i "${ts}" |
            grep --color=never -ioE '\{.+\}' |
            sed 's/\"{/{/g' |
            sed 's/}\"/}/g' |
            sed 's/\n//g' |
            jq -r '.event.email + " " + .event.action + " " + .event.camera_id'

            # tee >(jq -r .event.email | xargs -i echo -n "{}") >(jq -r .event.action | xargs -i echo -n "{}") >/dev/null |

            # tee >(jq -r '.event[] | .email + " " + .action') >/dev/null |
            # xargs -d '\n' -i echo "{}"

        done

        # for ts in "${events_list[@]}"; do
        #     ts_events_list=($( cat /tmp/tdc-log-actions.pipe |
        #             grep -iE 'prereadhandler' |
        #             grep --color=never -io "${ts}" |
        #             xargs -d '\n' -i printf '%s\x0a' '{}'
        #     ))
        #     event_occurrence_hour="$(date +%_H -d "TZ=\"UTC+0\" ${today} ${ts}")"
        #     hourly_events_spread[${event_occurrence_hour}]=$((hourly_events_spread[${event_occurrence_hour}] + 1))
        #     current_spread_value="${hourly_events_spread[${event_occurrence_hour}]}"
        #     printf "[%s] Events count %d, spread(%d)\x0a" "$(date +%H:%M:%S -d "TZ=\"UTC+0\" ${today} ${ts}")" "${#ts_events_list[@]}" "${current_spread_value}"
        # done

        # for hour in "${!hourly_events_spread[@]}"; do
        #     printf "[%d-%d] %d %s\x0a" "${hour}" "$((${hour} + 1))" "${hourly_events_spread[$hour]}"
        # done

    }

    case "${1}" in
        grph)
            stats
            exit 0
            ;;
    esac

    case "${1}" in
        api-platform)
            ;;
        lighttpd)
            ;;
        haproxy)
            ;;
        tmux)
            ${log_server} cat "${log_path}/api-platform.log" | sed 's/\\\"/"/g' >"${actions_pipe}"
            in_tmux
            ;;
        tmux2)
            in_tmux_2
            ;;
        swtmux)
            tmux select-window -t tdc_log:"${2}"
            ;;
        kill-tmux)
            tmux kill-session -t tdc_log
            rm -f "${actions_pipe}"
            ;;
        kill-tmux2)
            tmux kill-session -t tdc_log_summary
            rm -f  /tmp/tdc-api-actions.pipe
            ;;
    esac

    case "${1}" in
        tmux | tmux2 | swtmux | kill-tmux | kill-tmux2)
            exit 0
            ;;
    esac

    case "${2}" in
        watch)
            parser_cmd="${log_server} tail -f ${log_path}/${log_file} | sed 's/\\\\\\\"/\"/g'"
            ;;
    esac

    case "${3}" in
        user-deleted | camera-added)
            action="${3/-/_}"

            ${parser_cmd} |
            grep --color=always -E "${action}" |
            grep --color=always -Eo '"email":"[^"]+"' |
            sed 's/"//g' |
            cut -d ":" -f 2 |
            sort -u
            ;;
        errors)
            ${parser_cmd} |
            ${grep_cmd} -E '(CRITICAL|ERROR)'
            ;;
        actions)
            ${parser_cmd} |
            ${grep_cmd} -E '"(action|email)":"[^"]+"'
            ;;
        incomes)
            # summary label with span
            slwp="%-25s"
            while :; do
                clear
                cat "${actions_pipe}" |
                sed 's/\\\"/"/g' |
                ${grep_cmd} -iE '(preReadHandler|error|critical)' |
                tee \
                    >(grep -E "camera_added" | printf "${slwp}%d %b" "camera_added" "$(wc -l)" "\x0a")\
                    >(grep -E "camera_removed" | printf "${slwp}%d %b" "camera_removed" "$(wc -l)" "\x0a")\
                    >(grep -E "plan_purchased" | printf "${slwp}%d %b" "plan_purchased" "$(wc -l)" "\x0a")\
                    >(grep -E "plan_cancelled" | printf "${slwp}%d %b" "plan_cancelled" "$(wc -l)" "\x0a")\
                    >(grep -E "trial_used" | printf "${slwp}%d %b" "trial_used" "$(wc -l)" "\x0a")\
                    >(grep -E "user_deleted" | printf "${slwp}%d %b" "user_deleted" "$(wc -l)" "\x0a")\
                    >(grep -E "services_updated" | printf "${slwp}%d %b" "services_updated" "$(wc -l)" "\x0a")\
                    >(grep -E "(error|critical)" | printf "${slwp}%d %b" "errors" "$(wc -l)" "\x0a")\
                    >(printf "${slwp}[%s] %b${slwp}%d %b" "Time" "$(date +'%Y-%m-%d %H:%M:%S')" "\x0a" "total income" "$(wc -l)" "\x0a") \
                    > /dev/null | xargs -0 printf '%s'; \
                    # printf "\033[32m*\033[0m summary from the day start \x0a"; \
                    sleep 1
            done
            ;;
        *)
            ${parser_cmd}
            ;;
    esac

)

log-parser "${@}"
