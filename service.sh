#!/system/bin/sh
MODDIR="${0%/*}"

# ==================================================
# 守护核心 1：修复 Gemini 语音助手唤醒
# ==================================================
(
    do_gemini_fix() {
        GOOGLE_PKG="com.google.android.googlequicksearchbox"
        VOICE_SERVICE="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService"
        am force-stop $GOOGLE_PKG
        settings delete secure voice_interaction_service
        settings delete secure assistant
        sleep 1
        settings put secure voice_interaction_service $VOICE_SERVICE
        settings put secure assistant $VOICE_SERVICE
        am broadcast -a android.intent.action.USER_PRESENT -n $GOOGLE_PKG/.gsa.broadcastreceiver.ExternalBroadcastReceiver >/dev/null 2>&1
    }
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
    sleep 15; do_gemini_fix
    sleep 45; do_gemini_fix
) &

# ==================================================
# 守护核心 2：Smart DexOpt 空闲自动编译
# ==================================================
(
    MIN_BATTERY=60; MAX_TEMP=350; CHECK_INTERVAL=600; REST_AFTER_WORK=86400 
    while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 10; done
    sleep 60
    while true; do
        SCREEN_STATE=$(dumpsys power | grep 'mWakefulness=' | awk -F= '{print $2}')
        BATTERY_LEVEL=$(dumpsys battery | grep 'level:' | awk '{print $2}')
        if [ "$SCREEN_STATE" = "Asleep" ] && [ "$BATTERY_LEVEL" -ge "$MIN_BATTERY" ]; then
            sleep 180 
            if [ "$(dumpsys power | grep 'mWakefulness=' | awk -F= '{print $2}')" = "Asleep" ]; then
                CANCEL_FLAG=0
                BATTERY_TEMP_CHECK=$(dumpsys battery | grep 'temperature:' | awk '{print $2}')
                while [ "$BATTERY_TEMP_CHECK" -gt "$MAX_TEMP" ]; do
                    sleep 60 
                    if [ "$(dumpsys power | grep 'mWakefulness=' | awk -F= '{print $2}')" != "Asleep" ]; then CANCEL_FLAG=1; break; fi
                    BATTERY_TEMP_CHECK=$(dumpsys battery | grep 'temperature:' | awk '{print $2}')
                done
                if [ "$CANCEL_FLAG" -eq 1 ]; then sleep $CHECK_INTERVAL; continue; fi
                cmd package bg-dexopt-job
                sleep $REST_AFTER_WORK 
                continue
            fi
        fi
        sleep $CHECK_INTERVAL
    done
) &

