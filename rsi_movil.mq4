//+------------------------------------------------------------------+
//|                                                       RSI EA.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                           http://free-bonus-deposit.blogspot.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, dXerof"
#property link      "http://free-bonus-deposit.blogspot.com"
#property version   "1.00"
#property strict

input bool   OpenBUY=True;
input bool   OpenSELL=True;
input bool   CloseBySignal=False;
input double StopLoss=80;
input double TakeProfit=80;
input double TrailingStop=0;
input int    RSIperiod=14;
input double BuyLevel=30;
input double SellLevel=70;
input bool   AutoLot=True;
input double Risk=1.5;
input double ManualLots=0.1;
input int    MagicNumber=123;
input string Koment="RSIea";
input int    Slippage=10;
//---
int OrderBuy,OrderSell;
int ticket;
int LotDigits;
double Trail,iTrailingStop;

// variables de la Media movil

extern int Period_1  = 9;
//extern int Period_2  = 17;
//0 - SMA, 1 - EMA, 2 - SMMA, 3 - LWMA
extern int MA_Method    = 3;
//The minimum difference between MAs for Cross to count
extern int MinDiff      = 3;
// Money management
extern bool UseMM = false;
// Amount of lots per every 10,000 of free margin
extern double LotsPer10000 = 1;

extern bool ECN_Mode = false; // In ECN mode, SL and TP aren't applied on OrderSend() but are added later with OrderModify()

int Magic;
//Depend on broker's quotes
double Poin;
int Deviation;

int LastBars = 0;

//0 - undefined, 1 - bullish cross (fast MA above slow MA), -1 - bearish cross (fast MA below slow MA)
int PrevCross = 0;

int SlowMA;
int FastMA;

double price_val,high_price,low_price;
extern string Timeframe="M1";
int PeriodName=0;
int pband=0;
int pband1=0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
  /*
	FastMA = MathMin(Period_1, Period_2);
    SlowMA = MathMax(Period_1, Period_2);

	Poin = Point;
	Deviation = Slippage;
	//Checking for unconvetional Point digits number
	   if ((Point == 0.00001) || (Point == 0.001))
	   {
		  Poin *= 10;
		  Deviation *= 10;
	   }

   Magic = Period()+19472394;  
   */
   if(Timeframe=="M1") PeriodName=PERIOD_M1;
   else
      if(Timeframe=="M5") PeriodName=PERIOD_M5;
   else
      if(Timeframe=="M15")PeriodName=PERIOD_M15;
   else
      if(Timeframe=="M30")PeriodName=PERIOD_M30;
   else
      if(Timeframe=="H1") PeriodName=PERIOD_H1;
   else
      if(Timeframe=="H4") PeriodName=PERIOD_H4;
   else
      if(Timeframe=="D1") PeriodName=PERIOD_D1;
   else
      if(Timeframe=="W1") PeriodName=PERIOD_W1;
   else
      if(Timeframe=="MN") PeriodName=PERIOD_MN1;
   else
     {
      return(0);
     }
   return(0);   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int deinit()
  {
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
   double stoplevel=MarketInfo(Symbol(),MODE_STOPLEVEL);
   OrderBuy=0;
   OrderSell=0;
   for(int cnt=0; cnt<OrdersTotal(); cnt++)
     {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && OrderComment()==Koment)
           {
            if(OrderType()==OP_BUY) OrderBuy++;
            if(OrderType()==OP_SELL) OrderSell++;
            if(TrailingStop>0)
              {
               iTrailingStop=TrailingStop;
               if(TrailingStop<stoplevel) iTrailingStop=stoplevel;
               Trail=iTrailingStop*Point;
               double tsbuy=NormalizeDouble(Bid-Trail,Digits);
               double tssell=NormalizeDouble(Ask+Trail,Digits);
               if(OrderType()==OP_BUY && Bid-OrderOpenPrice()>Trail && Bid-OrderStopLoss()>Trail)
                 {
                  ticket=OrderModify(OrderTicket(),OrderOpenPrice(),tsbuy,OrderTakeProfit(),0,Blue);
                 }
               if(OrderType()==OP_SELL && OrderOpenPrice()-Ask>Trail && (OrderStopLoss()-Ask>Trail || OrderStopLoss()==0))
                 {
                  ticket=OrderModify(OrderTicket(),OrderOpenPrice(),tssell,OrderTakeProfit(),0,Blue);
                 }
              }
           }
     }
   
   double rsi=iRSI(Symbol(),0,RSIperiod,PRICE_CLOSE,0);
   double rsi1=iRSI(Symbol(),0,RSIperiod,PRICE_CLOSE,1);
     

