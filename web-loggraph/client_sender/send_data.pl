#!/usr/bin/perl

# send_data.cgi  -  温度・湿度・気圧データをWeb経由で送信する
#
# このスクリプトをクライアント側のRaspberryPiに置き、
#    サーバにデータを送信する。cronで5分ごとに自動起動設定する
# 2018/Apr/15  ver 1.0
# 2018/Apr/24  ver 1.1  -- 湿度データ送信を追加

use strict;
use warnings;

{
my $temp_room = 0;      # 室温
my $temp_sys = 0;       # RaspberryPi システム温度
my $humid = 0;          # 湿度

# webアクセス時の簡易パスワード
my $PWD = '1234ABCD';

# Raspberry Piの温度データ読み込み
getTemperature(\$temp_room, \$temp_sys);
# Raspberry Piの湿度データ読み込み
getHumidity(\$humid);

socketGetHtml("http://www.example.com/cgi-bin/add_data.cgi?pwd=$PWD", "", "temp_room=$temp_room&temp_sys=$temp_sys&humid=$humid", 5);
#socketGetHtml("http://localhost/log-graph/add_data.cgi?pwd=$PWD", "", "temp_room=$temp_room&temp_sys=$temp_sys", 5);

exit;
}

sub socketGetHtml {
    use Socket;
    
    my $strURI = shift;
    my $strReferer = shift;     # リファラー（例:"http://example.com/". 空文字列指定で送信しない）
    my $strSend = shift;        # url パラメーターとして送信する
    my $intTimeout = shift;     # タイムアウト 秒数
    
    my $socket;
    
    # ホストアドレスとファイル名を分離 ($dummy1=http:, $dummy2=, $host=www.example.com, file=dir/index.html)
    my ($dummy1, $dummy2, $host, $file) = split(/\//, $strURI, 4);
    if(substr($file, 0, 1) ne '/'){ $file = '/' . $file; }
    
    ##### DEBUG
#    print "host = $host\n";
#    print "file = $file\n";
#    print "===========\n";
    ##### DEBUG
    
    eval{
        # タイムアウト処理の設定
        local $SIG{ALRM} = sub{die "time out $!"};
        alarm($intTimeout);
        
        $socket = pack_sockaddr_in(80, inet_aton($host));
        socket(SOCKET, PF_INET, SOCK_STREAM, 0) || die("error: socket create");
        connect(SOCKET, $socket) || die("error: socket connect");
        
        SOCKET->autoflush;
#        select(SOCKET); $| = 1; select(STDOUT);

        my $str;
        if($strSend ne ''){ $str = "POST $file HTTP/1.1\r\n"; }     # POSTデータを送信する場合
        else{ $str = "GET $file HTTP/1.1\r\n"; }                    # POSTデータを送信しない場合
        $str .= "HOST: $host\r\n";
        if($strReferer ne ''){ $str .= "Referer: $strReferer\r\n"; }

        if($strSend ne ''){     # POSTデータを送信する場合
            my $intDataLength = length($strSend);
            $str .= "Content-Length: $intDataLength\r\n".
                "Connection: Keep-Alive\r\n".
                "\r\n".
                $strSend."\r\n".
                "\r\n";
        }
        else{                   # POSTデータを送信しない場合
            $str .= "Connection: close\r\n\r\n";
        }

        print SOCKET $str;
        
        ##### DEBUG
        # サーバ側からの返送文字列を画面表示
#        while (chomp(my $buf = <SOCKET>)) {
#            print "$buf\n";
#            $buf =~ /EXIT:/ && last;
#        }
        ##### DEBUG

        # タイムアウト処理の設定
        alarm(0);
    };
    if ($@) {
#      print "ERROR: $@";
      exit 1;
    }

    alarm(0);
}

# I2C接続外部温度センサー、Rpi内部温度センサーから温度を読み出す
sub getTemperature {
    my $refTemp_room = shift;
    my $refTemp_sys = shift;

    use Device::I2C;
    use Fcntl;


    # 外部I2C接続LM75センサーの読み込み
    my $i2cDev = Device::I2C->new('/dev/i2c-1', O_RDWR);
    $i2cDev->selectDevice(0x48);
    my $data = $i2cDev->readWordData(0);
    #取り出されたデータは、LM75 Temperature Registerの割り付けで
    # $data = D2 D1 D0 X   X X X X   D10 D9 D8 D7   D6 D5 D4 D3
    #となっている
    # これを、 D10 D9 D8   D7 D6 D5 D4   D3 D2 D1 D0  の並びに変えるため
    # ビットシフトの演算を行う。
    # 得られた値は、0.125℃単位である。
    my $temp = ( ( $data & 0xff) << 3 ) | ( ( $data & 0xf000 ) >> 13 );
    # 負数の場合の処理
    if($temp & 0x0400){
        $temp = (~$temp & 0x03ff);    # 1の補数
        $temp += 1;                   # 2の補数
        $temp *= -1;
    }
    $$refTemp_room = int($temp * 0.125);


    # Raspberry piボード上のbcm2835温度センサーの読み込み
    eval {
        open(FILE, '< /sys/class/thermal/thermal_zone0/temp') or die;
        my $line = <FILE>;
        close(FILE);
        $$refTemp_sys = int($line/1000);
    };
    if ($@) {
        exit;
    }

    return;
}

# DHT11から湿度を読み出す
sub getHumidity {
    my $refHumid = shift;

    use RPi::DHT11;

    my $dht11 = RPi::DHT11->new(27);
    $$refHumid = $dht11->humidity;

    return;
}

