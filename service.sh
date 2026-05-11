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
