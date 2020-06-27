
PC-8001 on DE10-Lite
PC-8001 on DE0-CV

簡易ドキュメント 
RJB (@RadioJunkBox)

■履歴
・2020/6/14 初版
・2020/6/27 Version 1.11　PCG8200モード、PCGフルドットカラー機能追加


■概要
このプロジェクトは、2004年にkwhr0さんが「FPGAでPC-8001を作る計画」で公開されたプロジェクトをリスペクトして、Intel FPGAを搭載したDE10-Lite、DE0-CVで動作するように改修したものです。PC-8001については、実機やPC-8001miniも所有しており、またj80などの素晴らしいエミュレータもありますが、15年前のプロジェクトを拝見し、いつかはFPGAで動かしてみたいというだけの実験的な理由からです。
基本的に、kwhr0さんのコードをそのまま使用させていただいており、VGAやPCG、PS/2キーボード対応などの機能追加をしています。オリジナルではUKPによるUSBキーボードが使えましたが、力不足で改修できず一部機能ダウンしているところもあります。なお、Z80のコアは、kwhr0さんの書かれたfz80コアをオリジナルのまま使っています。
「FPGAでPC-8001を作る計画」を公開してくださったkwhr0さん、およびSD-DOSを公開されたちくらっぺさん(@chiqlappe)に深く感謝いたします。


■必要なもの
　○必須
　・Terasic DE10-LiteまたはDE0-CV
　・Quartus Prime Version 18.1.0 Lite Edition（以外では確認していません）
　・PS/2キーボード（DE10-Liteの場合にはPS/2インターフェース回路も必要）
　・PC-8001 ROMデータ (BASIC BIOS、FONT)

　○必要に応じて
　・SD-DOS（ちくらっぺさん）、microSDカード（容量2GB以下まで）
　・サウンド、BEEP回路用インターフェースなど

　○DE10-Liteのみ
　・SDカードインターフェース


■使い方（インストール方法）
　1.DE10-LiteまたはDE0-CVの各プロジェクト一式を固めたpc8001m.zipを任意の作業フォルダに展開する。
　2.PC-8001実機から吸い出したBIOS ROMデータ及びFONT(CG)ROMデータをmif形式に変換し、それぞれbios.mif、font.mifというファイル名に変更する。
　3.pc8001m/ROMフォルダにあるbios.mif、font.mifを差し替える。（元のROMフォルダはサンプルのダミーデータ）
　4.SD-DOSを使用する場合は、ROMフォルダにあるextrom.mifをSD-DOSバイナリからmif形式にしたデータに差し替える。（ファイル名はextrom.mifのまま）
　5.Quartus Primeを立ち上げ、ファイルメニューのOpen Projectからpc8001mフォルダのpc8001m.qpfを選択し、プロジェクトを開く。
　6.StartCompilationでコンパイルする。コンパイルには数分かかり、エラーが出ずコンパイルが終了すればOK。（ワーニングが大量に出るが基本的に影響なし。気になる方は適宜直してください）
　7.コンパイル終了後、DE10-LiteまたはDE0-CVを接続しプログラムを書き込む。（適宜、sofまたはpofを選択してください）
　8.書き込み完了後、PC-8001の起動メッセージが出れば完了です。（当然、VGAモニタやPS/2キーボードなどが予め接続されていること）
　　なお、mif形式への変換、Quartus Primeの詳しい使い方などは、他のサイトや市販の書籍などを参考にしてください。


■機能など
　○メモリ
　・ROM BASIC BIOS 24kB、拡張ROM 8kB(SD-DOSなど)
　・RAM 64kB（下位32kBは拡張RAM扱い）
　・8012相当のメモリ切り替えが可(バンク0のみ)
　　E2h	bit7-5	未使用
	bit4	拡張RAM書き込み 0:不可 1:可（0-7FFFh）
	bit3-1	未使用
	bit0	拡張RAM読み出し 0:ROM 1:RAM（E8hでアドレス毎に設定可）
　　E7h	bit7	6000-7FFFh 0:ROM　1:RAMリード切り替え（オリジナル機能）
        bit6	4000-5FFFh 0:ROM　1:RAMリード切り替え
        bit5	2000-3FFFh 0:ROM　1:RAMリード切り替え
        bit4	0000-1FFFh 0:ROM　1:RAMリード切り替え
	bit3-0	未使用
　　※SD-DOSを使用する場合は、拡張ROMデータを拡張RAM(6000-7FFFh)にコピーし、OUT &HE7,&H80、OUT &HE2,&H11の後、＊G0000でリスタート。

