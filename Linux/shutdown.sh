#!/bin/bash

# 無効化するためのコマンド
if [ "$1" == "off" ]; then
    sudo crontab -r
    echo "シャットダウン設定を無効にしました。"
elif [ "$1" == "on" ]; then
    CRON_JOB="0 22 * * * /sbin/poweroff"
    CRONTAB_FILE=$(mktemp)

    # 現在の crontab を取得 (エラーを無視)
    sudo crontab -l > $CRONTAB_FILE 2>/dev/null

    # シャットダウン設定が既に存在するか確認し、無ければ追加
    if ! grep -Fxq "$CRON_JOB" $CRONTAB_FILE; then
        echo "$CRON_JOB" >> $CRONTAB_FILE
        sudo crontab $CRONTAB_FILE
        echo "シャットダウン設定を有効にしました。"
    else
        echo "シャットダウン設定は既に有効です。"
    fi

    # 一時ファイルを削除
    rm $CRONTAB_FILE
else
    echo "使用方法: $0 [on|off]"
fi