# ==================================================
# 守护核心 3：ZIP 模块自动归类引擎 (修复带空格路径)
# ==================================================
(
    TARGET_DIR="/storage/emulated/0/Download/模块"
    LOG_FILE="$MODDIR/move_log.txt"
    MATCH_PATTERN="module\.prop|customize\.sh|service\.sh|action\.sh|post-fs-data\.sh|uninstall\.sh"
    
    WATCH_DIRS="
    /storage/emulated/999/Android/data/com.tencent.mobileqq/Tencent/QQfile_recv
    /storage/emulated/0/Android/data/com.tencent.mobileqq/Tencent/QQfile_recv
    /data/data/com.tencent.mm/MicroMsg/f65a3b31e7fd9cd472a299bbe9deccb3/attachment
    /storage/emulated/0/Android/data/org.telegram.messenger.web/files/Telegram/Telegram Files
    /storage/emulated/0/Download
    "

    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
    mkdir -p "$TARGET_DIR"; STATE_DIR="/dev/automove_states"; mkdir -p "$STATE_DIR"

    while true; do
        # 核心修复：使用 echo | while read -r 按行读取，彻底解决目录带空格(如Telegram Files)被截断的问题
        echo "$WATCH_DIRS" | while read -r dir; do
            # 过滤头尾不可见字符与多余空格
            dir=$(echo "$dir" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -z "$dir" ] || [ ! -d "$dir" ] && continue
            
            state_file="$STATE_DIR/$(echo "$dir" | tr '/' '_')"
            cur_time=$(stat -c %Y "$dir" 2>/dev/null)
            last_time=$(cat "$state_file" 2>/dev/null)

            if [ "$cur_time" != "$last_time" ]; then
                for zip_file in "$dir"/*.zip; do
                    [ -f "$zip_file" ] || continue
                    if unzip -l "$zip_file" 2>/dev/null | grep -qE "$MATCH_PATTERN"; then
                        filename=$(basename "$zip_file"); target_file="$TARGET_DIR/$filename"
                        log_time=$(date "+%m-%d %H:%M"); src_name=$(basename "$dir")
                        if [ -f "$target_file" ]; then
                            md5_src=$(md5sum "$zip_file" | awk '{print $1}')
                            md5_tgt=$(md5sum "$target_file" | awk '{print $1}')
                            if [ "$md5_src" = "$md5_tgt" ]; then
                                rm -f "$zip_file"; echo "[$log_time] $src_name: 已清理重复 $filename" >> "$LOG_FILE"
                            else
                                new_name="${filename%.zip}_$(date +%s).zip"
                                mv "$zip_file" "$TARGET_DIR/$new_name"
                                echo "[$log_time] $src_name: 归档并重命名 $new_name" >> "$LOG_FILE"
                            fi
                        else
                            mv "$zip_file" "$target_file"; echo "[$log_time] $src_name: 成功归档 $filename" >> "$LOG_FILE"
                        fi
                        echo "$(tail -n 100 "$LOG_FILE")" > "$LOG_FILE"
                    fi
                done
                echo "$cur_time" > "$state_file"
            fi
        done
        sleep 10
    done
) &

# ==================================================
# 守护核心 4：运存防线 (彻底修复计算溢出与乱杀 Bug)
# ==================================================
(
    RAM_CFG="$MODDIR/ram_config.ini"
    RAM_WHITE="$MODDIR/ram_white.conf"
    RAM_BLACK="$MODDIR/ram_black.conf"
    RAM_LOG="$MODDIR/ram.log"

    # 初始化配置
    [ ! -f "$RAM_CFG" ] && echo "avail_mem_percent=10" > "$RAM_CFG"
    [ ! -f "$RAM_WHITE" ] && echo -e "com.tencent.mm\ncom.tencent.mobileqq" > "$RAM_WHITE"
    [ ! -f "$RAM_BLACK" ] && touch "$RAM_BLACK"
    [ ! -f "$RAM_LOG" ] && touch "$RAM_LOG"
    chmod 666 "$RAM_CFG" "$RAM_WHITE" "$RAM_BLACK" "$RAM_LOG"

    get_threshold() {
        val=$(grep -v "^#" "$RAM_CFG" 2>/dev/null | grep "avail_mem_percent" | cut -d'=' -f2 | tr -dc '0-9')
        [ -n "$val" ] && echo "$val" || echo "10"
    }

    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 10; done
    sleep 30

    THRESHOLD_PERCENT=$(get_threshold)
    LAST_MTIME=$(stat -c %Z "$RAM_CFG" 2>/dev/null)
    echo "$(date '+%m-%d %H:%M:%S'): 防线引擎已启动，当前触发阈值: ${THRESHOLD_PERCENT}%" >> "$RAM_LOG"

    while true; do
        # 1. 监听配置修改
        CURRENT_MTIME=$(stat -c %Z "$RAM_CFG" 2>/dev/null)
        if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
            NEW_THRESHOLD=$(get_threshold)
            if [ -n "$NEW_THRESHOLD" ]; then
                THRESHOLD_PERCENT=$NEW_THRESHOLD
                echo "$(date '+%m-%d %H:%M:%S'): 阈值配置已热更: ${THRESHOLD_PERCENT}%" >> "$RAM_LOG"
            fi
            LAST_MTIME=$CURRENT_MTIME
        fi

        # 2. 获取内存 (极其防弹的纯 awk 写法，绝不会算出 0 或空值)
        CURRENT_PERCENT=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.0f", (a/t)*100}' /proc/meminfo)
        
        # 终极防爆锁：如果内核没吐出内存数据，强制设置 100%，坚决不杀！
        [ -z "$CURRENT_PERCENT" ] && CURRENT_PERCENT=100

        # 3. 触发防线
        if [ "$CURRENT_PERCENT" -lt "$THRESHOLD_PERCENT" ]; then
            
            # 黑名单优先杀
            if [ -s "$RAM_BLACK" ]; then
                for pkg in $(grep -v "^#" "$RAM_BLACK" | tr -d '\r' | grep -v "^$"); do
                    if pidof "$pkg" > /dev/null; then
                        am force-stop "$pkg"
                        echo "$(date '+%H:%M:%S'): 内存 ${CURRENT_PERCENT}%，黑名单击杀 -> $pkg" >> "$RAM_LOG"
                        sleep 1
                    fi
                done
            fi

            # 时间倒序查杀
            recent_pkgs=$(dumpsys activity recents | grep "realActivity=" | cut -d'=' -f2 | cut -d'/' -f1 | tr -d '{' | uniq | awk '{a[i++]=$0} END {for (j=i-1; j>=0; j--) print a[j]}')
            
            for pkg_name in $recent_pkgs; do
                if [ -z "$pkg_name" ] || [ "$pkg_name" = "android" ] || [ "$pkg_name" = "com.miui.home" ]; then continue; fi
                if grep -q -E "^${pkg_name}$" "$RAM_WHITE" 2>/dev/null; then continue; fi

                if pidof "$pkg_name" > /dev/null; then
                    am force-stop "$pkg_name"
                    echo "$(date '+%H:%M:%S'): 内存 ${CURRENT_PERCENT}% < ${THRESHOLD_PERCENT}%，倒序清理 -> $pkg_name" >> "$RAM_LOG"
                    
                    # 安全截断日志，绝不破坏文件权限
                    lines=$(wc -l < "$RAM_LOG" 2>/dev/null || echo 0)
                    if [ "$lines" -gt 150 ]; then
                        tail -n 100 "$RAM_LOG" > "$RAM_LOG.tmp" && cat "$RAM_LOG.tmp" > "$RAM_LOG" && rm -f "$RAM_LOG.tmp"
                    fi
                    
                    sleep 1
                    break 
                fi
            done
        fi
        sleep 10
    done
) &
