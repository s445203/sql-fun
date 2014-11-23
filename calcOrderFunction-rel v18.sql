/*
 * OPISANIE:  Tozi file e samo za Stephan Gueorguiev.  Molia ne pipaite
 *            nishto po nego.  Ako ste stignali do tuk i imate nuzhda ot neshto, pishete mi
 *            na stephan.g@cantab.net
 */
/*
 * VERSION: 18
 *
 * Release History:
 * VERSION 18: 9.11.2014 moving the stock evaluation point from date of order to date of delivery; Addex maxFaktKol to dnevnazaguba
 * VERSION 17: 8.11.2014 Added calculation of actual inventory hole cost 
 * VERSION 16: 21.10.2014 Fixed order to not go massive on SMC only active for 1 month in last 3
 * VERSION 14-15:  New reverse and forward razpredelenie
 * VERSION 13: 3.10.2014   Added SofiaPC to calcorder.  Changed days ordered for obekt to 5.  Also added moveP2P.
 * VERSION 11: 14.09.2014  Increased Sofia orders for obekt expansion in calcOrder (0.7 factor for Sofia)
 * VERSION 10: 06.09.2014 Veliko Turnovo Changes  
 * VERSION 9: 25.08.2014  Changed DailyHoleCost API to reduce errors.
 * VERSION 8: 03.08.2014 Lowered threshold for 999999 on SofiaMax 0 to 0.  It was 0.5 before.
 * VERSION 7: 02.08.2014 Updated calcOrder API to the new version. 
 * VERSION 6: 30.07.2014 Updated calcOrder to disperse at least one komplekt to the stores  for Q<2000 and spit out true order in signal column.
 * VERSION 5: 30.07.2014 Updated DailyHoleCost to use actual ltm GP per SMC rather than single blanket figure.
 * VERSION 4: 29.07.2014. Updated calcOrder return 9s for low sales items that would otherwise never get ordered.
 * VERSION 3: 28.07.2014. Updated calcOrder to consider sales in current calendar month.
 * VERSION 2: 25.07.2014 Added rounding up for komplektacia to calcOrderFunction and calcMove functions.
 * VERSION 1: 23.07.2014 Initial release.  Functions used in report generation.
 */