　○PS/2キーボード配列
　・例
　　GPAPH: Alt
　　STOP : End
　　DEL  : Backsapce
　 ※詳しくは、ps2key.vのps2keymapを参照してください（お好みで変更してください）

　○VGA出力
　・オリジナルはカラーコンポジット信号でしたが、HDMIへの変換など利便性を考えてVGA出力に対応しました。
　・14.318MHzで駆動するCTRCコードをそのまま使い、2倍の28.636MHzのクロックと2ラインバッファで強引にVGAに変換していますので、規格に合ってないところがあります。
　・カラーコンポジット信号を使う場合には、crtc.vからのy_out、c_outを出力させ、別途DAC回路で変換し生成ください

　○SD-D0S
　・ファイルの入出力は、ちくらっぺさんが公開されているSD-DOS(https://github.com/chiqlappe)がこの上なく便利ですので利用を強く推奨します。
　・SD-DOSのバイナリは提供されていませんので、wavやcmt形式のファイルから変換してください。
　・拡張ROMにSD-DOSのバイナリを6010hから配置し、7F00h辺りに以下のような転送プログラムを仕込んで置くと便利です。
　　転送プログラムの例
　　　0000h(6000h): 41 42 CD 00 7F ・・・・
　　　0010h(6010h): SD-DOSバイナリ
　　　　　　　　　　　　・・・
　　　1F00h(7F00h): 21 10 60 01 F0 1F 11 00 60 ED B0 3E 80 D3 E7 3E
　　　1F10h(7F10h): 11 D3 E2 00 00 00 00 00 00 00 00 00 00 00 00 00
　　　1F20h(7F20h): 00 00 00 00 00 00 00 00 00 00 00 C9 00 00 ・・・　← C9 00 00はここに置く

　○PCG
　・PCG8100またはPCG8200相当の機能を実装しています（SWでモード切り替え）
　・CGROM→RAMへの転送機能は実装してません。
　・サウンドは、なんちゃって8253による3音再生が可能です。
　・ROMフォルダのpcgrom.mifはランダムパターンを再現するデータです。
　・PCGフルドットカラー（I/O誌1983年12月号）機能を実装しました
　　I/Oアドレスはオリジナルの記事と異なり、ちくらっぺさん(@chiqlappe)のtweet回路を参考にしています
　　90-97h　カラーパレット　　ex. OUT &H91,2 → パレット1（青）を赤色に登録
　　98-9Fh　RAM選択 bit1:赤 bit0:緑　ex. OUT &H98,2 → 書込みRAM:赤（青は常時選択）
　※PCG8200モードおよびフルドットカラー機能は動作が十分確認できてません

　○CMT（カセットテープI/F）/SIO
　・不安定であり、現時点はおまけ程度の機能です。（読み込めるが中身がエラーになっている場合がある）
　・CMT出力(FSK)信号は、SW2でBEEP出力を切り替えができます。
　・CMT音声(FSK)信号の読み込みにはuPC271(LM311)などを使ったコンパレータ回路の製作が必要です。
　・SIOは、モード固定のなんちゃって8251です。

　○スライドSW     OFF             ON
　　・SW0	        カラーモニタ表示   グリーンモニタ表示
　　・SW1	        未使用
　　・SW2	        BEEP            CMT出力（motorと連動）
　　・SW3	        FDC OFF         FDC ON (FDC:PCGフルドットカラー)
　　・SW4	        PCG8100モード    PCG8200モード
　　・SW5	        PCG OFF         PCG ON
　　・SW6	        未使用
　　・SW7	        拡張ROMなし       拡張ROM（SD-DOS）あり
　　・SW8	        未使用		
　　・SW9	        通常モード	        高速モード(WAIT減)
　　　※SW9を動かすと動作が固まる場合があります

　○プッシュボタン
　　・KEY0               リセット（STOP+リセット可）
　　・KEY1               未使用
　　・KEY2(DE0-CV)       未使用
　　・KEY3(DE0-CV)       未使用

　○LED
　　・LED0-7             CPUデータバス（CPU入力データ）
　　・LED8               SDアクセス
　　・LED9               拡張RAM使用

　○7セグメントLED
　　・7SEG0-3            CPUアドレス
　　・7SEG4-5            未使用


■外部I/O接続
　※注意！！
　・FPGAボードのI/O電圧は、全て3.3Vです。5Vの回路を直接接続するとFPGAボードを壊す場合があります。
　・また、FPGAボードに直接スピーカーやリレーなど重い負荷を接続すると壊れる場合があります。

　＜DE0-CV＞
　○サウンド出力
　・audio_out[0]	出力	JP2-37		PIN_G13　PCGサウンド 0
　・audio_out[1]	出力	JP2-38		PIN_G12　PCGサウンド 1
　・audio_out[2]	出力	JP2-39		PIN_J17　PCGサウンド 2
　・audio_out[3]	出力	JP2-40		PIN_K16　BEEP/CMT出力
　・beep_out	出力	JP2-31		PIN_F14　1kΩ程度の抵抗を入れて圧電ブザーに接続

　○白黒コンポジットビデオ出力（カラーバーストなし）
　・bw_out[0]	出力	JP2-5		PIN_A13　SYNC
　・bw_out[1]	出力	JP2-6		PIN_B13　Y信号（2値）

　○CMT/SIO入出力
　・cmt_in	入力	JP2-7		PIN_C13　外部コンパレータ回路が必要）
　・motor_out	出力	JP2-8		PIN_D13　motor 1で3.3V出力
　・rxd		入力	JP2-9		PIN_G18　SIO入力
　・txd		出力	JP2-10		PIN_G17　SIO出力

　＜DE10-Lite＞

　○PS/2キーボード入力
　・ps2_clk	入力	Arduino_IO7	PIN_AA12 3.3Vに変換のこと
　・ps2_data	入力	Arduino_IO6	PIN_AA11 3.3Vに変換のこと

　○SDカードIF
　・sd_dat	入力	JP1-31		PIN_AA7　DATA_0
　・sd_clk	出力	JP1-32		PIN_Y6 　CLK
　・sd_cmd	出力	JP1-33		PIN_AA6　CMD
　・sd_res	出力	JP1-34		PIN_Y5 　DATA_3/CD

　○サウンド出力
　・audio_out[0]	出力	JP1-37		PIN_AB3　PCGサウンド 0
　・audio_out[1]	出力	JP1-38		PIN_Y3 　PCGサウンド 1
　・audio_out[2]	出力	JP1-39		PIN_AB2　PCGサウンド 2
　・audio_out[3]	出力	JP1-40		PIN_AA2　BEEP/CMT出力
　・beep_out	出力	Arduino_IO5	PIN_Y10　1kΩ程度の抵抗を入れて圧電ブザーに接続

　○CMT/SIO入出力
　・cmt_in	入力	Arduino_IO2	PIN_AB7　外部コンパレータ回路が必要
　・motor_out	出力	Arduino_IO3	PIN_AB8　motor 1で3.3V出力
　・rxd		入力	Arduino_IO0	PIN_AB5　SIO入力
　・txd		出力	Arduino_IO1	PIN_AB6　SIO出力

　○白黒コンポジットビデオ出力（カラーバーストなし）
　・bw_out[0]	出力	JP1-1		PIN_V10　SYNC
　・bw_out[1]	出力	JP1-2		PIN_W10　Y信号（2値）

  ※外部I/Oのピン配置はピンアサイナーなどで適宜修正してください


　＜参考回路＞　※FPGAボード側のGNDは省略しているので、もちろんどこかに接続してください
  ○サウンド出力回路
                                         33u
  audio_out[0]   o----10k----o------o----||----o------o 
                             |      |   +      |        PCG/BEEP(CMT)サウンド出力
  audio_out[1]   o----10k----o      |          |      o
                             |     2.2k       10k     |
  audio_out[2]   o----10k----o      |          |      |
                             |      |          |      |
  audio_out[3]   o----10k----o     ---        ---    ---
                             　     ///        ///    /// 


  ○白黒ビデオ出力回路
                                          10u
  　　bw_out[0]  o----4.7k----o------o----||----o------o 
           　　               |      |   +      |        コンポジットビデオ出力
     bw_out[1]  o----2.2k----o     1.2k       10k     o
                                    |          |      |
  　　                              ---        ---    ---
                             　    ///        ///    /// 


■注意事項
　・FPGA、HDLについては完全に素人であり、不具合や誤ったコードなども多く含まれていると思います。追試や利用にあたっては自己責任でお願いします。
　　（万が一、DE10-LiteやDE0-CVなどが壊れても責任は負いかねます）
　・本プロジェクトに関するお問合せは受け兼ねます。また、kwhr0さんなどへの問い合わせなどもしないで下さい。
　・改修及び改修したものの公開は特に制限しませんが、オリジナルを引き継ぎ一切の商用利用は禁止します。


■参考サイト
　・FPGAでPC-8001を作る計画 http://kwhr0.g2.xrea.com/hard/pc8001.html
　・SD-DOS https://github.com/chiqlappe
　・PC-8001をゲームマシン化 http://w01.tp1.jp/~a571632211/pc8001/index.html
　・PC-8001を懐かしむページ https://bugfire2009.ojaru.jp/index.html
　・Enri's Home PAGE http://www43.tok2.com/home/cmpslv/index.htm