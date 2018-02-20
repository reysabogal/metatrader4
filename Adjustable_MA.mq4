//+------------------------------------------------------------------+
//|                                        Adjustable Moving Average |
//|                             Copyright © 2009-2012, EarnForex.com |
//|                                        http://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009-2012, EarnForex"
#property link      "http://www.earnforex.com"

extern double Lots      = 0.1;
extern int StopLoss     = 100;
extern int TakeProfit   = 70;
extern int TrailingStop = 0;
extern int Slippage     = 3;

extern int Period_1  = 20;
extern int Period_2  = 17;
//0 - SMA, 1 - EMA, 2 - SMMA, 3 - LWMA
extern int MA_Method    = 1;
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

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int init()
{
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
   return(0);
}

//+------------------------------------------------------------------+
//| Start function                                                   |
//+------------------------------------------------------------------+
void start()
{
   if (FastMA == SlowMA)
   {
      Print("MA periods should differ.");
      return;
   }

   if (TrailingStop > 0) DoTrailing();

   //Wait for the new Bar in a chart.
	if (LastBars == Bars) return;
	else LastBars = Bars;

   if ((Bars < SlowMA) || (IsTradeAllowed() == false)) return;
   
   CheckCross();
}

//+------------------------------------------------------------------+
//| Check for cross and open/close the positions respectively        |
//+------------------------------------------------------------------+
void CheckCross()
{
   double FMA_Current = iMA(NULL, 0, FastMA, 0, MA_Method, PRICE_CLOSE, 0);
   double SMA_Current = iMA(NULL, 0, SlowMA, 0, MA_Method, PRICE_CLOSE, 0);
   
   if (PrevCross == 0) //Was undefined
   {
      if ((FMA_Current - SMA_Current) >= MinDiff * Poin) PrevCross = 1; //Bullish state
      else if ((SMA_Current - FMA_Current) >= MinDiff * Poin) PrevCross = -1; //Bearish state
      return;
   }
   else if (PrevCross == 1) //Was bullish
   {
      if ((SMA_Current - FMA_Current) >= MinDiff * Poin) //Became bearish
      {
         ClosePrev();
         fSell();
         PrevCross = -1;
      }
   }
   else if (PrevCross == -1) //Was bearish
   {
      if ((FMA_Current - SMA_Current) >= MinDiff * Poin) //Became bullish
      {
         ClosePrev();
         fBuy();
         PrevCross = 1;
      }
   }
}

//+------------------------------------------------------------------+
//| Close previous position                                          |
//+------------------------------------------------------------------+
void ClosePrev()
{
   int total = OrdersTotal();
   for (int i = 0; i < total; i++)
   {
      if (OrderSelect(i, SELECT_BY_POS) == false) continue;
      if ((OrderSymbol() == Symbol()) && (OrderMagicNumber() == Magic))
      {
         if (OrderType() == OP_BUY)
         {
            RefreshRates();
            OrderClose(OrderTicket(), OrderLots(), Bid, Deviation);
         }
         else if (OrderType() == OP_SELL)
         {
            RefreshRates();
            OrderClose(OrderTicket(), OrderLots(), Ask, Deviation);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sell                                                             |
//+------------------------------------------------------------------+
int fSell()
{
	double SL = 0, TP = 0;
	RefreshRates();

	if (!ECN_Mode)
	{
      if (StopLoss > 0) SL = Bid + StopLoss * Poin;
      if (TakeProfit > 0) TP = Bid - TakeProfit * Poin;
   }
	int result = OrderSend(Symbol(), OP_SELL, LotsOptimized(), Bid, Deviation, SL, TP, "Adjustable MA", Magic);

	if (result == -1)
	{
		int e = GetLastError();
		Print(e);
	}
	else
	{
      if (ECN_Mode)
      {
      	RefreshRates();
         OrderSelect(result, SELECT_BY_TICKET);
         if (StopLoss > 0) SL = OrderOpenPrice() + StopLoss * Poin;
         if (TakeProfit > 0) TP = OrderOpenPrice() - TakeProfit * Poin;
         if ((SL != 0) || (TP != 0)) OrderModify(result, OrderOpenPrice(), SL, TP, 0);
      }
      return(result);
	}
}

//+------------------------------------------------------------------+
//| Buy                                                              |
//+------------------------------------------------------------------+
int fBuy()
{
	double SL = 0, TP = 0;
	RefreshRates();

	if (!ECN_Mode)
	{
      if (StopLoss > 0) SL = Ask - StopLoss * Poin;
      if (TakeProfit > 0) TP = Ask + TakeProfit * Poin;
   }
	int result = OrderSend(Symbol(), OP_BUY, LotsOptimized(), Ask, Deviation, SL, TP, "Adjustable MA", Magic);
	
	if (result == -1)
	{
		int e = GetLastError();
		Print(e);
	}
	else
	{
      if (ECN_Mode)
      {
      	RefreshRates();
         OrderSelect(result, SELECT_BY_TICKET);
         if (StopLoss > 0) SL = OrderOpenPrice() - StopLoss * Poin;
         if (TakeProfit > 0) TP = OrderOpenPrice() + TakeProfit * Poin;
         if ((SL != 0) || (TP != 0)) OrderModify(result, OrderOpenPrice(), SL, TP, 0);
      }
      return(result);
   }
}

void DoTrailing()
{
   int total = OrdersTotal();
   for (int pos = 0; pos < total; pos++)
   {
      if (OrderSelect(pos, SELECT_BY_POS) == false) continue;
      if ((OrderMagicNumber() == Magic) && (OrderSymbol() == Symbol()))
      {
         if (OrderType() == OP_BUY)
         {
            RefreshRates();
            if (Bid - OrderOpenPrice() >= TrailingStop * Poin) //If profit is greater or equal to the desired Trailing Stop value
            {
               if (OrderStopLoss() < (Bid - TrailingStop * Poin)) //If the current stop-loss is below the desired trailing stop level
                  OrderModify(OrderTicket(), OrderOpenPrice(), Bid - TrailingStop * Poin, OrderTakeProfit(), 0);
            }
         }
         else if (OrderType() == OP_SELL)
         {
            RefreshRates();
            if (OrderOpenPrice() - Ask >= TrailingStop * Poin) //If profit is greater or equal to the desired Trailing Stop value
            {
	              if ((OrderStopLoss() > (Ask + TrailingStop * Poin)) || (OrderStopLoss() == 0)) //If the current stop-loss is below the desired trailing stop level
                  OrderModify(OrderTicket(), OrderOpenPrice(), Ask + TrailingStop * Poin, OrderTakeProfit(), 0);
            }
         }
      }
   }   
}

double LotsOptimized()
{
   if (!UseMM) return(Lots);
   double vol = NormalizeDouble((AccountFreeMargin() / 10000) * LotsPer10000, 1);
   if (vol <= 0) return(0.1);
   return(vol);
}

//+------------------------------------------------------------------+