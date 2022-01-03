#! /usr/bin/perl
#
# Webカメラ画像アップローダ : サーバ側スクリプト（ファイル受信, index作成）
#
# (C) INOUE Hirokazu
# GNU GPL Free Software (http://www.opensource.jp/gpl/gpl.ja.html)
#
# version 1.0 (2021/Dec/26)
use strict;
use utf8;
use warnings;
use CGI;
use File::Copy;
use File::Basename;
use FindBin;
use Digest::MD5 qw(md5 md5_hex md5_base64);

# デバッグ用 画面出力  1:あり, 0:なし
my $FLAG_DEBUG_PRINT = 1;

# アップロードされた画像の保存ディレクトリ
my $DIR_IMAGES = $FindBin::Bin . '/pics/';

# サムネイル画像の保存ディレクトリ
my $DIR_THUMBS = $FindBin::Bin . "/thumb/";

# アップロードされた画像を一時保存するディレクトリ
my $DIR_TEMP = $FindBin::Bin . '/temp/';

# IMAGESディレクトリ内に存在できる最大ファイル数（これ以上は削除処理する）
my $MAX_IMAGE_FILES = 100;

# パスワード（POSTパラメータ password_str と比較）のmd5値
# (サンプルとして pass0123 を入力している)
# (echo -n "pass0123" | md5sum)
my $PASSWORD_MD5_HEX = "595657cc9c7d72665f2293b101862501";

# スクリプト開始 main サブルーチンを呼び出す
main();

sub main {
    my $filename = receive_uploaded_file();
    make_thumb_image( basename($filename) );
    delete_old_files();
    make_index_html();
    return;
}

