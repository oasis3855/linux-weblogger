#!/usr/bin/env python
# -*- coding: utf-8 -*-

# PyDrive : web camera jpeg uploader for Google Drive
# Webカメラのjpeg画像をGoogle Driveにアップロードするスクリプト

# Googleドライブ利用のためのPythonパッケージ2個必要
# > pip install google-api-python-client
# > pip install PyDrive

# (C) INOUE Hirokazu
# GNU GPL Free Software (http://www.opensource.jp/gpl/gpl.ja.html)
#
# version 1.0 (2019/Feb/07)
# version 1.1 (2021/Dec/30) - Python3対応

import datetime
# commandsモジュールはPython2.6で廃止されたため、Python3ではsubprocessを使用
#import commands
import subprocess
import sys
import os

from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive

# 指定フォルダのID
# GoogleドライブをWebブラウザで表示した時のURLよりID部分をコピーする
drive_folder_id = '5Ycn_hYk36Niemo-mRcZua3j1bQV2u8Df'

# メッセージ出力の有効化
message_enable = 1

if len(sys.argv) == 2 and sys.argv[1] == '--nomessage':
    message_enable = 0
else:
    print(
        "PyDrive upload webcam capture image\n  usage :\n  %s [--nomessage]\n" % sys.argv[0])


# スクリプト自身のディレクトリに、client_secrets.json と settings.yaml が保存されていること
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Googleドライブに登録するファイル名の作成
time_now = datetime.datetime.now()
image_filename = format(time_now, "image_%Y%m%d-%H%M%S.jpg")

# Webカメラで撮影し保存するファイル名（一時ファイル）
temp_filename = "/tmp/temp_webcamera.jpg"
# 一時ファイルがすでに存在していれば削除する
if os.path.exists(temp_filename):
    os.remove(temp_filename)

# Webカメラで撮影
# commandsモジュールはPython3では使えないため、subprocessに移行
#str_result = commands.getoutput("fswebcam -D 3 -S 50 -v -r 640x480 %s" % temp_filename)
str_command = "fswebcam -D 3 -S 50 -v -r 640x480 " + temp_filename
arr_result = subprocess.run(str_command.split(
    " "), encoding='utf-8', stdout=subprocess.PIPE, stderr=subprocess.PIPE)

# 撮影したファイルが存在するか確認
if(os.path.exists(temp_filename) is not True):
    if message_enable == 1:
        print("image file capture error")
    sys.exit()
else:
    if message_enable == 1:
        print("image file captured : %s" % temp_filename)

try:
    if message_enable == 1:
        print("connect to Google Drive ...")

    # PyDriveでGoogleドライブに接続
    gauth = GoogleAuth()
    gauth.CommandLineAuth()
    drive = GoogleDrive(gauth)

    if message_enable == 1:
        print("upload %s to Google Drive ..." % image_filename)

    # 画像ファイルのアップロード
    file = drive.CreateFile({'title': image_filename,
                             'parents': [{'id': drive_folder_id}],
                             'mimeType': 'image/jpeg'})
    file.SetContentFile(temp_filename)
    file.Upload()

except Exception as e:
    print("===== PyDrive fatal error =====")
    print(e)
    sys.exit()
finally:
    if os.path.exists(temp_filename):
        os.remove(temp_filename)

if message_enable == 1:
    print('done all')
