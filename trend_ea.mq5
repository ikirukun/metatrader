#property copyright "Copyright 2023, Bard"
#property link      "https://www.example.com"
#property version   "1.00"

input double first_lot = 0.01;//初期ロット
input double nanpin_range = 10000;//ナンピン幅
input double profit_target = 5000;//利益目標
input double stop_loss = 1500;//損切りライン
input double lot_type = 1.5;//マーチン倍率

input int magic_number = 10001;//マジックナンバー
double slippage = 10;//スリッページ

input bool time_limit = true;//エントリー時間制限（true：あり、false：なし）
input string start_time = "15:00";//エントリー開始時間
input string end_time = "23:00";//エントリー終了時間

// input double RSI_buy = 30;//RSIのbuyポジション
// input double RSI_sell = 70;//RSIのsellポジション

// 追加パラメータ
input int adx_period_param = 14;           // ADXの期間
input int macd_fast_ema_param = 12;      // MACDの短期EMA期間
input int macd_slow_ema_param = 26;      // MACDの長期EMA期間
input int macd_signal_param = 9;         // MACDのシグナル期間
input int ma_short_period_param = 10;    // 短期移動平均線の期間
input int ma_long_period_param = 50;     // 長期移動平均線の期間
input ENUM_MA_METHOD ma_method_param = MODE_SMA; // 移動平均線の種類

input int breakout_lookback = 5;         // ブレイクアウト判定のローソク足数
input int support_resistance_lookback = 10; // 支持線・抵抗線判定のローソク足数
input double adx_threshold = 25.0;        // ADXの閾値

// 使用する通貨ペアを定義
string current_symbol;

//+----エントリー時間帯チェック-----------------------------------------------+
bool entryTime(string stime, string etime)
{
   // 現在の日時を取得
   datetime currentTime = TimeCurrent();

   // 文字列から datetime 型に変換するためのフォーマット
   string dateFormat = "%Y.%m.%d ";

   // 開始時間と終了時間を datetime 型に変換
   datetime startTime =  StringToTime(TimeToString(currentTime, TIME_DATE) + " " + stime);
   datetime endTime =  StringToTime(TimeToString(currentTime, TIME_DATE) + " " + etime);

   // 終了時間が開始時間より前の場合、日を跨いだと判断
   if (endTime < startTime) {
      endTime = endTime + 86400; // 終了時間に1日（86400秒）を加算
   }

   // 現在時刻が開始時間と終了時間の間にあるかどうかを判定
   if (startTime <= currentTime && currentTime < endTime) {
      return true;
   } else {
      return false;
   }
}

//+-----------------------------------------------------------------------+
int OnInit()
{
   // EAがアタッチされたチャートの通貨ペアを取得
   current_symbol = Symbol();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   int buy_position = 0;//buyポジション数
   int sell_position = 0;//sellポジション数
   double buy_profit = 0.0;//buyポジションの含み損益
   double sell_profit = 0.0;//sellポジションの含み損益
   double current_buy_lot = 0.0;//最新のbuyポジションのロット数
   double current_sell_lot = 0.0;//最新のsellポジションのロット数
   double current_buy_price = 0.0;//最新のbuyポジションの価格
   double current_sell_price = 0.0;//最新のsellポジションの価格

   bool entry_flag;//エントリーフラグ

//+----エントリー時間帯の確認---------------------------------------------+

   entry_flag=false; //エントリーフラグの初期化

   if(!time_limit){ //エントリー時間制限なし(false)の場合
      entry_flag=true;
   }else
   if(entryTime(start_time,end_time)){ //エントリー時間内(true)の場合
      entry_flag=true;
   }

//+------------------------------------------------------------------+
//+----ポジションの確認----------------------------------------+

   for(int i = 0; i < PositionsTotal(); i++)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != "" && symbol == current_symbol) // 対象通貨ペアのポジションのみ処理
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            buy_position++;
            buy_profit += PositionGetDouble(POSITION_PROFIT);
            current_buy_lot = PositionGetDouble(POSITION_VOLUME);
            current_buy_price = PositionGetDouble(POSITION_PRICE_OPEN);
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               sell_position++;
               sell_profit += PositionGetDouble(POSITION_PROFIT);
               current_sell_lot = PositionGetDouble(POSITION_VOLUME);
               current_sell_price = PositionGetDouble(POSITION_PRICE_OPEN);
              }
        }
     }

//+---------------------------------------------------------+

//+----最新ティックの取得----------------------------------------+

   MqlTick last_tick;
   SymbolInfoTick(current_symbol, last_tick); // 対象通貨ペアのティックを取得

   double Ask=last_tick.ask;
   double Bid=last_tick.bid;