IF OBJECT_ID ( 'dbo.sgCalcOrder', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgCalcOrder; 
IF OBJECT_ID ( 'dbo.sgNumActiveMonths', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgNumActiveMonths; 
IF OBJECT_ID ( 'dbo.sgDailyHoleCost', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgDailyHoleCost; 
IF OBJECT_ID ( 'dbo.sgCalcMove', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgCalcMove;
IF OBJECT_ID ( 'dbo.sgMax', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgMax;
IF OBJECT_ID ( 'dbo.sgMin', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgMin;


CREATE FUNCTION dbo.sgCalcMoveVT(@srcStore INT, @destStore INT,@komplekt Real,@Quality Real,@daySales3 Real, @daySales21 Real, @MaxFaktKol Real, @QualityCutOff Real,@store1Inv Real,@store2Inv Real)
RETURNS Real
AS
BEGIN
    DECLARE @stockToMove INT;
    DECLARE @srcStock Real;
    DECLARE @dstStock Real;
    DECLARE @availableSrc Real;
    DECLARE @dstStockNeeded Real;
    DECLARE @dstActualNeed1 Real;
    DECLARE @totalNeedAllStores Real;
	DECLARE @sendFactor Real;
	/*
     * We dont have enough capital to hold lower quality than the cutoff passed in.
     */
	IF @Quality > @QualityCutOff RETURN 0;
    /*
     * Compute source and dest quantities
     */
	IF @srcStore = 1 SET @srcStock = @store1Inv;
	IF @destStore = 2 SET @dstStock = @store2Inv;
    /*
     * What is the target quantity to hold.
     * If komplekt, we round up to 1 komplekt for the stores.
     */
    SET @dstStockNeeded = dbo.sgMax(1,@daySales3,@MaxFaktKol);
    SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded,@komplekt,0);
    /*
	 * How much do we need to send to the target store?
	 */
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @dstStock,0,0);
    /*
     * Then we see if the source store can supply
     */
    SET @availableSrc = dbo.sgMin(@srcStock - @daySales21,@srcStock - @MaxFaktKol,@srcStock - @komplekt);
    IF @availableSrc < 0 SET @availableSrc = 0;
	IF @availableSrc > @dstStockNeeded
		SET @stockToMove = @dstStockNeeded
	ELSE
		SET @stockToMove = @availableSrc
	END
	/*
	 * Scale how much to send.  
	 */
	SET @stockToMove = FLOOR(@sendFactor * @dstStockNeeded);
	/*
	 * We dont send if by sending we dont have enough for one
	 * komplekt.
	 */
	IF ((@stockToMove + @dstStock) < @komplekt) SET @stockToMove = 0;
    RETURN @stockToMove;
END

IF OBJECT_ID ( 'dbo.sgCalcReturnMove', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgCalcReturnMove;
CREATE FUNCTION dbo.sgCalcReturnMove(@srcStore INT,@komplekt Real,@Quality Real,@expDstSales Real, @expSrcSales Real, @sendThresholdStock Real, @MaxFaktKol Real, @QualityCutOff Real,@store1Inv Real, @store2Inv Real, @store3Inv Real, @store4Inv Real, @store5Inv Real, @sendLimit Real)
RETURNS Real
AS
BEGIN
	DECLARE @stockToMove INT;
    DECLARE @dstStockNeeded Real;
    DECLARE @availableSrc2 Real,@availableSrc3 Real,@availableSrc4 Real,@availableSrc5 Real;
	DECLARE @sendFrom2 Real,@sendFrom3 Real,@sendFrom4 Real,@sendFrom5 Real;
	/*
	 */
	IF @Quality IS NULL SET @Quality = 100000
	/*
	 * First we check if we have less stock than the send threshold
	 */
	IF (@store1Inv > @sendThresholdStock) AND (@store1Inv > @maxFaktKol) AND (@store1Inv > @komplekt)
		RETURN 0;
    /*
     * Compute Sofia need
     */
    SET @dstStockNeeded = dbo.sgMax(1,@expDstSales,@MaxFaktKol);
    SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded,@komplekt,0);
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @store1Inv,0,0);
    /*
     * Then we see if the source store can supply
     */
	IF @Quality > @QualityCutoff
	BEGIN
		/*
		 * For low quality, our source is the whole inventory
		 */
		SET @availableSrc2 = @store2Inv;
		SET @availableSrc3 = @store3Inv;
		SET @availableSrc4 = @store4Inv;
		SET @availableSrc5 = @store5Inv;
	END
	ELSE
	BEGIN
	    /*
	     * For higher quality, our source is only the excess
	     */
		SET @availableSrc2 = @store2Inv - dbo.sgRoundStock(@expSrcSales,@komplekt,@MaxFaktKol,0);
		SET @availableSrc3 = @store3Inv - dbo.sgRoundStock(@expSrcSales,@komplekt,@MaxFaktKol,0);
		SET @availableSrc4 = @store4Inv - dbo.sgRoundStock(@expSrcSales,@komplekt,@MaxFaktKol,0);
		SET @availableSrc5 = @store5Inv - dbo.sgRoundStock(@expSrcSales,@komplekt,@MaxFaktKol,0);
	END
	IF @availableSrc2 < 0 SET @availableSrc2 = 0;
	IF @availableSrc3 < 0 SET @availableSrc3 = 0;
	IF @availableSrc4 < 0 SET @availableSrc4 = 0;
    IF @availableSrc5 < 0 SET @availableSrc5 = 0;
	SET @sendFrom5 = dbo.sgMin(@dstStockNeeded,@availableSrc5,1000000);
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @sendFrom5,0,0);
	SET @sendFrom4 = dbo.sgMin(@dstStockNeeded,@availableSrc4,1000000);
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @sendFrom4,0,0);
	SET @sendFrom3 = dbo.sgMin(@dstStockNeeded,@availableSrc3,1000000);
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @sendFrom3,0,0);
	SET @sendFrom2 = dbo.sgMin(@dstStockNeeded,@availableSrc2,1000000);
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @sendFrom2,0,0);
	IF @srcStore = 2 SET @stockToMove = @sendFrom2;
	IF @srcStore = 3 SET @stockToMove = @sendFrom3;
	IF @srcStore = 4 SET @stockToMove = @sendFrom4;
	IF @srcStore = 5 SET @stockToMove = @sendFrom5;
    RETURN @stockToMove;
END


