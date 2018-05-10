#!/usr/bin/perl

# send_data.cgi  -  温度・湿度・気圧データをWeb経由で送信する
#
# このスクリプトをクライアント側のRaspberryPiに置き、
#    サーバにデータを送信する。cronで5分ごとに自動起動設定する
# 2018/Apr/15  ver 1.0
# 2018/Apr/24  ver 1.1  -- 湿度データ送信を追加
# 2018/May/10  ver 1.2  -- BMP280 温度・気圧を追加

use strict;
use warnings;
use IO::File;
use Fcntl;
use Time::HiRes 'usleep';

# https://mirrors.edge.kernel.org/pub/linux/kernel/people/marcelo/linux-2.4/include/linux/i2c.h
use constant I2C_SLAVE       => 0x0703;
use constant I2C_SLAVE_FORCE => 0x0706;
use constant I2C_RDWR        => 0x0707;

use constant BMP280_I2C_ADDRESS => 0x76;

use constant BMP280_TEMP_OSS     => 0x01;  # osrs_t = 0b001  -> oversampling x 1
use constant BMP280_PRES_OSS     => 0x01;  # osrs_p = 0b001  -> oversampling x 1
use constant BMP280_POWER_NORMAL => 0x03;  # power on (normalmode)
use constant BMP280_POWER_SLEEP  => 0x00;  # sleep

use constant LM75_I2C_ADDRESS => 0x48;

{
    my $temp_room = 0;    # 室温
    my $temp_sys  = 0;    # RaspberryPi システム温度
    my $humid     = 0;    # 湿度
    my $pressure  = 0;    # 気圧

    # webアクセス時の簡易パスワード
    my $PWD = '1234ABCD';

    # Raspberry Piの温度データ読み込み
    getTemperature( \$temp_room, \$temp_sys, \$pressure );

    # Raspberry Piの湿度データ読み込み
    getHumidity( \$humid );

    socketGetHtml( "http://www.example.com/cgi-bin/add_data.cgi?pwd=$PWD", "",
                   "temp_room=$temp_room&temp_sys=$temp_sys&humid=$humid&pressure=$pressure", 5 );

    #socketGetHtml("http://localhost/log-graph/add_data.cgi?pwd=$PWD", "", "temp_room=$temp_room&temp_sys=$temp_sys", 5);

    exit;
}