//+---------------------------------------------------------+
// 使用するインジケータのハンドルを取得
   int adx_handle = iADX(current_symbol, Period(), adx_period_param);
   int macd_handle = iMACD(current_symbol, Period(), macd_fast_ema_param, macd_slow_ema_param, macd_signal_param, PRICE_CLOSE);
   int ma_short_handle = iMA(current_symbol, Period(), ma_short_period_param, 0, ma_method_param, PRICE_CLOSE);
   int ma_long_handle = iMA(current_symbol, Period(), ma_long_period_param, 0, ma_method_param, PRICE_CLOSE);

   if(adx_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE || ma_short_handle == INVALID_HANDLE || ma_long_handle == INVALID_HANDLE)
   {
       Print("インジケータハンドルの取得に失敗しました");
       return;
   }
   
   // RSIの設定値を定義します
   int time_period = 14;
   ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE;
    
    // RSIの指標ハンドルを取得します
   int handle = iRSI(current_symbol, PERIOD_CURRENT, time_period, applied_price); // 対象通貨ペアのRSIを取得
    
    // 指標ハンドルが有効かどうか確認します
   if(handle == INVALID_HANDLE)
   {
        Print("iRSI指標ハンドルの取得に失敗しました");
        return;
   }
    
    // RSIの値を取得します
   double rsi[];
   ArraySetAsSeries(rsi, true);
   CopyBuffer(handle, 0, 0, 3, rsi);
   
// インジケータの値を格納する配列
   double adx_values[3];
   double macd_values[2]; // 0: MACD Line, 1: Signal Line
   double ma_short_values[1];
   double ma_long_values[1];

// データのコピー
   CopyBuffer(adx_handle, 0, 0, 1, adx_values);
   CopyBuffer(macd_handle, 0, 0, 1, macd_values);
   CopyBuffer(macd_handle, 1, 0, 1, macd_values); // シグナルライン
   CopyBuffer(ma_short_handle, 0, 0, 1, ma_short_values);
   CopyBuffer(ma_long_handle, 0, 0, 1, ma_long_values);

// ブレイクアウトの条件
   bool buy_breakout = Ask > iHigh(current_symbol, Period(), breakout_lookback);
   bool sell_breakout = Bid < iLow(current_symbol, Period(), breakout_lookback);

// 支持線・抵抗線の条件 (簡略化のため直近の高値・安値を利用)
   double highest_high = iHigh(current_symbol, Period(), support_resistance_lookback);
   double lowest_low = iLow(current_symbol, Period(), support_resistance_lookback);
   bool near_support = Ask < lowest_low;
   bool near_resistance = Bid > highest_high;

// ADXの条件
   bool adx_trend_buy = adx_values[0] > adx_threshold; // トレンドありとみなす
   bool adx_trend_sell = adx_values[0] > adx_threshold;

// MACDの条件
   bool macd_buy_signal = macd_values[0] > macd_values[1];
   bool macd_sell_signal = macd_values[0] < macd_values[1];

// 移動平均線の条件
   bool ma_buy_trend = ma_short_values[0] > ma_long_values[0];
   bool ma_sell_trend = ma_short_values[0] < ma_long_values[0];

   //+----新規エントリー注文----------------------------------------+

   if(buy_position==0 && entry_flag && adx_trend_buy && macd_buy_signal && ma_buy_trend && buy_breakout && 50 <= rsi[0] <= 70)//&& 50 <= rsi[0] <= 70
     {

      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL; // 成行注文
      request.type = ORDER_TYPE_BUY; // 注文タイプ
      request.magic = magic_number; // マジックナンバー
      request.symbol = current_symbol; // 通貨ペア名
      request.volume = first_lot; // ロット数
      request.price = Ask; // 注文価格
      request.deviation = slippage; // スリッページ
      request.comment = "first_buy"; // コメント
      request.type_filling = ORDER_FILLING_IOC; // ボリューム実行ポリシー

      OrderSend(request, result);

     }
   if(sell_position==0 && entry_flag && adx_trend_sell && macd_sell_signal && ma_sell_trend && sell_breakout && 50 >= rsi[0] >= 30)//&& 50 >= rsi[0] >= 30
     {

      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL;// 成行注文
      request.type = ORDER_TYPE_SELL; // 注文タイプ
      request.magic = magic_number; // マジックナンバー
      request.symbol = current_symbol; // 通貨ペア名
      request.volume = first_lot; // ロット数
      request.price = Bid;// 注文価格
      request.deviation = slippage; // スリッページ
      request.comment = "first_sell"; // コメント
      request.type_filling = ORDER_FILLING_IOC; // ボリューム実行ポリシー

      OrderSend(request, result);

     }

//+------------------------------------------------------------------+

