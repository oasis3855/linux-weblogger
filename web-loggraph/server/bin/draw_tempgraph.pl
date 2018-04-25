#!/usr/bin/perl
# draw_tempgraph.pl  -  温度データのグラフを描画しPNGファイルに保存する。また、最終追加データをテキスト出力する
#
# このスクリプトをサーバ側に置き、webブラウザ経由で画面表示させる
#
# 2018/Apr/15  ver 1.0
# 2018/Apr/25  ver 1.1  - 湿度グラフ追加

use strict;
use warnings;

use Time::Local;
use GD;
use DBI;
my $WIDTH  = 500;
my $HEIGHT = 250;
my $MARGIN = 10;
my $timeMin;
my $timeMax;
my $tempMin = 0;
my $tempMax = 50;
my $humidMin = 20;
my $humidMax = 70;

# DSNファイル名は相対パス（一旦ホームディレクトリに戻って、binを参照）
my $strSqlDsn     = 'DBI:SQLite:dbname=../bin/data.sqlite3';    # DSN
my $filenameSql = '../bin/data.sqlite3';
my $filenameGraph_1 = '../temperature_graph.png';
my $filenameGraph_2 = '../temperature_humid.png';

sub drawTempgraph {

    # 引数
    ( $timeMin, $timeMax, $tempMin, $tempMax ) = @_;

    # 引数の汚染除去のための「数値化」と、前後関係チェック
    $timeMin = $timeMin + 0;
    $timeMax = $timeMax + 0;
    $tempMin = $tempMin + 0;
    $tempMax = $tempMax + 0;
    if ( $timeMin > $timeMax ) { return; }
    if ( $tempMin > $tempMax ) { return; }

#    print "<p>$timeMin, $timeMax, $tempMin, $tempMax</p>";

    my $image_1 = new GD::Image( $WIDTH + $MARGIN * 2, $HEIGHT + $MARGIN * 2 );
    my $image_2 = new GD::Image( $WIDTH + $MARGIN * 2, $HEIGHT + $MARGIN * 2 );

    # カラー インデックス
    my $colorWhite_1 = $image_1->colorAllocate( 255, 255, 255 );
    my $colorWhite_2 = $image_2->colorAllocate( 255, 255, 255 );
    my $colorRed   = $image_1->colorAllocate( 200, 0,   0 );
    my $colorGreen = $image_1->colorAllocate( 0,   200, 0 );
    my $colorBlue = $image_2->colorAllocate( 75,   75, 200 );

    # 背景色を透明
    $image_1->transparent($colorWhite_1);
    $image_2->transparent($colorWhite_2);

    # 座標軸を描画
    imageDrawGrid( \$image_1, $timeMin, $timeMax, $tempMin, $tempMax );
    imageDrawGrid( \$image_2, $timeMin, $timeMax, $humidMin, $humidMax );

#    $timeMin = timelocal( 0, 0, 0, 15, 4 - 1, 2016 - 1900 );  # 2018/1/1 0:00:00
#    $timeMax = timelocal( 0, 0, 0, 15, 4 - 1, 2018 - 1900 );  # 2018/1/2 0:00:00

    my $x1;
    my $y1;
    my $x2;
    my $y2;

    # データベースより温度データの取り出し
    my @dummy;
    databaseGetData( $timeMin, $timeMax, \@dummy );

    foreach my $arr (@dummy) {

        $x1 = $arr->[0];
        $y1 = $arr->[2];
        if ( $tempMax > $y1 && $y1 > $tempMin ) {
            convParam( \$y1, \$x1, $timeMin, $timeMax, $tempMin, $tempMax );
            #            $image->setPixel($x1,$y1,$colorGreen);
            $image_1->arc( $x1, $y1, 2, 2, 0, 360, $colorGreen );
        }
        $x1 = $arr->[0];
        $y1 = $arr->[1];
        if ( $tempMax > $y1 && $y1 > $tempMin ) {
            convParam( \$y1, \$x1, $timeMin, $timeMax, $tempMin, $tempMax );
            $image_1->arc( $x1, $y1, 2, 2, 0, 360, $colorRed );
        }
        $x1 = $arr->[0];
        $y1 = $arr->[3];
        if ( $humidMax > $y1 && $y1 > $humidMin ) {
            convParam( \$y1, \$x1, $timeMin, $timeMax, $humidMin, $humidMax );
            $image_2->arc( $x1, $y1, 2, 2, 0, 360, $colorBlue );
        }
    }

    # GDイメージを画像ファイルに書き込み
    # （画像ファイルに「読み書き許可」があること。Web CGIから用いる場合は特に注意）
    eval {
        open( FILE_1, "> $filenameGraph_1" ) or die($!);
        binmode FILE_1;
        print FILE_1 $image_1->png;
        close(FILE_1);

        open( FILE_2, "> $filenameGraph_2" ) or die($!);
        binmode FILE_2;
        print FILE_2 $image_2->png;
        close(FILE_2);
    };
    if ($@) {
        print "$@";
        exit;
    }

    # データ数を返す
    return scalar(@dummy);
}

