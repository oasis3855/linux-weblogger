#!/usr/bin/perl
# draw_tempgraph.pl  -  温度データのグラフを描画しPNGファイルに保存する。また、最終追加データをテキスト出力する
#
# このスクリプトをサーバ側に置き、webブラウザ経由で画面表示させる
#
# 2018/Apr/15  ver 1.0

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

# DSNファイル名は相対パス（一旦ホームディレクトリに戻って、binを参照）
my $strSqlDsn     = 'DBI:SQLite:dbname=../bin/data.sqlite3';    # DSN
my $filenameSql = '../bin/data.sqlite3';
my $filenameGraph = '../temperature_graph.png';

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

    my $image = new GD::Image( $WIDTH + $MARGIN * 2, $HEIGHT + $MARGIN * 2 );

    # カラー インデックス
    my $colorWhite = $image->colorAllocate( 255, 255, 255 );
    my $colorBlack = $image->colorAllocate( 0,   0,   0 );
    my $colorGray  = $image->colorAllocate( 150, 150, 150 );
    my $colorRed   = $image->colorAllocate( 200, 0,   0 );
    my $colorGreen = $image->colorAllocate( 0,   200, 0 );

    # 背景色を透明にし、非インターレース化
    $image->transparent($colorWhite);

    # 座標軸を描画
    imageDrawGrid( \$image );

#    $timeMin = timelocal( 0, 0, 0, 15, 4 - 1, 2016 - 1900 );  # 2018/1/1 0:00:00
#    $timeMax = timelocal( 0, 0, 0, 15, 4 - 1, 2018 - 1900 );  # 2018/1/2 0:00:00

    my $time1;
    my $temp1;
    my $time2;
    my $temp2;

    # データベースより温度データの取り出し
    my @dummy;
    databaseGetData( $timeMin, $timeMax, \@dummy );

    foreach my $arr (@dummy) {

        $time1 = $arr->[0];
        $temp1 = $arr->[2];
        if ( $temp1 > 0 ) {
            convParam( \$temp1, \$time1 );

            #            $image->setPixel($time1,$temp1,$colorGreen);
            $image->arc( $time1, $temp1, 2, 2, 0, 360, $colorGreen );
        }
        $time1 = $arr->[0];
        $temp1 = $arr->[1];
        if ( $temp1 > 0 ) {
            convParam( \$temp1, \$time1 );

            #            $image->setPixel( $time1, $temp1, $colorRed );
            $image->arc( $time1, $temp1, 2, 2, 0, 360, $colorRed );
        }
    }

    # GDイメージを画像ファイルに書き込み
    # （画像ファイルに「読み書き許可」があること。Web CGIから用いる場合は特に注意）
    eval {
        open( FILE, "> $filenameGraph" ) or die($!);
        binmode FILE;
        print FILE $image->png;
        close(FILE);
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
    my $refTemp = shift;
    my $refTime = shift;

    $$refTime =
      $WIDTH * ( $$refTime - $timeMin ) / ( $timeMax - $timeMin ) + $MARGIN;
    $$refTemp =
      $HEIGHT -
      $HEIGHT * ( $$refTemp - $tempMin ) / ( $tempMax - $tempMin ) +
      $MARGIN;
}