sub receive_uploaded_file {
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime;
    print "Content-Type: text/plain\n\n";
    my $q = CGI->new;

    # スクリプト呼び出し時の引数を画面表示する（デバッグ用）
    if ($FLAG_DEBUG_PRINT) {

        # POSTでデータ送受信の場合
        foreach my $param ( $q->param() ) {
            print "POST : $param = " . $q->param($param) . "\n";
        }

        # GETでデータ送受信（URLパラメーター）の場合
        foreach my $param ( $q->url_param() ) {
            print "GET (url param) : $param = " . $q->url_param($param) . "\n";
        }
    }
    if ( defined( $q->param('password_str') ) && length( $q->param('file_name') ) > 0 ) {
        if ( md5_hex( $q->param('password_str') ) ne $PASSWORD_MD5_HEX ) {
            print("error : password different\n");
            exit;
        }
    }
    else {
        print("error : no password\n");
        exit;
    }

    # アップロードされたファイルを保存するファイル名を、日時をベースとしたものとする
    my $filename = sprintf(
        "%s%04d-%02d-%02d_%02d-%02d-%02d.jpg",
        $DIR_IMAGES, $year + 1900,
        $mon + 1, $mday, $hour, $min, $sec
    );
    if ( defined( $q->param('file_name') ) && length( $q->param('file_name') ) > 0 ) {
        my $fh                       = $q->upload('file_name');
        my $tempfile                 = $q->tmpFileName($fh);
        my $flag_imagemagick_success = 1;
        if ($FLAG_DEBUG_PRINT) { print( "uploaded tempfile : " . $tempfile . "\n" ); }

        # アップロードされた一時ファイルが存在しない場合は、エラー（NULL文字列を返す）
        if ( !-f $tempfile ) {
            print("error : uploaded temp file is not exist\n");
            exit;
        }

        # アップロードされたファイルの拡張子が.jpgでない場合は、エラー（NULL文字列を返す）
        my @filename_split = split( /\./, $q->param('file_name') );
        if ( $filename_split[$#filename_split] ne "jpg" ) {
            print("error : filename ext is not jpg\n");
            exit;
        }

        # アップロードされたファイルを、一時ディレクトリから、ファイル名変更しつつ移動
        # (単純コピーは、不正なファイル、データが取り込まれる可能性があるため、imagemagickで変換コピーする)
        if ( !File::Copy::move( $tempfile, $DIR_TEMP . basename($filename) ) ) {
            print("error : temp file move fail\n");
            exit;
        }
        system( "convert -quality 50 " . $DIR_TEMP . basename($filename) . " " . $filename );
        close($fh);
        unlink( $DIR_TEMP . basename($filename) );
        if ( !-f $filename ) { print("error : temp file imagemagick convert fail\n"); exit; }
        if ($FLAG_DEBUG_PRINT) {
            printf( "file saved : %s\n", $filename );
        }
    }
    else {
        # POSTパラメータにfile_nameが存在しない場合はエラー
        print("error : file upload POST syntax\n");
        exit;
    }

    # アップロードファイルの受け取り成功時は、保存したファイル名を返す
    # (失敗した場合は その時点でメッセージを表示してdieでスクリプト終了済み)
    return $filename;
}

sub delete_old_files {
    ### (STEP 1/2) $DIR_IMAGES ディレクトリを処理
    my @filenames       = glob( $DIR_IMAGES . '*.jpg' );
    my @filenamesSorted = sort { $b cmp $a } @filenames;

    # IMAGESディレクトリ内にファイルが一つも無い場合はエラー
    if ( $#filenames < 0 ) {
        print "error : no image file in pics dir\n";
        return;
    }

    # IMAGESディレクトリ内のファイル一覧をデバッグ表示
    if ($FLAG_DEBUG_PRINT) {
        print( "Dir List (pics) , " . ( $#filenamesSorted + 1 ) . " files exist\n" );
        foreach my $filename (@filenamesSorted) {
            print( "  > " . $filename . "\n" );
        }
    }

    # MAX_IMAGE_FILES を超える数の画像ファイルを削除する
    if ( $#filenamesSorted > $MAX_IMAGE_FILES ) {
        for ( my $i = $MAX_IMAGE_FILES ; $i <= $#filenamesSorted ; $i++ ) {
            if ( !unlink( $filenamesSorted[$i] ) ) {
                if ($FLAG_DEBUG_PRINT) {
                    print( "  > delete FAIL ! : " . $filenamesSorted[$i] . "\n" );
                }
            }
            else {
                if ($FLAG_DEBUG_PRINT) { print( "  > delete : " . $filenamesSorted[$i] . "\n" ); }
            }
        }
    }
    ### (STEP 2/2) $DIR_THUMBS ディレクトリを処理
    @filenames       = ();
    @filenames       = glob( $DIR_THUMBS . '*.jpg' );
    @filenamesSorted = ();
    @filenamesSorted = sort { $b cmp $a } @filenames;

    # THUMBSディレクトリ内のファイル一覧をデバッグ表示
    if ($FLAG_DEBUG_PRINT) {
        print( "Dir List (thumbs) , " . ( $#filenamesSorted + 1 ) . " files exist\n" );
        foreach my $filename (@filenamesSorted) {
            print( "  > " . $filename . "\n" );
        }
    }

    # MAX_IMAGE_FILES を超える数の画像ファイルを削除する
    if ( $#filenamesSorted > $MAX_IMAGE_FILES ) {
        for ( my $i = $MAX_IMAGE_FILES ; $i <= $#filenamesSorted ; $i++ ) {
            if ( !unlink( $filenamesSorted[$i] ) ) {
                if ($FLAG_DEBUG_PRINT) {
                    print( "  > delete FAIL ! : " . $filenamesSorted[$i] . "\n" );
                }
            }
            else {
                if ($FLAG_DEBUG_PRINT) { print( "  > delete : " . $filenamesSorted[$i] . "\n" ); }
            }
        }
    }
    return;
}

sub make_index_html {
    ### IMAGES ディレクトリ内のファイル一覧を取得し、ファイル名でソート
    my @filenames       = glob( $DIR_IMAGES . '*.jpg' );
    my @filenamesSorted = sort { $b cmp $a } @filenames;
    ### index.html ファイルに書き込む
    my $fh       = undef;
    my $encoding = ":encoding(UTF-8)";
    open( $fh, "> $encoding", "index.html" ) or die("make_index_html : file oopen error\n");
    print( $fh
"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
          . "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"ja\" lang=\"ja\">\n"
          . "<head>\n"
          . "    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n"
          . "    <meta http-equiv=\"Content-Language\" content=\"ja\" />\n"
          . "    <title>image list</title>\n"
          . "</head>\n"
          . "<body>\n" );
    for ( my $i = 0 ; $i <= $#filenamesSorted ; $i++ ) {
        print(  $fh "<p><a href=\"pics/"
              . basename( $filenamesSorted[$i] ) . "\">"
              . "<img src=\"thumb/"
              . basename( $filenamesSorted[$i] ) . "\">"
              . basename( $filenamesSorted[$i] )
              . "<img></a></p>\n" );
    }
    print( $fh "</body>\n</html>\n" );
    close($fh) or die("make_index_html : file close error\n");
    if ($FLAG_DEBUG_PRINT) {
        print( "index.html created.  " . ( $#filenamesSorted + 1 ) . " image files listed\n" );
    }
    return;
}

sub make_thumb_image {

    #my $file_basename = shift;
    my ($file_basename) = @_;
    if ($FLAG_DEBUG_PRINT) { print( "imagemagick convert : thumbs/" . $file_basename . "\n" ); }
    system( "convert "
          . $DIR_IMAGES
          . $file_basename
          . " -resize 70x "
          . $DIR_THUMBS
          . $file_basename ) == 0
      or print( "imagemagick convert fail : " . $file_basename . "\n" );
    if ( !-f $DIR_THUMBS . $file_basename ) {
        print("error : thumb file imagemagick convert fail\n");
        exit;
    }
    return;
}