sub socketGetHtml {
    use Socket;

    my $strURI = shift;
    my $strReferer = shift; # リファラー（例:"http://example.com/". 空文字列指定で送信しない）
    my $strSend    = shift; # url パラメーターとして送信する
    my $intTimeout = shift; # タイムアウト 秒数

    my $socket;

# ホストアドレスとファイル名を分離 ($dummy1=http:, $dummy2=, $host=www.example.com, file=dir/index.html)
    my ( $dummy1, $dummy2, $host, $file ) = split( /\//, $strURI, 4 );
    if ( substr( $file, 0, 1 ) ne '/' ) { $file = '/' . $file; }

    ##### DEBUG
#    print "host = $host\n";
#    print "file = $file\n";
#    print "===========\n";
    ##### DEBUG

    eval {
        # タイムアウト処理の設定
        local $SIG{ALRM} = sub { die "time out $!" };
        alarm($intTimeout);

        $socket = pack_sockaddr_in( 80, inet_aton($host) );
        socket( SOCKET, PF_INET, SOCK_STREAM, 0 )
          || die("error: socket create");
        connect( SOCKET, $socket ) || die("error: socket connect");

        SOCKET->autoflush;

#        select(SOCKET); $| = 1; select(STDOUT);

        my $str;
        if ( $strSend ne '' ) { $str = "POST $file HTTP/1.1\r\n"; } # POSTデータを送信する場合
        else { $str = "GET $file HTTP/1.1\r\n"; } # POSTデータを送信しない場合
        $str .= "HOST: $host\r\n";
        if ( $strReferer ne '' ) { $str .= "Referer: $strReferer\r\n"; }

        if ( $strSend ne '' ) {    # POSTデータを送信する場合
            my $intDataLength = length($strSend);
            $str .=
                "Content-Length: $intDataLength\r\n"
              . "Connection: Keep-Alive\r\n" . "\r\n"
              . $strSend . "\r\n" . "\r\n";
        } else {                   # POSTデータを送信しない場合
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
    my $refTemp_sys  = shift;
    my $refPressure = shift;

    # GPIO 4 を BMP280のVCCとして利用する
    system "/usr/local/bin/gpio -g mode 4 out";
    system "/usr/local/bin/gpio -g write 4 1";
    my ( $t, $p ) = bmp280_getvalue();
    printf( "BMP280\ntemperature = %.2f deg-C, pressure = %.2f hPa\n", $t, $p );
    system "/usr/local/bin/gpio -g write 4 0";

    $$refTemp_room = int( $t );
    $$refPressure = int( $p );

    # Raspberry piボード上のbcm2835温度センサーの読み込み
    eval {
        open( FILE, '< /sys/class/thermal/thermal_zone0/temp' ) or die;
        my $line = <FILE>;
        close(FILE);
        $$refTemp_sys = int( $line / 1000 );
    };
    if ($@) {
        exit;
    }

    return;
}

sub LM75_getvalue {
    use Device::I2C;
    use Fcntl;

    # 外部I2C接続LM75センサーの読み込み
    my $i2cDev = Device::I2C->new( '/dev/i2c-1', O_RDWR );
    $i2cDev->selectDevice(LM75_I2C_ADDRESS);
    my $data = $i2cDev->readWordData(0);

    #取り出されたデータは、LM75 Temperature Registerの割り付けで
    # $data = D2 D1 D0 X   X X X X   D10 D9 D8 D7   D6 D5 D4 D3
    #となっている
    # これを、 D10 D9 D8   D7 D6 D5 D4   D3 D2 D1 D0  の並びに変えるため
    # ビットシフトの演算を行う。
    # 得られた値は、0.125℃単位である。
    my $temp = ( ( $data & 0xff ) << 3 ) | ( ( $data & 0xf000 ) >> 13 );

    # 負数の場合の処理
    if ( $temp & 0x0400 ) {
        $temp = ( ~$temp & 0x03ff );    # 1の補数
        $temp += 1;                     # 2の補数
        $temp *= -1;
    }

    return $temp * 0.125;

}

# DHT11から湿度を読み出す
sub getHumidity {
    my $refHumid = shift;

    use RPi::DHT11;

    my $dht11 = RPi::DHT11->new(27);
    $$refHumid = $dht11->humidity;

    return;
}

# 温度・気圧を配列で返すsub
sub bmp280_getvalue {
    my ( $t, $p ) = ( 0, 0 );

    eval {
        my $fh = IO::File->new( "/dev/i2c-1", O_RDWR );
        $fh->ioctl( I2C_SLAVE_FORCE, BMP280_I2C_ADDRESS );
        $fh->binmode();

        #
        # read Trimming parameter
        #
        my $dig_t1 = i2c_read_unsigned_int( $fh, 0x88 );
        my $dig_t2 = i2c_read_int( $fh, 0x8a );
        my $dig_t3 = i2c_read_int( $fh, 0x8c );
        my $dig_p1 = i2c_read_unsigned_int( $fh, 0x8e );
        my $dig_p2 = i2c_read_int( $fh, 0x90 );
        my $dig_p3 = i2c_read_int( $fh, 0x92 );
        my $dig_p4 = i2c_read_int( $fh, 0x94 );
        my $dig_p5 = i2c_read_int( $fh, 0x96 );
        my $dig_p6 = i2c_read_int( $fh, 0x98 );
        my $dig_p7 = i2c_read_int( $fh, 0x9a );
        my $dig_p8 = i2c_read_int( $fh, 0x9c );
        my $dig_p9 = i2c_read_int( $fh, 0x9e );

        #
        # Write 0xF4 "ctrl_meas" register sets
        # Controls oversampling of temperature and pressure data
        #
        my @array_bytes = (
               0xF4,
               BMP280_TEMP_OSS << 5 | BMP280_PRES_OSS << 3 | BMP280_POWER_NORMAL
        );
        i2c_write_bytes( $fh, \@array_bytes );

        #
        # Write 0xF5 "config" register sets
        # Set stand by time = 1000ms (t_sb=0b101)
        #
        @array_bytes = ( 0xF5, 0xA0 );
        i2c_write_bytes( $fh, \@array_bytes );
        usleep( 1000 * 1000 );

        #
        # Read raw temperature and pressure measurement output
        #
        my $data_bytes = i2c_read_bytes( $fh, 0xf7, 6 );

        my $adc_p =
          unpack( "C", substr( $data_bytes, 0, 1 ) ) << 12 |
          unpack( "C", substr( $data_bytes, 1, 1 ) ) << 4 |
          unpack( "C", substr( $data_bytes, 2, 1 ) ) >> 4;
        my $adc_t =
          unpack( "C", substr( $data_bytes, 3, 1 ) ) << 12 |
          unpack( "C", substr( $data_bytes, 4, 1 ) ) << 4 |
          unpack( "C", substr( $data_bytes, 5, 1 ) ) >> 4;

        #
        # Calc temperature
        #
        my $var1 = ( $adc_t / 16384.0 - $dig_t1 / 1024.0 ) * $dig_t2;
        my $var2 =
          ( ( $adc_t / 131072.0 - $dig_t1 / 8192.0 ) *
            ( $adc_t / 131072.0 - $dig_t1 / 8192.0 ) ) *
          $dig_t3;
        my $t_fine = $var1 + $var2;
        $t = ( $var1 + $var2 ) / 5120.0;
        #
        # Calc pressure
        #
        $var1 = ( $t_fine / 2.0 ) - 64000.0;
        $var2 = $var1 * $var1 * $dig_p6 / 32768.0;
        $var2 = $var2 + $var1 * $dig_p5 * 2.0;
        $var2 = ( $var2 / 4.0 ) + ( $dig_p4 * 65536.0 );
        $var1 =
          ( $dig_p3 * $var1 * $var1 / 524288.0 + $dig_p2 * $var1 ) / 524288.0;
        $var1 = ( 1.0 + $var1 / 32768.0 ) * $dig_p1;
        $p    = 1048576.0 - $adc_p;
        $p    = ( $p - ( $var2 / 4096.0 ) ) * 6250.0 / $var1;
        $var1 = $dig_p9 * $p * $p / 2147483648.0;
        $var2 = $p * $dig_p8 / 32768.0;
        $p    = ( $p + ( $var1 + $var2 + $dig_p7 ) / 16.0 ) / 100;

        #
        # Write 0xF4 "ctrl_meas" register sets
        # Controls oversampling of temperature and pressure data
        #
        @array_bytes = (
                0xF4,
                BMP280_TEMP_OSS << 5 | BMP280_PRES_OSS << 3 | BMP280_POWER_SLEEP
        );
        i2c_write_bytes( $fh, \@array_bytes );

        close($fh);

    };
    if ($@) {
        die $@;
    }

    return ( $t, $p );

}

sub i2c_read_int {
    my ( $i2c, $bmp085_reg ) = @_;

    # アドレス 2Bytes をバイナリ形式の変数に格納
    my $buffer = pack( "C*", $bmp085_reg );

    # アドレス 2Bytes 送信
    #（bufferdのprintではなく、unbufferdのsyswrite利用）
    $i2c->syswrite($buffer);

    # データ 1Byte 受信
    #（bufferdのreadではなく、unbufferdのsysread利用）
    $i2c->sysread( $buffer, 2 );

    my $val0 = unpack( "v", $buffer ); # リトルエンディアンのshort unsigned intとして解釈
    my $val = unpack( "s", pack( "S", $val0 ) ); # unsigned から signed に変換

    return $val;
}

sub i2c_read_unsigned_int {
    my ( $i2c, $bmp085_reg ) = @_;

    # アドレス 2Bytes をバイナリ形式の変数に格納
    my $buffer = pack( "C*", $bmp085_reg );

    # アドレス 2Bytes 送信
    $i2c->syswrite($buffer);

    # データ 1Byte 受信
    $i2c->sysread( $buffer, 2 );

    my $val = unpack( "v", $buffer ); # リトルエンディアンのshort unsigned intとして解釈

    return $val;
}

sub i2c_write_bytes {
    my ( $i2c, $ref_array, $count ) = @_;

    # アドレス 2Bytes をバイナリ形式の変数に格納
    my $buffer = pack( "C*", @{$ref_array} );

    # アドレス 2Bytes 送信
    $i2c->syswrite($buffer);

    return;
}

sub i2c_read_bytes {
    my ( $i2c, $bmp085_reg, $count ) = @_;

    # アドレス 2Bytes をバイナリ形式の変数に格納
    my $buffer = pack( "C*", $bmp085_reg );

    # アドレス 2Bytes 送信
    $i2c->syswrite($buffer);

    # データ $count Byte 受信
    if ( $i2c->sysread( $buffer, $count ) != $count ) {
        print "(less data error) \n";
    }

    return $buffer;
}

