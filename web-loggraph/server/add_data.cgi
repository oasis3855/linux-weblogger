#!/usr/bin/perl

# add_data.cgi  -  温度・湿度・気圧データをWeb経由でsqlite3データベースに追加する
#
# このスクリプトをサーバ側に置き、クライアントからのデータを受信する
#
# 2018/Apr/15  ver 1.0

use strict;
use warnings;
use DBI;
use CGI;

# sqlite3データベースのファイルはbinサブディレクトリに格納（webからはアクセス制御する）
my $strSqlDsn = 'DBI:SQLite:dbname=./bin/data.sqlite3';    # DSN

# webアクセス時の簡易パスワード（POSTまたはGETのpwd変数で受け取り一致するかチェックされる）
my $PWD = '1234ABCD';

main();

exit;

sub main {
    my %hashData; # web経由でPOSTまたはGETにより受け取った変数を格納するハッシュ

    print "Content-Type: text/plain\n\n";

    ##### DEBUG
#    $hashData{'pwd'}       = $PWD;
#    $hashData{'temp_room'} = 35;
    ##### DEBUG

    # POSTまたはGETで受け取った変数をハッシュに格納
    receive_data( \%hashData );

    # pwd変数が指定されたパスワードと一致するか検査
    if ( !check_password( \%hashData ) ) {
        print "EXIT:ERROR_1\n";
        return;
    }

    ##### DEBUG #####
#    print "Content-Type: text/plain\n\n";
#    foreach my $key(keys(%hashData)){
#        print "$key = $hashData{$key}\n";
#    }
    ##### DEBUG #####

    # sqlite3データベースに指定時間内のデータが重複登録されていないかチェック
    if ( !check_database() ) {
        print "EXIT:ERROR_2\n";
        return;
    }

    # sqlite3データベースに温度・湿度・気圧データを追加
    if ( !save_data( \%hashData ) ) {
        print "EXIT:ERROR_3\n";
        return;
    }

    print "EXIT:OK\n";
    return;
}

# webアクセスでPOSTまたはGETにより受診したデータをハッシュに格納
sub receive_data {
    my $refHashData = shift;

    my $q = new CGI;

    # GETでデータ送受信（URLパラメーター）の場合
    foreach my $param ( $q->url_param() ) {
        $$refHashData{$param} = $q->url_param($param);
    }

    # POSTでデータ送受信の場合
    foreach my $param ( $q->param() ) {
        $$refHashData{$param} = $q->param($param);
    }
}

# パスワードが一致するかチェック
sub check_password {
    my $refHashData = shift;

    if ( !defined( $$refHashData{'pwd'} ) ) { return 0; }
    if ( $$refHashData{'pwd'} ne $PWD )     { return 0; }
    return 1;
}

# sqlite3データベースに指定時間内のデータが重複登録されていないかチェック
sub check_database {
    my $datatime = time();
    $datatime = $datatime - ( $datatime % 300 );    # 5分毎にまるめる
    my $dbh = undef;
    my $sth = undef;
    my $count;

    eval {
        # データベースに接続
        $dbh = DBI->connect( $strSqlDsn, "", "",
                             { PrintError => 0, AutoCommit => 0 } );
        if ( !$dbh ) { return 0; }

        # SQL文を構築する
        my $strQuery = "select count(*) from graphdata where datatime >= ?";
        $sth = $dbh->prepare($strQuery);

        # SQLを発行する
        if ($sth) { $sth->execute( $datatime - 10 ); } # 規定間隔より10秒余裕をみる
        $count = $sth->fetchrow_array();
        if ($sth) { $sth->finish(); }
        $dbh->commit;
        $dbh->disconnect();
    };
    if ($@) {

        # evalによるエラートラップ：エラー時の処理
        $dbh->rollback;
        $dbh->disconnect();
        return 0;
    }
    if ( $count > 0 ) { return 0; }
    return 1;
}

# sqlite3データベースに温度・湿度・気圧データを追加
sub save_data {
    my $refHashData = shift;

    my $datatime = time();
    $datatime = $datatime - ( $datatime % 300 );    # 5分毎にまるめる
    my %hashParam;

    # GET/POSTデータ受信から「データ項目」を抜き出す
    if ( defined( $$refHashData{'temp_sys'} ) ) {
        $hashParam{'temp_sys'} = $$refHashData{'temp_sys'} + 0;
    }
    if ( defined( $$refHashData{'temp_room'} ) ) {
        $hashParam{'temp_room'} = $$refHashData{'temp_room'} + 0;
    }
    if ( defined( $$refHashData{'humid'} ) ) {
        $hashParam{'humid'} = $$refHashData{'humid'} + 0;
    }
    if ( defined( $$refHashData{'pressure'} ) ) {
        $hashParam{'pressure'} = $$refHashData{'pressure'} + 0;
    }

    # データ項目が1つも送信されてこない時はエラー
    if ( keys(%hashParam) == 0 ) { return 0; }

    # 欠落データ項目は "0" を代入
    if ( !defined( $hashParam{'temp_sys'} ) )  { $hashParam{'temp_sys'}  = 0; }
    if ( !defined( $hashParam{'temp_room'} ) ) { $hashParam{'temp_room'} = 0; }
    if ( !defined( $hashParam{'humid'} ) )     { $hashParam{'humid'}     = 0; }
    if ( !defined( $hashParam{'pressure'} ) )  { $hashParam{'pressure'}  = 0; }

    my $dbh = undef;
    my $sth = undef;

    eval {
        # データベースに接続
        $dbh = DBI->connect( $strSqlDsn, "", "",
                             { PrintError => 0, AutoCommit => 0 } );
        if ( !$dbh ) { return 0; }

        # SQL文を構築する
        my $strQuery =
"insert into graphdata('datatime', 'temp_sys', 'temp_room', 'humid', 'pressure') "
          . "values(?, ?, ?, ?, ?)";
        $sth = $dbh->prepare($strQuery);

        # SQLを発行する
        if ($sth) {
            $sth->execute(
                           $datatime,               $hashParam{'temp_sys'},
                           $hashParam{'temp_room'}, $hashParam{'humid'},
                           $hashParam{'pressure'} );
        }
        if ($sth) { $sth->finish(); }
        $dbh->commit;
        $dbh->disconnect();
        ##### DEBUG #####
        print "DB($strSqlDsn) write done\n";
    };
    if ($@) {

        # evalによるエラートラップ：エラー時の処理
        $dbh->rollback;
        $dbh->disconnect();
        return 0;
    }
    return 1;
}
