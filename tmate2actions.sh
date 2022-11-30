#!/usr/bin/env bash
# 版权所有 (c) 2020 P3TERX <https://p3terx.com>
# 这是免费软件，根据MIT许可证许可。
# 有关详细信息，请参阅/LICENSE。
# https://github.com/P3TERX/ssh2actions
# 文件名：tmate2actions.sh
# 描述：使用tmate通过SSH连接到Github Actions VM
# 版本：2.0



#  设置环境变量
set -e
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"
TMATE_SOCK="/tmp/tmate.sock"
TELEGRAM_LOG="/tmp/telegram.log"
CONTINUE_FILE="/tmp/continue"

# 在macOS或Ubuntu上安装tmate
echo -e "${INFO} 正在设置 tmate ..."
if [[ -n "$(uname | grep Linux)" ]]; then
    curl -fsSL git.io/tmate.sh | bash
elif [[ -x "$(command -v brew)" ]]; then
    brew install tmate
else
    echo -e "${ERROR} 不支持此系统!!!"
    exit 1
fi

# 如果需要，生成ssh密钥
[[ -e ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# 监控 tmate 运行状态
echo -e "${INFO} 运行 tmate..."
tmate -S ${TMATE_SOCK} new-session -d
tmate -S ${TMATE_SOCK} wait tmate-ready

# 打印连接信息
TMATE_SSH=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_ssh}')
TMATE_WEB=$(tmate -S ${TMATE_SOCK} display -p '#{tmate_web}')
MSG="
*GitHub操作-tmate会话信息:*

⚡ *CLI:*
\`${TMATE_SSH}\`

🔗 *URL:*
${TMATE_WEB}

🔔 *TIPS:*
Run '\`touch ${CONTINUE_FILE}\`' 继续下一步.
"

if [[ -n "${TELEGRAM_BOT_TOKEN}" && -n "${TELEGRAM_CHAT_ID}" ]]; then
    echo -e "${INFO} 正在将消息发送到Telegram......."
    curl -sSX POST "${TELEGRAM_API_URL:-https://api.telegram.org}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=Markdown" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MSG}" >${TELEGRAM_LOG}
    TELEGRAM_STATUS=$(cat ${TELEGRAM_LOG} | jq -r .ok)
    if [[ ${TELEGRAM_STATUS} != true ]]; then
        echo -e "${ERROR} 消息发送失败: $(cat ${TELEGRAM_LOG})"
    else
        echo -e "${INFO} 消息发送成功!"
    fi
fi

while ((${PRT_COUNT:=1} <= ${PRT_TOTAL:=10})); do
    SECONDS_LEFT=${PRT_INTERVAL_SEC:=10}
    while ((${PRT_COUNT} > 1)) && ((${SECONDS_LEFT} > 0)); do
        echo -e "${INFO} (${PRT_COUNT}/${PRT_TOTAL}) 请稍候 ${SECONDS_LEFT}s ..."
        sleep 1
        SECONDS_LEFT=$((${SECONDS_LEFT} - 1))
    done
    echo "-----------------------------------------------------------------------------------"
    echo "要连接到此会话，请将以下内容复制并粘贴到终端或浏览器中:"
    echo -e "SSH 终端连接:  ${Green_font_prefix}${TMATE_SSH}${Font_color_suffix}"
    echo -e "WEB 连接地址:  ${Green_font_prefix}${TMATE_WEB}${Font_color_suffix}"
    echo -e "提示：运行 'touch ${CONTINUE_FILE}' 继续下一步."
    echo "-----------------------------------------------------------------------------------"
    PRT_COUNT=$((${PRT_COUNT} + 1))
done

while [[ -S ${TMATE_SOCK} ]]; do
    sleep 1
    if [[ -e ${CONTINUE_FILE} ]]; then
        echo -e "${INFO} 继续下一步."
        exit 0
    fi
done

# ref: https://github.com/csexton/debugger-action/blob/master/script.sh