IF OBJECT_ID ( 'dbo.sgCalcMoveP2P', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgCalcMoveP2P;
CREATE FUNCTION dbo.sgCalcMoveP2P(@srcStore INT, @destStore INT,@komplekt Real,@Quality Real,@daySales3 Real, @daySales21 Real, @MaxFaktKol Real, @QualityCutOff Real,@store1Inv Real,@store2Inv Real)
RETURNS Real
AS
BEGIN
    DECLARE @stockToMove INT;
    DECLARE @srcStock Real;
    DECLARE @dstStock Real;
    DECLARE @availableSrc Real;
    DECLARE @dstStockNeeded Real;
    /*
     * Quality can be passed in as NULL if we havent sold it in the last 12 months, but this effectively means
     * its really low, so we set it to 100000
     */
	IF @quality IS NULL RETURN 0;
	--IF @Quality > @QualityCutOff RETURN 0;
    /*
     * Compute source and dest quantities
     */
	IF @srcStore = 1 SET @srcStock = @store1Inv;
	IF @destStore = 2 SET @dstStock = @store2Inv;
    /*
     * What is the target quantity to hold.
     * If komplekt, we round up to 1 komplekt for the stores.
     */
    SET @dstStockNeeded = dbo.sgMax(1,@daySales3,@MaxFaktKol);
    SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded,@komplekt,0);
    /*
	 * How much do we need to send to the target store?
	 */
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @dstStock,0,0);
    /*
     * Then we see if the source store can supply
     */
    SET @availableSrc = dbo.sgMin(@srcStock - @daySales21,@srcStock - @MaxFaktKol,@srcStock - @komplekt);
    IF @availableSrc < 0 SET @availableSrc = 0;
	IF @availableSrc > @dstStockNeeded
		IF @Quality > @QualityCutOff
			/*
			 * We want to have lower quality SMCs in Sofia rather than the obekt
			 * so we send all of our excess
			 */
			SET @stockToMove = @availableSrc
		ELSE
			/*
			 * For higher quality SMCs we send only enough excess to cover Sofia need
			 */
			SET @stockToMove = @dstStockNeeded
	ELSE
		SET @stockToMove = 0
	/*
	 * We dont send if by sending we dont have enough for one
	 * komplekt.
	 */
	IF ((@stockToMove + @dstStock) < @komplekt) SET @stockToMove = 0;
    RETURN @stockToMove;
END

