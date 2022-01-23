カメラ画像や温湿度データをサーバに送信・保管し、Webブラウザで閲覧するソフトウエア

---

## web-loggraph
Webサーバに温湿度計測値をアップロード(Perlスクリプト)

![web-loggraphの概念図](web-loggraph/readme_pics/tempgraph-schematic.png)

Linuxが稼働するレンタルサーバに、温湿度・気圧（BMP280やDHT11で計測）の計測値をアップロードし、グラフ表示させるスクリプト

[詳細説明、ソフトウエアのダウンロードはこちら](web-loggraph/)


## webcamera-uploader
WebサーバにUSBカメラの画像をアップロード(Perlスクリプト)

![webcamera-uploaderの概念図](webcamera_uploader/readme_pics/webcamera-uploader-schematic.png)

Linuxが稼働するレンタルサーバに、Webカメラ（USB接続カメラ）で撮影した画像ファイルをアップロードし、一覧表示させるスクリプト

[詳細説明、ソフトウエアのダウンロードはこちら](webcamera_uploader/)


## googledrive-webcamera
GoogleDriveにUSBカメラの画像をアップロード(Pythonスクリプト)

![googledrive-webcameraの概念図](googledrive-webcamera/readme_pics/gdrive-schematic.png)

Webカメラ（USB接続カメラ）で撮影した画像ファイルを、Googleドライブにアップロードします。

[詳細説明、ソフトウエアのダウンロードはこちら](googledrive-webcamera/)