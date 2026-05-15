#!/system/bin/sh
MODDIR="${0%/*}"

# ==================================================
# 守护核心 1：修复 Gemini 语音助手唤醒 (开机双段加固)
# ==================================================
(
    # 封装核心修复逻辑为一个函数
    do_gemini_fix() {
        GOOGLE_PKG="com.google.android.googlequicksearchbox"
        VOICE_SERVICE="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService"

        # 强行停止以清除僵尸进程缓存
        am force-stop $GOOGLE_PKG
        # 彻底解绑
        settings delete secure voice_interaction_service
        settings delete secure assistant
        sleep 1
        # 重新强制绑定
        settings put secure voice_interaction_service $VOICE_SERVICE
        settings put secure assistant $VOICE_SERVICE
        # 发送广播激活
        am broadcast -a android.intent.action.USER_PRESENT -n $GOOGLE_PKG/.gsa.broadcastreceiver.ExternalBroadcastReceiver >/dev/null 2>&1
    }

    # 等待系统完全开机标志
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
    
    # 【第一段介入】：开机后 15 秒，抢先修复，保证用户一解锁就能用
    sleep 15
    do_gemini_fix
    
    # 【第二段加固】：额外等待 45 秒（即开机后 60 秒）
    # 此时系统所有高负载初始化已结束，桌面完全稳定。再执行一次确保不会被系统重置
    sleep 45
    do_gemini_fix
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
# 守护核心 3：ZIP 模块自动归类引擎 (重定向逻辑)
# ==================================================
(
    TARGET_DIR="/storage/emulated/0/Download/模块"
    LOG_FILE="$MODDIR/move_log.txt"
    MATCH_PATTERN="module\.prop|customize\.sh|service\.sh|action\.sh|post-fs-data\.sh|uninstall\.sh"
    
    # 监控路径列表
    WATCH_DIRS="
    /storage/emulated/999/Android/data/com.tencent.mobileqq/Tencent/QQfile_recv
    /storage/emulated/0/Android/data/com.tencent.mobileqq/Tencent/QQfile_recv
    /data/data/com.tencent.mm/MicroMsg/f65a3b31e7fd9cd472a299bbe9deccb3/attachment
    /storage/emulated/0/Android/data/org.telegram.messenger.web/files/Telegram/Telegram Files
    /storage/emulated/0/Download
    storage/emulated/0
    "

    # 等待开机
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
    mkdir -p "$TARGET_DIR"
    STATE_DIR="/dev/automove_states"
    mkdir -p "$STATE_DIR"

    while true; do
        # 使用 for 循环避免子 Shell 变量丢失，同时兼容换行
        for dir in $WATCH_DIRS; do
            # 清理可能的隐藏换行符
            dir=$(echo "$dir" | tr -d '\r')
            
            [ -z "$dir" ] || [ ! -d "$dir" ] && continue
            
            state_file="$STATE_DIR/$(echo "$dir" | tr '/' '_')"
            cur_time=$(stat -c %Y "$dir" 2>/dev/null)
            last_time=$(cat "$state_file" 2>/dev/null)

            if [ "$cur_time" != "$last_time" ]; then
                for zip_file in "$dir"/*.zip; do
                    [ -f "$zip_file" ] || continue
                    
                    if unzip -l "$zip_file" 2>/dev/null | grep -qE "$MATCH_PATTERN"; then
                        filename=$(basename "$zip_file")
                        target_file="$TARGET_DIR/$filename"
                        log_time=$(date "+%m-%d %H:%M")
                        
                        # 取路径最后一段作为日志来源名
                        src_name=$(basename "$dir")
                        
                        if [ -f "$target_file" ]; then
                            md5_src=$(md5sum "$zip_file" | awk '{print $1}')
                            md5_tgt=$(md5sum "$target_file" | awk '{print $1}')
                            if [ "$md5_src" = "$md5_tgt" ]; then
                                rm -f "$zip_file"
                                echo "[$log_time] $src_name 目录: 已清理重复包 $filename" >> "$LOG_FILE"
                            else
                                new_name="${filename%.zip}_$(date +%s).zip"
                                mv "$zip_file" "$TARGET_DIR/$new_name"
                                echo "[$log_time] $src_name 目录: 归档并重命名 $new_name" >> "$LOG_FILE"
                            fi
                        else
                            mv "$zip_file" "$target_file"
                            echo "[$log_time] $src_name 目录: 成功归档 $filename" >> "$LOG_FILE"
                        fi
                        # 维持日志不至于无限大，最多100行
                        echo "$(tail -n 100 "$LOG_FILE")" > "$LOG_FILE"
                    fi
                done
                # 记录最后修改时间
                echo "$cur_time" > "$state_file"
            fi
        done
        # 每 10 秒巡逻一次
        sleep 10
    done
) &
# ==================================================
# 守护核心 4：运存防线 (严格时间倒序精准杀后台)
# ==================================================
(
    RAM_CFG="$MODDIR/ram_config.ini"
    RAM_WHITE="$MODDIR/ram_white.conf"
    RAM_BLACK="$MODDIR/ram_black.conf"
    RAM_LOG="$MODDIR/ram.log"

    # 如果配置不存在，初始化默认文件
    [ ! -f "$RAM_CFG" ] && echo "avail_mem_percent=10" > "$RAM_CFG"
    [ ! -f "$RAM_WHITE" ] && echo -e "com.tencent.mm\ncom.tencent.mobileqq" > "$RAM_WHITE"
    [ ! -f "$RAM_BLACK" ] && touch "$RAM_BLACK"

    get_threshold() {
        grep -v "^#" "$RAM_CFG" | grep "avail_mem_percent" | cut -d'=' -f2 | tr -d '\r' | tr -d ' '
    }

    # 延迟启动，避免开机拥堵
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 10; done
    sleep 30

    THRESHOLD_PERCENT=$(get_threshold)
    [ -z "$THRESHOLD_PERCENT" ] && THRESHOLD_PERCENT=10
    LAST_MTIME=$(stat -c %Z "$RAM_CFG" 2>/dev/null)

    echo "$(date '+%m-%d %H:%M:%S'): 防线已启动(倒序模式)，阈值: ${THRESHOLD_PERCENT}%" >> "$RAM_LOG"

    while true; do
        # 1. 监听配置是否修改
        CURRENT_MTIME=$(stat -c %Z "$RAM_CFG" 2>/dev/null)
        if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
            NEW_THRESHOLD=$(get_threshold)
            if [ -n "$NEW_THRESHOLD" ]; then
                THRESHOLD_PERCENT=$NEW_THRESHOLD
                echo "$(date '+%m-%d %H:%M:%S'): 热更配置，新阈值: ${THRESHOLD_PERCENT}%" >> "$RAM_LOG"
            fi
            LAST_MTIME=$CURRENT_MTIME
        fi

        # 2. 读取内存
        MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        MEM_AVAIL=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        CURRENT_PERCENT=$(( MEM_AVAIL * 100 / MEM_TOTAL ))

        # 3. 触发查杀
        if [ "$CURRENT_PERCENT" -lt "$THRESHOLD_PERCENT" ]; then
            # 黑名单秒杀
            if [ -s "$RAM_BLACK" ]; then
                for pkg in $(grep -v "^#" "$RAM_BLACK" | tr -d '\r' | grep -v "^$"); do
                    if pidof "$pkg" > /dev/null; then
                        am force-stop "$pkg"
                        echo "$(date '+%H:%M:%S'): 内存 ${CURRENT_PERCENT}%，黑名单击杀 -> $pkg" >> "$RAM_LOG"
                        sleep 1
                    fi
                done
            fi

            # 时间倒序查杀 (获取多任务列表并倒排)
            recent_pkgs=$(dumpsys activity recents | grep "realActivity=" | cut -d'=' -f2 | cut -d'/' -f1 | tr -d '{' | uniq | awk '{a[i++]=$0} END {for (j=i-1; j>=0; j--) print a[j]}')
            
            for pkg_name in $recent_pkgs; do
                if [ -z "$pkg_name" ] || [ "$pkg_name" = "android" ] || [ "$pkg_name" = "com.miui.home" ]; then
                    continue
                fi
                if grep -q -E "^${pkg_name}$" "$RAM_WHITE" 2>/dev/null; then 
                    continue
                fi

                if pidof "$pkg_name" > /dev/null; then
                    am force-stop "$pkg_name"
                    echo "$(date '+%H:%M:%S'): 内存 ${CURRENT_PERCENT}% < ${THRESHOLD_PERCENT}%，倒序清理 -> $pkg_name" >> "$RAM_LOG"
                    # 日志控制在100行防爆
                    tail -n 100 "$RAM_LOG" > "$RAM_LOG.tmp" && mv "$RAM_LOG.tmp" "$RAM_LOG"
                    sleep 1
                    break 
                fi
            done
        fi
        sleep 10
    done
) &