IF OBJECT_ID ( 'dbo.sgRoundStock', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgRoundStock;
CREATE FUNCTION dbo.sgRoundStock(@expSales Real, @komplekt Real, @MaxFaktKol Real, @lowThresh Real)
RETURNS Real
AS
BEGIN
    DECLARE @lump Real, @rtnVal  Real;
    SET @lump = dbo.sgMax(@MaxFaktKol,@komplekt,0);
    IF (@lump > 0)
	BEGIN
		SET @rtnVal = FLOOR(@expSales / @lump) * @lump
		SET @rtnVal = dbo.sgMax(@expSales, @rtnVal,@lump);
	END
	ELSE
		SET @rtnVal = @expSales;
	SET @rtnVal = dbo.sgMax(@lowThresh,@rtnVal,0);
	RETURN @rtnVal
END

IF OBJECT_ID ( 'dbo.sgCalcMovePriority', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgCalcMovePriority;
CREATE FUNCTION dbo.sgCalcMovePriority(@destStore INT,@komplekt Real,@Quality Real,@expDstSales Real, @expSrcSales Real, @MaxFaktKol Real, @QualityCutOff Real,@store1Inv Real, @store2Inv Real, @store3Inv Real, @store4Inv Real, @store5Inv Real, @sendLimit Real)
RETURNS Real
AS
BEGIN
    DECLARE @stockToMove INT;
    DECLARE @srcStock Real;
    DECLARE @dstStock Real;
    DECLARE @availableSrc Real;
    DECLARE @dstStockNeeded Real;
    DECLARE @dstActualNeed1 Real,@dstActualNeed2 Real,@dstActualNeed3 Real,@dstActualNeed4 Real, @dstActualNeed5 Real;
    DECLARE @totalNeedAllStores Real;
	DECLARE @sendFactor Real;
	DECLARE @sendTo2 Real,@sendTo3 Real,@sendTo4 Real,@sendTo5 Real;
    /*
     * What is the target quantity to hold.
     * If komplekt, we round up to 1 komplekt for the stores.
     */
    SET @dstStockNeeded = dbo.sgRoundStock(@expDstSales,@komplekt,@MaxFaktKol,1);
    /*
     * How much do we need to send everywhere?
     */
	SET @dstActualNeed2 = dbo.sgMax(@dstStockNeeded - @store2Inv,0,0);
	SET @dstActualNeed3 = dbo.sgMax(@dstStockNeeded - @store3Inv,0,0);
	SET @dstActualNeed4 = dbo.sgMax(@dstStockNeeded - @store4Inv,0,0);
	SET @dstActualNeed5 = dbo.sgMax(@dstStockNeeded - @store5Inv,0,0);
    /*
     * Then we see if the source store can supply - we keep at least 2 in Sofia
     */    
	SET @availableSrc = @store1Inv - dbo.sgRoundStock(@expSrcSales,@komplekt,@MaxFaktKol,2);
	IF @availableSrc < 0 SET @availableSrc = 0;
    /*
     * We send in order of priority.  We don't send if we won't have enough for one komplekt
     * at destination.
     */
	SET @sendTo2 = dbo.sgMin(@availableSrc,@dstActualNeed2,1000000);
	IF (@sendTo2 + @store2Inv) < @komplekt SET @sendTo2 = 0;
	SET @availableSrc = dbo.sgMax(@availableSrc - @sendTo2,0,0);
	SET @sendTo3 = dbo.sgMin(@availableSrc,@dstActualNeed3,1000000);
	IF (@sendTo3 + @store3Inv) < @komplekt SET @sendTo3 = 0;
	SET @availableSrc = dbo.sgMax(@availableSrc - @sendTo3,0,0);
	SET @sendTo4 = dbo.sgMin(@availableSrc,@dstActualNeed4,1000000);
	IF (@sendTo4 + @store4Inv) < @komplekt SET @sendTo4 = 0;
	SET @availableSrc = dbo.sgMax(@availableSrc - @sendTo4,0,0);
	SET @sendTo5 = dbo.sgMin(@availableSrc,@dstActualNeed5,1000000);
	IF (@sendTo5 + @store5Inv) < @komplekt SET @sendTo5 = 0;
	SET @availableSrc = dbo.sgMax(@availableSrc - @sendTo5,0,0);
	IF @destStore = 2 SET @stockToMove = @sendTo2;
	IF @destStore = 3 SET @stockToMove = @sendTo3;
	IF @destStore = 4 SET @stockToMove = @sendTo4;
	IF @destStore = 5 SET @stockToMove = @sendTo5;
    RETURN @stockToMove;
END


CREATE FUNCTION dbo.sgCalcMove(@srcStore INT, @destStore INT,@komplekt Real,@Quality Real,@daySales3 Real, @daySales21 Real, @MaxFaktKol Real, @QualityCutOff Real,@store1Inv Real, @store2Inv Real, @store3Inv Real, @store4Inv Real, @store5Inv Real, @sendLimit Real)
RETURNS Real
AS
BEGIN
    DECLARE @stockToMove INT;
    DECLARE @srcStock Real;
    DECLARE @dstStock Real;
    DECLARE @availableSrc Real;
    DECLARE @dstStockNeeded Real;
    DECLARE @dstActualNeed1 Real,@dstActualNeed2 Real,@dstActualNeed3 Real,@dstActualNeed4 Real, @dstActualNeed5 Real;
    DECLARE @totalNeedAllStores Real;
	DECLARE @sendFactor Real;
	/*
     * We dont have enough capital to hold lower quality than the cutoff passed in.
     */
	IF @Quality > @QualityCutOff RETURN 0;
    /*
     * Compute source and dest quantities
     */
	IF @srcStore = 1 SET @srcStock = @store1Inv;
	IF @srcStore = 2 SET @srcStock = @store2Inv;
	IF @srcStore = 3 SET @srcStock = @store3Inv;
	IF @srcStore = 4 SET @srcStock = @store4Inv;
	IF @srcStore = 5 SET @srcStock = @store5Inv;
	IF @destStore = 1 SET @dstStock = @store1Inv;
	IF @destStore = 2 SET @dstStock = @store2Inv;
	IF @destStore = 3 SET @dstStock = @store3Inv;
	IF @destStore = 4 SET @dstStock = @store4Inv;
	IF @destStore = 5 SET @dstStock = @store5Inv;
    /*
     * What is the target quantity to hold.
     * If komplekt, we round up to 1 komplekt for the stores.
     */
    SET @dstStockNeeded = dbo.sgMax(1,@daySales3,@MaxFaktKol);
    SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded,@komplekt,0);
    /*
     * How much do we need to send everywhere?
     */
	SET @dstActualNeed1 = dbo.sgMax(@dstStockNeeded - @store1Inv,0,0);
	SET @dstActualNeed2 = dbo.sgMax(@dstStockNeeded - @store2Inv,0,0);
	SET @dstActualNeed3 = dbo.sgMax(@dstStockNeeded - @store3Inv,0,0);
	SET @dstActualNeed4 = dbo.sgMax(@dstStockNeeded - @store4Inv,0,0);
	SET @dstActualNeed5 = dbo.sgMax(@dstStockNeeded - @store5Inv,0,0);
	SET @totalNeedAllStores = @dstActualNeed1 + @dstActualNeed2 + @dstActualNeed3 + @dstActualNeed4 + @dstActualNeed5;
	/*
	 * How much do we need to send to the target store?
	 */
	SET @dstStockNeeded = dbo.sgMax(@dstStockNeeded - @dstStock,0,0);
    /*
     * Then we see if the source store can supply
     */
    SET @availableSrc = dbo.sgMin(@srcStock - @daySales21,@srcStock - @MaxFaktKol,@srcStock - @komplekt);
    SET @availableSrc = dbo.sgMin(@availableSrc,@sendLimit,10000000);
    IF @availableSrc < 0 SET @availableSrc = 0;
	IF (@availableSrc > @totalNeedAllStores) OR (@totalNeedAllStores = 0)
		SET @sendFactor = 1;
	ELSE
		SET @sendFactor = @availableSrc / @totalNeedAllStores;
	/*
	 * Scale how much to send.  
	 */
	SET @stockToMove = FLOOR(@sendFactor * @dstStockNeeded);
	/*
	 * We dont send if by sending we dont have enough for one
	 * komplekt.
	 */
	IF ((@stockToMove + @dstStock) < @komplekt) SET @stockToMove = 0;
    RETURN @stockToMove;
END

CREATE FUNCTION dbo.sgMax(@val1 Real, @val2 Real, @val3 Real)
RETURNS Real
AS
BEGIN
  DECLARE @max12 Real
  IF @val1 > @val2
    SET @max12 =  @val1
  ELSE
	SET @max12 = @val2
  IF @max12 > @val3
	 RETURN @max12;
  RETURN ISNULL(@val3,@max12)
END

CREATE FUNCTION dbo.sgMin(@val1 Real, @val2 Real, @val3 Real)
RETURNS Real
AS
BEGIN
  DECLARE @min12 Real
  IF @val1 < @val2
    SET @min12 =  @val1
  ELSE
	SET @min12 = @val2
  IF @min12 < @val3
	 RETURN @min12;
  RETURN ISNULL(@val3,@min12)
END

IF OBJECT_ID ( 'dbo.sgDailyHoleCost', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgDailyHoleCost; 
CREATE FUNCTION dbo.sgDailyHoleCost(@monthlySalesRate Real, @maxFaktKol Real, @stock Real, @ltmRev Real, @ltmGP Real, @ltmKol Real, @ltmCOGS Real, @purchasePrice Real)
RETURNS Real
AS
BEGIN
    DECLARE @dailyHoleCost Real;
	DECLARE @grossProfitMargin Real;
	IF ((@monthlySalesRate <= 0) OR (@monthlySalesRate IS NULL) OR (@purchasePrice <= 0) OR (@maxFaktKol < 0)) RETURN 0;
	IF ((@ltmKol <= 0) OR (@ltmRev <= 0) OR (@ltmGP <= 0) OR (@ltmKol IS NULL) OR (@ltmRev IS NULL) OR (@ltmGP IS NULL) OR (@ltmGP = @ltmRev)) RETURN 0;
	IF (@stock < @maxFaktKol)
		SET @dailyHoleCost = (@ltmGP / @ltmKol) * @monthlySalesRate / 30;
	ELSE
	    SET @dailyHoleCost = 0;
	RETURN @dailyHoleCost;
END

IF OBJECT_ID ( 'dbo.sgDailyOrderDelayCost', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgDailyOrderDelayCost; 
CREATE FUNCTION dbo.sgDailyOrderDelayCost(@monthlySalesRate Real, @maxFaktKol Real, @leadTimeMonths Real, @stock Real, @ltmRev Real, @ltmGP Real, @ltmKol Real, @ltmCOGS Real, @purchasePrice Real)
RETURNS Real
AS
BEGIN
    DECLARE @dailyHoleCost Real;
	DECLARE @grossProfitMargin Real;
	IF ((@monthlySalesRate <= 0) OR (@monthlySalesRate IS NULL) OR (@leadTimeMonths < 0) OR (@purchasePrice <= 0)) RETURN 0;
	IF ((@ltmKol <= 0) OR (@ltmRev <= 0) OR (@ltmGP <= 0) OR (@ltmKol IS NULL) OR (@ltmRev IS NULL) OR (@ltmGP IS NULL) OR (@ltmGP = @ltmRev)) RETURN 0;
	IF ((@leadTimeMonths * @monthlySalesRate) > (@stock - @maxFaktKol))
		SET @dailyHoleCost = (@ltmGP / @ltmKol) * @monthlySalesRate / 30;
	ELSE
	    SET @dailyHoleCost = 0;
	RETURN @dailyHoleCost;
END

IF OBJECT_ID ( 'dbo.sgCalcOrder', 'FN' ) IS NOT NULL DROP FUNCTION dbo.sgCalcOrder;
CREATE FUNCTION dbo.sgCalcOrder(@bReturnNegativeOrderQ INT,@bReturn9Q INT,
								@bufferSafety Real, @komplekt Real, @quality Real,
								@leadTimeMonths Real,
								@salesThisMonth Real,
								@sales3 Real, @sales6 Real, @sales12 Real, @sales24 Real,
								@active3 INT,@active6 INT, @active12 Real, @active24 Real,
								@stock Real,
								@SofiaMax Real, @SofiaPC Real, @dayToday INT, @maxFaktKol Real)
RETURNS Real
AS
BEGIN
    DECLARE @monthlyForecast Real, @unadjMonthlyForecast Real, @SofiaNeed Real;
    DECLARE @weight3 Real, @weight6 Real, @weight12 Real, @weight24 Real;
    DECLARE @sumWeights Real;
    DECLARE @targetStock Real;
    DECLARE @orderValue Real;
	DECLARE @broiKomplekt Real;
	DECLARE @obektNeed Real;
	DECLARE @ave3 Real, @ave6 Real, @ave12 Real, @ave24 Real;
	/* 
	 * Occasionally its just returns - clean the data
	 */
	IF (@salesThisMonth < 0) SET @salesThisMonth = 0;
	IF (@sales3 < 0) SET @sales3 = 0;
	IF (@sales6 < 0) SET @sales6 = 0;
	IF (@sales12 < 0) SET @sales12 = 0;
	IF (@sales24 < 0) SET @sales24 = 0;
	IF (@stock < 0) SET @stock = 0;
	/*
	 * We try to use number of active months, otherwise we fall back on average sales
	 * if there are no active months but we have sales anyway.
	 *
	 * However, if there's less than one third active months for the period, the
	 * signal gets distorted, so we use actual sales to avoid over-ordering.
	 *
	 * At the same time we extend everything with sales from the current month.
	 */
	IF ((@active3 IS NOT NULL) AND (@active3 > 1)) SET @ave3 = (@sales3 + @salesThisMonth) / (@active3 + @dayToday / 31) ELSE SET @ave3 = (@sales3 + @salesThisMonth) / (3 + (@dayToday / 31));
	IF ((@active6 IS NOT NULL) AND (@active6 > 2)) SET @ave6 = (@sales6 + @salesThisMonth) / (@active6 + @dayToday / 31) ELSE SET @ave6 = (@sales6 + @salesThisMonth) / (6 + (@dayToday / 31));
	IF ((@active12 IS NOT NULL) AND (@active12 > 4)) SET @ave12 = (@sales12 + @salesThisMonth) / (@active12 + @dayToday / 31) ELSE SET @ave12 = (@sales12 + @salesThisMonth) / (12 + (@dayToday / 31));
	IF ((@active24 IS NOT NULL) AND (@active24 > 8)) SET @ave24 = (@sales24 + @salesThisMonth) / (@active24 + @dayToday / 31) ELSE SET @ave24 = (@sales24 + @salesThisMonth) / (24 + (@dayToday / 31));
	/*
	 *
	 */
	SET @weight3 = 6;
    SET @weight6 = 3;
    SET @weight12 = 1;
    SET @weight24 = 0.5;
    SET @sumWeights = @weight3 + @weight6 + @weight12 + @weight24;
    /*
     * Quality can be passed in as NULL if we havent sold it in the last 12 months, but this effectively means
     * its really low, so we set it to 100000
     */
	IF @quality IS NULL SET @quality = 100000
    --
    IF @sumWeights > 0 SET @monthlyForecast = (@weight3*@ave3 + @weight6*@ave6 + @weight12*@ave12+@weight24*@ave24)/@sumWeights
    ELSE SET @monthlyForecast = 0;
	/*
	 * If were consistently selling less as time goes by and its a low turn item, we stop
	 */
	IF (@ave3 < @ave6) AND (@ave6 < @ave12) AND (@ave12 < @ave24) AND (@ave3 < 1) SET @monthlyForecast = 0;
    /*
     * If something is accelerating and we have holes the last
     * 3 months, we accelerate our forecast by 20%
     */
    SET @unadjMonthlyForecast = @monthlyForecast
	IF (@ave3 > @ave6) AND (@ave6 > @ave12) AND (@ave12 > @ave24) AND (@active3 IS NOT NULL) AND (@active3 < 3) SET @monthlyForecast = @monthlyForecast * 1.2;
    /*
     * If we have no sales the last 3 months Mariyan gets worried, so we halve the monthly forecast
     */
    IF (@salesThisMonth + @sales3) = 0 SET @monthlyForecast = @monthlyForecast / 2;
    /*
     * For stuff we really short lead time this does not work properly
     * So we set the lead time to 0.5 a month - in reality we cannot react any quicker than that today
     */
    IF @leadTimeMonths < 0.5 SET @leadTimeMonths = 0.5
	SET @targetStock = @leadTimeMonths * @monthlyForecast * (@bufferSafety + 1);
    /*
     * Now we check if we need to increase target stock for Byala, Ruse and Varna.
     * If the SMC is good enough quality, we stock the max number of 
     * 3 day sales, komplekt or max fakt in each object.
     *
     * If this amounts to more than the target stock, we order more.  Otherwise
     * its just the monthly forecast.
     * 
     */
	IF (@quality < 6000) AND (@targetStock > 0) AND (@monthlyForecast > 0)
	BEGIN
		/*
		 * We use the % of sales from Sofia the last 12 months to also order for Sofia. 
		 * For dead stock we get SofiaPC as NULL so we assume in this cases 0.7 is the right number
		 */
		IF ((@SofiaPC <= 0) OR (@SofiaPC IS NULL)) SET @SofiaPC = 0.7;
	    /*
	     * The 5 here needs to match the dni obespechenie na obekt used in the razpredelenie
	     * function - this is how much stock we order for each obekt
	     * We order enough for each store to supply all the stores need (yes, its overkill) but
	     * otherwise we run too lean.  This is the reason for the (1-@SofiaPC)
	     */
		SET @obektNeed = dbo.sgMax(1, 5*(1-@SofiaPC)*@monthlyForecast/31, @maxFaktKol);
		SET @obektNeed = ROUND(@obektNeed,0);
		SET @obektNeed = dbo.sgMax(@komplekt, @obektNeed, 1);
		/*
		 * Now Sofia
		 */
		SET @SofiaNeed = @SofiaPC * @leadTimeMonths * @monthlyForecast * (@bufferSafety + 1);
		SET @SofiaNeed = dbo.sgMax(@SofiaNeed, @maxFaktKol,0)
		/*
		 * There are now 4 other obekts where we hold stock.
		 */
		SET @obektNeed = 4*@obektNeed + @SofiaNeed;
		IF (@obektNeed > @targetStock) SET @targetStock = @obektNeed
	END
	/*
	 * Expand to nearest whole order quantity.  If you want to hold enough for just a single komplekt,
	 * then replace
	 * IF (@komplekt > 0)
	 *   with
	 * IF (@komplekt > @targetStock)
	 */
	IF (@komplekt > 0)
	BEGIN
		/*
		 * We buy at least one komplekt.  After that we round to the 
		 * nearest komplekt quantity to buy.
		 */
		SET @broiKomplekt = ROUND(@targetStock / @komplekt,0);
		IF (@broiKomplekt = 0) SET @broiKomplekt = 1;
		SET @targetStock = @broiKomplekt * @komplekt;
	END
	--SET @orderValue = @targetStock - @stock;
	SET @orderValue = @targetStock - dbo.sgMax((@stock - (@unadjMonthlyForecast * @leadTimeMonths)),0,0)
	/*
	 * If SofiaMax is zero, and we think we should order it, we flag it
	 */
	IF (@SofiaMax = 0) AND (@orderValue > 0) AND (@bReturnNegativeOrderQ = 0)
	BEGIN
		IF (@sales6 + @salesThisMonth > 0) SET @orderValue = 999999 ELSE SET @orderValue = 0;
	END
	/*
	 * Old SMCs with incorrect Max k-vo - likely switched to another SMC. We flag.
	 */
	IF (@SofiaMax > 0) AND (@orderValue > 0.5) AND ((@sales6 + @salesThisMonth) = 0) AND (@bReturnNegativeOrderQ = 0)
	BEGIN
		IF (@stock = 0) SET @orderValue = 999999 ELSE SET @orderValue = 0;
	END
	/*
	 * If SofiaMax is minus one, we never order it and dont waste time flagging it.
	 */
	IF (@SofiaMax = -1) SET @orderValue = 0
	/*
	 *  Now we have rules for very low sales stock, which might never get ordered
	 *  and needs to be flagged.
	 *  If we have had this active in the last three months and its order value is
	 *  such that it would get rounded to zero always, and its not in stock and it is not
	 *  dead stock.....then somehting is fishy and we need to look at it by hand. 
	 */
	IF     (@bReturn9Q = 1) AND (@bReturnNegativeOrderQ = 0)
	   AND ((@sales3 + @salesThisMonth) > 0) 
	   AND (@orderValue > 0) AND (@orderValue < 0.5) 
	   AND (@stock = 0) 
	   AND (@quality <> 100000
	   AND (@SofiaMax > 0)) SET @orderValue = 999999;
	/*
	 * Clean up the output for CHISTA ZAIAVKA
	 */
	IF @bReturnNegativeOrderQ = 0 AND @orderValue < 0 SET @orderValue = 0
	IF @bReturn9Q = 0 AND @orderValue = 999999 SET @orderValue = 0
	IF @bReturnNegativeOrderQ = 0 SET @orderValue = ROUND(@orderValue,0)
	RETURN @orderValue;
END


EXEC sp_helptext 'sgCalcOrder';

SELECT dbo.sgCalcOrder(1,1,1,1,1,1) AS foo;

/*
 * Return the number of months which had non-zero inventory at both the beginning
 * and the end of the month in our intentory window
 * 
 * Inventory values passed in may be NULL in which case we convert them to 0.
 * 
 * InventoryWindow must be 3,6,9,12 or 24, otherwise we return -1 as error.
 */
CREATE FUNCTION dbo.sgNumActiveMonths(@InventoryWindow INT, @I1 Real, --Inventory at beginning of current month
     @I2 Real,  --Inventory at beginning of month before current
     @I3 Real,
     @I4 Real,
     @I5 Real,
     @I6 Real,
     @I7 Real,
     @I8 Real,
     @I9 Real,
     @I10 Real,
     @I11 Real,
     @I12 Real,
     @I13 Real,
     @I14 Real,
     @I15 Real,
     @I16 Real,
     @I17 Real,
     @I18 Real,
     @I19 Real,
     @I20 Real,
     @I21 Real,
     @I22 Real,
     @I23 Real,
     @I24 Real,
     @I25 Real)
 RETURNS INT
 AS
 BEGIN
     DECLARE @activeMonths3 INT,@activeMonths6 INT,@activeMonths12 INT,@activeMonths24 INT,@returnVal INT; 
     SET @activeMonths3 = 0;
     SET @activeMonths6 = 0;
     SET @activeMonths12 = 0;
     SET @activeMonths24 = 0;
     SET @returnVal = -1;
     --
     IF (ISNULL(@I1,0) > 0) AND (ISNULL(@I2,0) > 0) SET @activeMonths3 = @activeMonths3 + 1;
     IF (ISNULL(@I2,0) > 0) AND (ISNULL(@I3,0) > 0) SET @activeMonths3 = @activeMonths3 + 1;
     IF (ISNULL(@I3,0) > 0) AND (ISNULL(@I4,0) > 0) SET @activeMonths3 = @activeMonths3 + 1;
     SET @activeMonths6 = @activeMonths3;
     --
     IF (ISNULL(@I4,0) > 0) AND (ISNULL(@I5,0) > 0) SET @activeMonths6 = @activeMonths6 + 1;
     IF (ISNULL(@I5,0) > 0) AND (ISNULL(@I6,0) > 0) SET @activeMonths6 = @activeMonths6 + 1;
     IF (ISNULL(@I6,0) > 0) AND (ISNULL(@I7,0) > 0) SET @activeMonths6 = @activeMonths6 + 1;
     SET @activeMonths12 = @activeMonths6;
     --    
     IF (ISNULL(@I7,0) > 0) AND (ISNULL(@I8,0) > 0) SET @activeMonths12 = @activeMonths12 + 1;
     IF (ISNULL(@I8,0) > 0) AND (ISNULL(@I9,0) > 0) SET @activeMonths12 = @activeMonths12 + 1;
     IF (ISNULL(@I9,0) > 0) AND (ISNULL(@I10,0) > 0) SET @activeMonths12 = @activeMonths12 + 1;
     IF (ISNULL(@I10,0) > 0) AND (ISNULL(@I11,0) > 0) SET @activeMonths12 = @activeMonths12 + 1;
     IF (ISNULL(@I11,0) > 0) AND (ISNULL(@I12,0) > 0) SET @activeMonths12 = @activeMonths12 + 1;
     IF (ISNULL(@I12,0) > 0) AND (ISNULL(@I13,0) > 0) SET @activeMonths12 = @activeMonths12 + 1;
     SET @activeMonths24 = @activeMonths12
     --
     IF (ISNULL(@I13,0) > 0) AND (ISNULL(@I14,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I14,0) > 0) AND (ISNULL(@I15,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I15,0) > 0) AND (ISNULL(@I16,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I16,0) > 0) AND (ISNULL(@I17,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I17,0) > 0) AND (ISNULL(@I18,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I18,0) > 0) AND (ISNULL(@I19,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I19,0) > 0) AND (ISNULL(@I20,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I20,0) > 0) AND (ISNULL(@I21,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I21,0) > 0) AND (ISNULL(@I22,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I22,0) > 0) AND (ISNULL(@I23,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I23,0) > 0) AND (ISNULL(@I24,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     IF (ISNULL(@I24,0) > 0) AND (ISNULL(@I25,0) > 0) SET @activeMonths24 = @activeMonths24 + 1;
     --
     IF @InventoryWindow = 3 SET @returnVal = @activeMonths3
     IF @InventoryWindow = 6 SET @returnVal = @activeMonths6
     IF @InventoryWindow = 12 SET @returnVal = @activeMonths12
     IF @InventoryWindow = 24 SET @returnVal = @activeMonths24;
     --
     /*
      * We use the number of active months to calculate sales.  We can still have sales in a month
      * where we run out, and this will lead to a divide by zero error.  So its a kludge but we return -1
      */
     IF @returnVal = 0 SET @returnVal = NULL;
     RETURN @returnVal;
 END 
 
 SELECT dbo.sgNumActiveMonths(12,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25) AS foo;
EXEC sp_helptext 'sgNumActiveMonths';   


SELECT Grupi,Kod1,Ime1,Kod2 FROM Klas_SMC K WHERE K.Kod1 LIKE 'I%' AND K.Aktivno = 1;
