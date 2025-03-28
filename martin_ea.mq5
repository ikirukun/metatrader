#property copyright "Copyright 2023, Bard"
#property link      "https://www.example.com"
#property version   "1.00"

input double first_lot = 0.01;//初期ロット
input double nanpin_range = 400;//ナンピン幅
input double profit_target = 300;//利益目標
input double stop_loss = 100000;//損切りライン
input double lot_type = 1.5;//マーチン倍率

input int magic_number = 10001;//マジックナンバー
double slippage = 10;//スリッページ

input bool time_limit = false;//エントリー時間制限（true：あり、false：なし）
input string start_time = "02:00";//エントリー開始時間
input string end_time = "10:00";//エントリー終了時間

input double RSI_buy = 30;//RSIのbuyポジション
input double RSI_sell = 70;//RSIのsellポジション

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
// 使用する通貨ペアと時間枠を設定します
   //string symbol = "GOLD"; // 既に target_symbol で定義済み
   //ENUM_TIMEFRAMES period = PERIOD_M30;
    
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
    
   //+----新規エントリー注文----------------------------------------+
   
   if(buy_position==0&&entry_flag&&rsi[0] <= RSI_buy)//buyポジションを持っていない、かつエントリーフラグ=trueかつRSIが30以下の場合
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
   if(sell_position==0&&entry_flag&&rsi[0] >= RSI_sell)//sellポジションを持っていない、かつエントリーフラグ=trueかつRSIが70以上の場合
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