# 温度・時刻の実データを画像座標に変換する
sub convParam {
    my ($refY, $refX, $x_min, $x_max, $y_min, $y_max ) = @_;

    $$refX =
      $WIDTH * ( $$refX - $x_min ) / ( $x_max - $x_min ) + $MARGIN;
    $$refY =
      $HEIGHT -
      $HEIGHT * ( $$refY - $y_min ) / ( $y_max - $y_min ) +
      $MARGIN;
}

# GDイメージに座標軸を描画
sub imageDrawGrid {
    my ($image, $x_min, $x_max, $y_min, $y_max ) = @_;

    # カラー インデックス
    my $colorWhite = $$image->colorAllocate( 255, 255, 255 );
    my $colorBlack = $$image->colorAllocate( 0,   0,   0 );
    my $colorGray  = $$image->colorAllocate( 150, 150, 150 );
    my $colorRed   = $$image->colorAllocate( 200, 0,   0 );
    my $colorGreen = $$image->colorAllocate( 0,   200, 0 );

    # 縦軸（左端）
    my $x1 = $x_min;
    my $y1 = $y_min;
    my $x2 = $x_min;
    my $y2 = $y_max;
    convParam( \$y1, \$x1, $x_min, $x_max, $y_min, $y_max );
    convParam( \$y2, \$x2, $x_min, $x_max, $y_min, $y_max );
    $$image->line( $x1, $y1, $x2, $y2, $colorBlack );

    # 横軸（下端）
    $x1 = $x_min;
    $y1 = $y_min;
    $x2 = $x_max;
    $y2 = $y_min;
    convParam( \$y1, \$x1, $x_min, $x_max, $y_min, $y_max );
    convParam( \$y2, \$x2, $x_min, $x_max, $y_min, $y_max );
    $$image->line( $x1, $y1, $x2, $y2, $colorBlack );

    # 縦軸（温度）目盛線
    for ( my $i = ( int( $y_min / 10 ) + 1 ) * 10 ; $i < $y_max ; $i += 10 )
    {
        $x1 = $x_min;
        $y1 = $i;
        $x2 = $x_max;
        $y2 = $i;
        convParam( \$y1, \$x1, $x_min, $x_max, $y_min, $y_max );
        convParam( \$y2, \$x2, $x_min, $x_max, $y_min, $y_max );
        $$image->line( $x1, $y1, $x2, $y2, $colorGray );

        $$image->string( gdSmallFont, 0, $y1, $i, $colorBlack );
    }

    # 横軸（時間）目盛線
    if ( $x_max - $x_min <= 3 * ( 24 + 1 ) * 60 * 60 ) {

        # 3日+1h以内の場合、2時間毎の目盛線
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($x_min);
        my $hourStart =
          timelocal( 0, 0, ( int( $hour / 2 ) + 1 ) * 2, $mday, $mon, $year );
        for ( my $i = $hourStart ; $i < $x_max ; $i += 2 * 60 * 60 ) {
            $x1 = $i;
            $y1 = $y_min;
            $x2 = $i;
            $y2 = $y_max;
            convParam( \$y1, \$x1, $x_min, $x_max, $y_min, $y_max );
            convParam( \$y2, \$x2, $x_min, $x_max, $y_min, $y_max );
            ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($i);
            $$image->line( $x1, $y1, $x2, $y2,
                           $hour == 0 ? $colorBlack : $colorGray );

            $$image->string( gdTinyFont, $x1, $HEIGHT + $MARGIN,
                             $hour, $colorBlack );
        }
    } elsif ( $x_max - $x_min <= 15 * 24 * 60 * 60 ) {

        # 15日以内の場合、1日毎の目盛線
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($x_min);
        my $hourStart = timelocal( 0, 0, 0, $mday + 1, $mon, $year );
        for ( my $i = $hourStart ; $i < $x_max ; $i += 24 * 60 * 60 ) {
            $x1 = $i;
            $y1 = $y_min;
            $x2 = $i;
            $y2 = $y_max;
            convParam( \$y1, \$x1, $x_min, $x_max, $y_min, $y_max );
            convParam( \$y2, \$x2, $x_min, $x_max, $y_min, $y_max );
            ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($i);
            $$image->line( $x1, $y1, $x2, $y2,
                           $mday % 5 == 0 ? $colorBlack : $colorGray );

            $$image->string( gdTinyFont, $x1, $HEIGHT + $MARGIN,
                             $mday, $colorBlack );
        }
    } elsif ( $x_max - $x_min <= 2 * 365 * 24 * 60 * 60 ) {

        # 2年以内の場合、1ヶ月毎の目盛線
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($x_min);
        my $hourStart = timelocal( 0, 0, 0, 1, $mon + 1, $year );
        my @strMonth = (
                         'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                         'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
        );
        for ( my $i = $hourStart ; $i < $x_max ; ) {
            $x1 = $i;
            $y1 = $y_min;
            $x2 = $i;
            $y2 = $y_max;
            convParam( \$y1, \$x1, $x_min, $x_max, $y_min, $y_max );
            convParam( \$y2, \$x2, $x_min, $x_max, $y_min, $y_max );
            ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($i);
            $$image->line( $x1, $y1, $x2, $y2,
                           $mday % 5 == 0 ? $colorBlack : $colorGray );

            $$image->string( gdTinyFont, $x1, $HEIGHT + $MARGIN,
                             $strMonth[$mon], $colorBlack );

            # 翌月1日に繰り上げる
            if ( $mon >= 11 ) {
                $mon = 0;
                $year++;
            } else {
                $mon++;
            }
            $i = timelocal( 0, 0, 0, 1, $mon, $year );
        }
    }

}

