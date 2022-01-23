#!/usr/bin/perl

# コマンドラインからグラフ画像ファイルを強制作成するサンプルスクリプト

use strict;
use warnings;

require 'draw_tempgraph.pl';

my $timeMin = timelocal( 0, 0, 0, 1,  4 - 1, 2018 - 1900 );    # 2018/04/01
my $timeMax = timelocal( 0, 0, 0, 30, 4 - 1, 2018 - 1900 );    # 2018/04/30

drawTempgraph( $timeMin, $timeMax, 0, 50 );

exit;
