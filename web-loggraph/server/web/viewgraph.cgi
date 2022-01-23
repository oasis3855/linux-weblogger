#!/usr/bin/perl
# viewgraph.cgi  -  温度データのグラフを表示するwebインターフェース
#
# このスクリプトをサーバ側に置き、webブラウザ経由で画面表示させる
#
# 2018/Apr/15  ver 1.0
# 2018/Apr/25  ver 1.1  - 湿度グラフ追加
# 2018/May/11  ver 1.2  - 気圧グラフ追加

use strict;
use warnings;
use utf8;
use CGI;
use File::Basename 'basename';

binmode( STDIN, ":utf8" ); # コンソール入力があるコマンドライン版の時
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );
require '../bin/draw_tempgraph.pl';

my $filenameGraph_1 = 'temperature_graph.png';
my $filenameGraph_2 = 'temperature_humid.png';
my $filenameGraph_3 = 'temperature_pressure.png';
my $str_this_script = basename($0); # このスクリプト自身のファイル名

main();

exit;

sub main {
    my $q = new CGI;

    # HTML出力開始（ヘッダ）
    sub_print_start_html( \$q );

  # 期間指定（開始時刻）のフォーム入力からのPOST受信処理
    my ( $secMin, $minMin, $hourMin, $mdayMin, $monMin, $yearMin ) =
      localtime( time() );
    if ( defined( $q->param('start_year') ) ) {
        $yearMin = $q->param('start_year') - 1900;
    }
    if ( defined( $q->param('start_month') ) ) {
        $monMin = $q->param('start_month') - 1;
    }
    if ( defined( $q->param('start_day') ) ) {
        $mdayMin = $q->param('start_day') + 0;
    }
    if (    $yearMin < 70
         || $yearMin > 132
         || $monMin < 0
         || $monMin > 11
         || $mdayMin < 1
         || $mdayMin > 31 )
    {
      # 年・月・日の受信値異常の場合は、現在時刻に上書き
        ( $secMin, $minMin, $hourMin, $mdayMin, $monMin, $yearMin ) =
          localtime( time() );
    }
    my $timeMin = timelocal( 0, 0, 0, $mdayMin, $monMin, $yearMin );

  # 期間指定（終了時刻）のフォーム入力からのPOST受信処理
    my ( $secMax, $minMax, $hourMax, $mdayMax, $monMax, $yearMax ) =
      localtime( time() + 24 * 60 * 60 );
    if ( defined( $q->param('end_year') ) ) {
        $yearMax = $q->param('end_year') - 1900;
    }
    if ( defined( $q->param('end_month') ) ) {
        $monMax = $q->param('end_month') - 1;
    }
    if ( defined( $q->param('end_day') ) ) {
        $mdayMax = $q->param('end_day') + 0;
    }
    if (    $yearMax < 70
         || $yearMax > 132
         || $monMax < 0
         || $monMax > 11
         || $mdayMax < 1
         || $mdayMax > 31 )
    {
# 年・月・日の受信値異常の場合は、現在時刻プラス1日に上書き
        ( $secMax, $minMax, $hourMax, $mdayMax, $monMax, $yearMax ) =
          localtime( time() ) + 24 * 60 * 60;
    }
    my $timeMax = timelocal( 0, 0, 0, $mdayMax, $monMax, $yearMax );

    # 開始・終了時刻の前後関係のチェックと修正
    if ( $timeMin >= $timeMax ) { $timeMin = $timeMax - 7 * 24 * 60 * 60; }

    # 最終確定した開始・終了時刻を画面表示用変数に代入
    ( $secMin, $minMin, $hourMin, $mdayMin, $monMin, $yearMin ) =
      localtime($timeMin);
    ( $secMax, $minMax, $hourMax, $mdayMax, $monMax, $yearMax ) =
      localtime($timeMax);

    # 指定された期間でグラフ作成
    my $count = drawTempgraph( $timeMin, $timeMax, 0, 50 );
    print "<h2>温度ログ</h2>\n";

    # 期間指定のフォーム入力エリア
    print '<form method="post" action="'
      . $str_this_script . '">'
      . '<p>期間指定 ： <input type="text" name="start_year" size="5" value="'
      . ( $yearMin + 1900 )
      . '" />年<input type="text" name="start_month" size="5" value="'
      . ( $monMin + 1 )
      . '" />月<input type="text" name="start_day" size="5" value="'
      . ($mdayMin)
      . '" />日 ' . "\n";
    print ' 〜 <input type="text" name="end_year" size="5" value="'
      . ( $yearMax + 1900 )
      . '" />年<input type="text" name="end_month" size="5" value="'
      . ( $monMax + 1 )
      . '" />月<input type="text" name="end_day" size="5" value="'
      . ($mdayMax)
      . '" />日 </p>' . "\n"
      . '<p><input type="submit" value="クエリ開始" name="B1" /><input type="reset" value="表示項目のリセット" name="B2" /><input type="hidden" name="query_command" value="start" /></p></form>'
      . "\n";

    # グラフ（PNG画像）
    print
    "<p><img src='../$filenameGraph_1' width='500' height='250' alt='tempereture' /></p>\n"
    ."<p><img src='../$filenameGraph_2' width='500' height='250' alt='humidity' /></p>\n"
    ."<p><img src='../$filenameGraph_3' width='500' height='250' alt='pressure' /></p>\n";
    # 抽出期間のテキスト表示
    print "<p>ログ抽出期間  $timeMin("
      . ( $yearMin + 1900 ) . "/"
      . ( $monMin + 1 )
      . "/$mdayMin) 〜 $timeMax("
      . ( $yearMax + 1900 ) . "/"
      . ( $monMax + 1 )
      . "/$mdayMax) , データ数 $count</p>\n";
    # 最終追加のデータの表示
    print "<p>指定期間内での最終追加データ<br/>\n";
    printLastAddedData( $timeMin, $timeMax, 0, 50 );
    print "</p>\n";

    # HTML出力終了
    sub_print_close_html( \$q );
}

# htmlを開始する
sub sub_print_start_html {
    my $q_ref = shift;    # CGIオブジェクト
    print( $$q_ref->header( -type => 'text/html', -charset => 'utf-8' ) );
    print( $$q_ref->start_html(
                   -title => "Temperature Log Viewer",
                   -dtd   => [
                       '-//W3C//DTD XHTML 1.0 Transitional//EN',
                       'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'
                   ],
                   -lang  => 'ja-JP',
                   -style => { 'src' => 'style.css' } ) );
}

# htmlを閉じる
sub sub_print_close_html {
    print("</body>\n</html>\n");
}