# データベースより温度データを読み込む
# （データベースファイルに「読み書き許可」があること。Web CGIから用いる場合は特に注意）
sub databaseGetData {

    # 引数
    my ( $timeStart, $timeEnd, $refData ) = @_;

    my $dbh = undef;
    my $sth = undef;
    my $count;

    eval {
        # データベースに接続
        $dbh = DBI->connect( $strSqlDsn, "", "",
                             { PrintError => 0, AutoCommit => 0 } );
        if ( !$dbh ) { return 0; }

        # SQL文を構築する
        my $strQuery =
"select datatime, temp_sys, temp_room, humid, pressure from graphdata where datatime >= ? and datatime <= ?";
        $sth = $dbh->prepare($strQuery);

        # SQLを発行する
        if ($sth) {
            $sth->execute( $timeStart, $timeEnd );
        }    # 規定間隔より10秒余裕をみる
        while ( my @arr = $sth->fetchrow_array() ) {
            push( @{$refData}, \@arr );

            #            print " " . $arr[1] . ", " . $arr[2] . "\n";
        }
        if ($sth) { $sth->finish(); }
        $dbh->disconnect();
    };
    if ($@) {

        # evalによるエラートラップ：エラー時の処理
        $dbh->disconnect();
        return 0;
    }

}

# 最後に追加されたデータを（画面表示用に）出力する
sub printLastAddedData {

    # 引数
    ( $timeMin, $timeMax, $tempMin, $tempMax ) = @_;

    # 引数の汚染除去のための「数値化」と、前後関係チェック
    $timeMin = $timeMin + 0;
    $timeMax = $timeMax + 0;
    $tempMin = $tempMin + 0;
    $tempMax = $tempMax + 0;
    if ( $timeMin > $timeMax ) { return; }
    if ( $tempMin > $tempMax ) { return; }

    my ( $sec, $min, $hour, $mday, $mon, $year );

    # データベースより温度データの取り出し
    my $dbh = undef;
    my $sth = undef;
    my $count;

    eval {
        # データベースに接続
        $dbh = DBI->connect( $strSqlDsn, "", "",
                             { PrintError => 0, AutoCommit => 0 } );
        if ( !$dbh ) { return 0; }

        # SQL文を構築する
        my $strQuery =
"select datatime, temp_sys, temp_room, humid, pressure from graphdata where datatime >= ? and datatime <= ? order by datatime desc limit 5";
        $sth = $dbh->prepare($strQuery);

        # SQLを発行する
        if ($sth) {
            $sth->execute( $timeMin, $timeMax );
        }
        while ( my @arr = $sth->fetchrow_array() ) {
            my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( $arr[0] );
            printf(
"%04d/%02d/%02d %02d:%02d:%02d - temp_sys=$arr[1] , temp_room=$arr[2], humid=$arr[3], pressure=$arr[4]<br/>\n",
                $year + 1900,
                $mon + 1, $mday, $hour, $min, $sec
            );
        }
        if ($sth) { $sth->finish(); }
        $dbh->disconnect();
    };
    if ($@) {

        # evalによるエラートラップ：エラー時の処理
        $dbh->disconnect();
        return 0;
    }
    
    # ファイルサイズの表示
    my $size = -s $filenameSql;
    $size /= 1024;      # kBytes単位に変換
    print "<br/>sqlite database file size = $size kBytes\n" 
}

1;