//--- open position
   if(OpenSELL && OrderSell<1 && rsi<SellLevel && rsi1>SellLevel) pband = 1;
   if(OpenBUY && OrderBuy<1 && rsi>BuyLevel && rsi1<BuyLevel) pband1 = 1;
   
   double FMA_Current = iMA(NULL, 0, Period_1, 0, MA_Method, PRICE_CLOSE, 0);
   high_price=iHigh(NULL,PeriodName,1);
   low_price=iLow(NULL,PeriodName,1);
   price_val = (high_price + low_price)/2;
   
   if (pband == 1 && price_val < FMA_Current) OPSELL(); pband = 0;
   if (pband1 == 1 && price_val > FMA_Current) OPBUY();  pband1 =0;     
    
//--- close position by signal

   if(CloseBySignal)
     {
      if(OrderBuy>0 && rsi<SellLevel && rsi1>SellLevel) CloseBuy();
      if(OrderSell>0 && rsi>BuyLevel && rsi1<BuyLevel) CloseSell();
     }
	 
//---
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OPBUY()
  {
   double StopLossLevel;
   double TakeProfitLevel;
   if(StopLoss>0) StopLossLevel=Bid-StopLoss*Point; else StopLossLevel=0.0;
   if(TakeProfit>0) TakeProfitLevel=Ask+TakeProfit*Point; else TakeProfitLevel=0.0;

   ticket=OrderSend(Symbol(),OP_BUY,LOT(),Ask,Slippage,StopLossLevel,TakeProfitLevel,Koment,MagicNumber,0,DodgerBlue);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OPSELL()
  {
   double StopLossLevel;
   double TakeProfitLevel;
   if(StopLoss>0) StopLossLevel=Ask+StopLoss*Point; else StopLossLevel=0.0;
   if(TakeProfit>0) TakeProfitLevel=Bid-TakeProfit*Point; else TakeProfitLevel=0.0;
//---
   ticket=OrderSend(Symbol(),OP_SELL,LOT(),Bid,Slippage,StopLossLevel,TakeProfitLevel,Koment,MagicNumber,0,DeepPink);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseSell()
  {
   int  total=OrdersTotal();
   for(int y=OrdersTotal()-1; y>=0; y--)
     {
      if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderType()==OP_SELL && OrderMagicNumber()==MagicNumber)
           {
            ticket=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,Black);
           }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseBuy()
  {
   int  total=OrdersTotal();
   for(int y=OrdersTotal()-1; y>=0; y--)
     {
      if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderType()==OP_BUY && OrderMagicNumber()==MagicNumber)
           {
            ticket=OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),5,Black);
           }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LOT()
  {
   double lotsi;
   double ilot_max =MarketInfo(Symbol(),MODE_MAXLOT);
   double ilot_min =MarketInfo(Symbol(),MODE_MINLOT);
   double tick=MarketInfo(Symbol(),MODE_TICKVALUE);
//---
   double  myAccount=AccountBalance();
//---
   if(ilot_min==0.01) LotDigits=2;
   if(ilot_min==0.1) LotDigits=1;
   if(ilot_min==1) LotDigits=0;
//---
   if(AutoLot)
     {
      lotsi=NormalizeDouble((myAccount*Risk)/10000,LotDigits);
        } else { lotsi=ManualLots;
     }
//---
   if(lotsi>=ilot_max) { lotsi=ilot_max; }
//---
   return(lotsi);
  }
//+------------------------------------------------------------------+