# GDイメージに座標軸を描画
sub imageDrawGrid {
    my $image = shift;

    # カラー インデックス
    my $colorWhite = $$image->colorAllocate( 255, 255, 255 );
    my $colorBlack = $$image->colorAllocate( 0,   0,   0 );
    my $colorGray  = $$image->colorAllocate( 150, 150, 150 );
    my $colorRed   = $$image->colorAllocate( 200, 0,   0 );
    my $colorGreen = $$image->colorAllocate( 0,   200, 0 );

    my $time1 = $timeMin;
    my $temp1 = $tempMin;
    my $time2 = $timeMin;
    my $temp2 = $tempMax;
    convParam( \$temp1, \$time1 );
    convParam( \$temp2, \$time2 );
    $$image->line( $time1, $temp1, $time2, $temp2, $colorBlack );

    $time1 = $timeMin;
    $temp1 = $tempMin;
    $time2 = $timeMax;
    $temp2 = $tempMin;
    convParam( \$temp1, \$time1 );
    convParam( \$temp2, \$time2 );
    $$image->line( $time1, $temp1, $time2, $temp2, $colorBlack );

    # 縦軸（温度）目盛線
    for ( my $i = ( int( $tempMin / 10 ) + 1 ) * 10 ; $i < $tempMax ; $i += 10 )
    {
        $time1 = $timeMin;
        $temp1 = $i;
        $time2 = $timeMax;
        $temp2 = $i;
        convParam( \$temp1, \$time1 );
        convParam( \$temp2, \$time2 );
        $$image->line( $time1, $temp1, $time2, $temp2, $colorGray );

        $$image->string( gdSmallFont, 0, $temp1, $i, $colorBlack );
    }

    # 横軸（時間）目盛線
    if ( $timeMax - $timeMin <= 3 * ( 24 + 1 ) * 60 * 60 ) {

        # 3日+1h以内の場合、2時間毎の目盛線
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($timeMin);
        my $hourStart =
          timelocal( 0, 0, ( int( $hour / 2 ) + 1 ) * 2, $mday, $mon, $year );
        for ( my $i = $hourStart ; $i < $timeMax ; $i += 2 * 60 * 60 ) {
            $time1 = $i;
            $temp1 = $tempMin;
            $time2 = $i;
            $temp2 = $tempMax;
            convParam( \$temp1, \$time1 );
            convParam( \$temp2, \$time2 );
            ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($i);
            $$image->line( $time1, $temp1, $time2, $temp2,
                           $hour == 0 ? $colorBlack : $colorGray );

            $$image->string( gdTinyFont, $time1, $HEIGHT + $MARGIN,
                             $hour, $colorBlack );
        }
    } elsif ( $timeMax - $timeMin <= 15 * 24 * 60 * 60 ) {

        # 15日以内の場合、1日毎の目盛線
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($timeMin);
        my $hourStart = timelocal( 0, 0, 0, $mday + 1, $mon, $year );
        for ( my $i = $hourStart ; $i < $timeMax ; $i += 24 * 60 * 60 ) {
            $time1 = $i;
            $temp1 = $tempMin;
            $time2 = $i;
            $temp2 = $tempMax;
            convParam( \$temp1, \$time1 );
            convParam( \$temp2, \$time2 );
            ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($i);
            $$image->line( $time1, $temp1, $time2, $temp2,
                           $mday % 5 == 0 ? $colorBlack : $colorGray );

            $$image->string( gdTinyFont, $time1, $HEIGHT + $MARGIN,
                             $mday, $colorBlack );
        }
    } elsif ( $timeMax - $timeMin <= 2 * 365 * 24 * 60 * 60 ) {

        # 2年以内の場合、1ヶ月毎の目盛線
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($timeMin);
        my $hourStart = timelocal( 0, 0, 0, 1, $mon + 1, $year );
        my @strMonth = (
                         'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                         'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
        );
        for ( my $i = $hourStart ; $i < $timeMax ; ) {
            $time1 = $i;
            $temp1 = $tempMin;
            $time2 = $i;
            $temp2 = $tempMax;
            convParam( \$temp1, \$time1 );
            convParam( \$temp2, \$time2 );
            ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($i);
            $$image->line( $time1, $temp1, $time2, $temp2,
                           $mday % 5 == 0 ? $colorBlack : $colorGray );

            $$image->string( gdTinyFont, $time1, $HEIGHT + $MARGIN,
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
"%04d/%02d/%02d %02d:%02d:%02d - temp_sys=$arr[1] , temp_room=$arr[2]<br/>\n",
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