//+----追加エントリー（ナンピン）注文----------------------------------------+

   if(buy_position > 0)
     {
      if(Ask < current_buy_price - nanpin_range * Point())  //現在価格がナンピン幅に達しているか
        {

         MqlTradeRequest request = {};
         MqlTradeResult result = {};

         request.action = TRADE_ACTION_DEAL; // 成行注文
         request.type = ORDER_TYPE_BUY;  // 注文タイプ
         request.magic = magic_number; // マジックナンバー
         request.symbol = current_symbol; // 通貨ペア名
         request.volume = round(current_buy_lot*lot_type*100)/100; // ロット数
         request.price = Ask; // 注文価格
         request.deviation = slippage; // スリッページ
         request.comment = "nanpin_buy"; // コメント
         request.type_filling = ORDER_FILLING_IOC; // ボリューム実行ポリシー

         OrderSend(request, result);

        }

     }

   if(sell_position > 0)
     {
      if(Bid > current_sell_price + nanpin_range * Point())  //現在価格がナンピン幅に達しているか
        {

         MqlTradeRequest request = {};
         MqlTradeResult result = {};

         request.action = TRADE_ACTION_DEAL; // 成行注文
         request.type = ORDER_TYPE_SELL; // 注文タイプ
         request.magic = magic_number; // マジックナンバー
         request.symbol = current_symbol; // 通貨ペア名
         request.volume = round(current_sell_lot*lot_type*100)/100; // ロット数
         request.price = Bid; // 注文価格
         request.deviation = slippage; // スリッページ
         request.comment = "nanpin_sell"; // コメント
         request.type_filling = ORDER_FILLING_IOC; // ボリューム実行ポリシー

         OrderSend(request, result);

        }
     }

//+------------------------------------------------------------------+

//+----ポジションクローズ注文----------------------------------------------+

   if(buy_position>0)
     {
      if(buy_profit>profit_target*buy_position)
        {
         buyClose(current_symbol);//すべてbuyポジションをクローズ
        }
      else if(buy_profit < -stop_loss) // 損切り条件を追加
        {
         buyClose(current_symbol); // 損切りでbuyポジションをクローズ
        }
     }

   if(sell_position>0)
     {
      if(sell_profit>profit_target*sell_position)
        {
         sellClose(current_symbol);//すべてsellポジションをクローズ
        }
      else if(sell_profit < -stop_loss) // 損切り条件を追加
        {
         sellClose(current_symbol); // 損切りでsellポジションをクローズ
        }
     }

//+------------------------------------------------------------------+

  }
//+------------------------------------------------------------------+
//|   buyポジションをクローズする関数                                         |
//+------------------------------------------------------------------+
void buyClose(string symbol) // 対象通貨ペアを引数に追加
  {

   for(int i = 0; i < PositionsTotal(); i++)
     {
      string position_symbol = PositionGetSymbol(i);
      if(position_symbol != "" && position_symbol == symbol) // 対象通貨ペアのポジションのみ処理
        {
         if(PositionGetInteger(POSITION_MAGIC)==magic_number)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {

               MqlTradeRequest request = {};
               MqlTradeResult result = {};

               request.position =PositionGetTicket(i); // ポジションチケット
               request.action = TRADE_ACTION_DEAL; // 成行注文
               request.type = ORDER_TYPE_SELL; // 注文タイプ
               request.magic = magic_number; // マジックナンバー
               request.symbol = symbol; // 通貨ペア名
               request.volume = PositionGetDouble(POSITION_VOLUME); // ロット数
               request.price = SymbolInfoDouble(symbol,SYMBOL_BID); // 注文価格
               request.deviation = slippage; // スリッページ
               request.type_filling = ORDER_FILLING_IOC; // ボリューム実行ポリシー

               OrderSend(request, result);

              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|   sellポジションをクローズする関数                                        |
//+------------------------------------------------------------------+
void sellClose(string symbol) // 対象通貨ペアを引数に追加
  {

   for(int i = 0; i < PositionsTotal(); i++)
     {
      string position_symbol = PositionGetSymbol(i);
      if(position_symbol != "" && position_symbol == symbol) // 対象通貨ペアのポジションのみ処理
        {
         if(PositionGetInteger(POSITION_MAGIC)==magic_number)
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {

               MqlTradeRequest request = {};
               MqlTradeResult result = {};

               request.position =PositionGetTicket(i); // ポジションチケット
               request.action = TRADE_ACTION_DEAL;// 成行注文
               request.type = ORDER_TYPE_BUY;             // 注文タイプ
               request.magic = magic_number;             // マジックナンバー
               request.symbol = symbol; // 通貨ペア名
               request.volume = PositionGetDouble(POSITION_VOLUME);              // ロット数
               request.price = SymbolInfoDouble(symbol,SYMBOL_ASK);// 注文価格
               request.deviation = slippage;               // スリッページ
               request.type_filling = ORDER_FILLING_IOC; // ボリューム実行ポリシー

               OrderSend(request, result);

              }

           }
        }
     }
  }