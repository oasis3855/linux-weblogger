#!/usr/bin/perl
#
# Webカメラ画像アップローダ : クライアント側スクリプト（撮影とアップロード）
#
# (C) INOUE Hirokazu
# GNU GPL Free Software (http://www.opensource.jp/gpl/gpl.ja.html)
#
# version 1.0 (2021/Dec/26)

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;

# パスワード（POSTパラメータ password_str で送信する）
# (サンプルとして pass0123 を入力している)
my $PASSWORD_PLAIN = "pass0123";

# 受信サーバのURL
my $url = "http://www.example.com/cgi-bin/img_uploader/img_receive.cgi";

### Webカメラのデバイスファイル名（カメラを接続した時に lsusb コマンド等で事前確認）
if ( !-e "/dev/video0" ) {
    print("/dev/video0 offline. try bind usb 1-1 ...\n");
    exit;
}

### Webカメラで撮影した画像を一時保存するファイル名
my $fn = "/tmp/img_send_temp.jpg";

### 一時保存の画像ファイルが存在していれば、撮影前に削除する
if ( -f $fn ) {
    print( $fn . " exist. delete it ...\n" );
    unlink($fn);
}
### Webカメラで撮影し、一時ファイルに保存
system( "fswebcam --quiet --delay 3 --skip 50 --resolution 640x480  " . $fn );

### 画像の一時ファイルが存在しない場合は、撮影失敗のため、スクリプトを終了
if ( !-f $fn ) {
    print( "file " . $fn . " not exist\n" );
    exit;
}

print( "upload url : " . $url . "\n" );
### サーバに画像ファイルをアップロード
my $ua  = LWP::UserAgent->new;
my $req = POST(
    $url,
    'Content_Type' => 'form-data',
    'Content'      => [
        param1       => 'parameter 1',
        param2       => 'parameter 2',
        password_str => $PASSWORD_PLAIN,
        file_name    => [$fn]
    ],
);
### （Basic認証あり）
$req->authorization_basic( 'SAMPLE_USER', 'USER_PASSWORD' );

my $res = $ua->request($req);

print "result = " . $res->as_string() . "\n";
