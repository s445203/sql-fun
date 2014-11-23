/*
 * OPISANIE:  Slozhi stoinost na @initialOrderBuffer i pusni.
 *
 *  Skripta smiata poruchkata koiato triabva da se napravi na vseki dostavchik.
 *  Skripta poruchva za (vremeto na dostavka ot dostavchika v dolnata tablica) * (1 + @initialOrderBuffer)
 *
 *  Primer:  Ako sroka e 2 meseca i @initialOrderBuffer = 0.5, skripta shte smetne dostavka dostatuchna za
 *           3 meseca prodazbi 2*(1+0.5)
 */
DECLARE @initialOrderBuffer Real;
SET @initialOrderBuffer = 0.5;
DECLARE @bLog BIT,@versionNum INT, @startTime DATETIME;
SET @versionNum = 18;
SET @bLog = 1;
SET @startTime = GetDate();
/*========================================================*/
/*
 * Kakvo vrushta:
 *  Grupa:  
 *   	Nomer na grupata
 *
 *  Dostavchik:	
 *		Ime na dostavchika
 *		
 *  Sredno Kachestvo na SMC s Nuzhda za poruchvane:  
 *		Za tozi dostavchik, kachestvoto na vsichki SMCta koito 
 *      skripta bi poruchal.  Poruchki s 999999 se smiatat kato 0 za tova.
 *
 *  Stoinost na cialata poruchka:  
 *      Sumata na poruchkata ako se porucha vsichko.  Ponezhe poruchki s 999999 se smiatata kato 0
 *      istinskata poruchka shte e po goliama.
 *
 *  Broi SMCta: 
 *      Broi SMCta ot tozi dostavchik koito sa nuzhni za poruchka
 *
 * Dnenvna Zaguba ot Zakusnenie BGN
 *      Kolko brutna pechalba shte gubi firmata na denia predi tazi poruchka pristigne v sklada.
 *      Tova ischisliava kolko SMCta shte gi niama kogato poruchkata pristigne i subira dnevnata brutna pechalba
 *      koito tezi SMCta niama.  Za brutna pechalba izpolzva marg 23.7%.  Kolkoto poveche SMCta she sa se svurshili, tolkova poveche zagubata
 *      ot dnevno zakusnenie na poruchkata.
 */
/*========================================================*/
/*
 * VERSION: 18
 *
 * Release History:
 * VERSION 18: 13.11.2014 Added logging.
 * VERSION 17: 9.11.2014 Updates for negative leadtimes, and zeroing of hole costs for things which are not ordered.
 * VERSION 16: 8.11.2014 Added calculation of actual inventory hole cost 
 * VERSION 15: 3.10.2014  Added breakdown by obekt to quality table.  Runtime 2m55s
 * VERSION 14: 14.09.2014  Changed MaxFaktKol to increase gently as confidence builds from number of fakts
 * VERSION 13: 06.09.2014 Added Veliko Turnovo
 * VERSION 12: 25.08.2014 Got rid of old Varna
 * VERSION 11: 25.08.2014  Changed DailyHoleCost API to reduce errors.
 * VERSION 10: 18.8.2013.  Added Varna 2.
 * VERSION 9:  Speed-up improvements
 * VERSION 8: 13.08.2014  Added ceiling to sd effect on MaxFaktKol to 1.5*AvgKol.
 * VERSION 7: 1.08.2014  Lots of API changes.  Rewrote calcOrder.
 * VERSION 6: 30.07.2014 Aligned order calculation with the purchase report one.
 * VERSION 5: 30.07.2014 Updated DailyHoleCost to use actual ltm GP per SMC rather than single blanket figure.
 * VERSION 4: 30.07.2014 Rolled forward changes from the non-working version and it now all seems to work on ALMA.
 * VERSION 3: 25.07.2014 Updated for Komplekt API to calcOrder and changed so negative Order quantities are also returned
 *                       Also fixed podelenie1 <> 4
 * VERSION 2: 25.07.2014 Updated the Gross Profit Calculation to use the proper ledger entry
 * VERSION 1: 23.07.2014 Initial release.  Compute the quality scores and update the table.  
 */
/*
 * Order of work:
 * 1. Compute the required order amount for each SMC, taking into account past 24 months stock, sales and supplier lead time
 *    This is done by the algotirhm described in the PurchaseReport script.
 *
 * 2. Compute the quality score for each SMC by ranking gross profit and sold quantity last 12 months.
 * 3. Produce the report by grouping SMCs needing purchasing into a single report line.
 *
 * Note that suppliers not added to the table below will have a negative leadtime which will mean they are never ordered from
 * and wont appear in the order list
 */ 
DECLARE @SMCKod VARCHAR(20);
SET @SMCKod = '%';
IF NOT OBJECT_ID('tempdb..#sgSalesHistory')     IS NULL DROP TABLE #sgSalesHistory;
IF NOT OBJECT_ID('tempdb..#sgAllSalda')         IS NULL DROP TABLE #sgAllSalda;
IF NOT OBJECT_ID('tempdb..#sgInventoryHistory') IS NULL DROP TABLE #sgInventoryHistory;
IF NOT OBJECT_ID('tempdb..#sgCurrentStock')     IS NULL DROP TABLE #sgCurrentStock;
IF NOT OBJECT_ID('tempdb..#sgMonthDelta')       IS NULL DROP TABLE #sgMonthDelta;
IF NOT OBJECT_ID('tempdb..#sgOrdersReport')       IS NULL DROP TABLE #sgOrdersReport;
CREATE TABLE #sgSalesHistory
(
	SMCKod INT NULL,
	Kol Real NULL,
	Month INT NULL,
);
CREATE TABLE #sgAllSalda
(
	Month INT NULL,
	SMCKod INT NULL,
	QTY Real NULL,
	Period INT NULL,
	Year INT NULL,
);
CREATE TABLE #sgCurrentStock
(	Stock REAL NULL,
	SMCKod INT NULL,
	Month INT NULL
);
CREATE TABLE #sgInventoryHistory
(
	Stock REAL NULL,
	SMCKod INT NULL,
	Month INT NULL
);
CREATE TABLE #sgMonthDelta
(
    Delta REAL NULL,
	SMCKod INT NULL,
	Month INT NULL
);
CREATE CLUSTERED INDEX sgIdxIH ON #sgInventoryHistory(SMCKod);
CREATE INDEX sgIdxIHMonth ON #sgInventoryHistory(Month);
CREATE CLUSTERED INDEX sgIdxSH ON #sgSalesHistory(SMCKod);
CREATE INDEX sgIdxSHMonth ON #sgSalesHistory(Month);
DECLARE @startMonth TINYINT;
DECLARE @currMonth TINYINT;
DECLARE @today DateTime;
DECLARE @currMonthStart DateTime;
DECLARE @today3m DateTime;
DECLARE @today6m DateTime;
/*
 * Jan2006 is month 1 in our scheme
 */
SET @startMonth = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE());
SET @currMonth = @startMonth;
/* 
 * Initiliase Current Sales as Current Month + 1
 */
SET @today = GETDATE();
SET @today3m = DATEADD(month, -3, @today);
SET @today6m = DATEADD(month, -6, @today);
--
SET @currMonthStart = DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0);
/*
 * 2. Copy all of the Fakt table data into #sgSalesHistory.  This is how we
 *     collect everything accross years.  #sgSalesHistory contains the purchased quantity of each
 *     SMC in our date scheme, where Jan2005 is month 1.
 */
WHILE @currMonth > @startMonth - 26
BEGIN
     /*
     * Add the delta from the current month
     */
    IF YEAR(@currMonthStart) = 2014
    BEGIN
        INSERT INTO #sgSalesHistory
	    SELECT FN.VidSMC AS SMCKod,SUM(FN.Kol) AS Kol,@currMonth AS Month
        FROM T2014.dbo.Fakt F
        INNER JOIN T2014.dbo.FaktN FN ON F.ID = FN.FaktId AND F.Data >= @currMonthStart AND F.Data < DATEADD(month,1,@currMonthStart)
		INNER JOIN T2014.dbo.Klas_SMC K ON K.Id = FN.VidSMC
		WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
		GROUP BY FN.VidSMC 
    END
    IF YEAR(@currMonthStart) = 2013
    BEGIN
        INSERT INTO #sgSalesHistory
        SELECT FN.VidSMC AS SMCKod,SUM(FN.Kol) AS Kol,@currMonth AS Month
        FROM T2013.dbo.Fakt F
        INNER JOIN T2013.dbo.FaktN FN ON F.ID = FN.FaktId AND F.Data >= @currMonthStart AND F.Data < DATEADD(month,1,@currMonthStart)
		INNER JOIN T2014.dbo.Klas_SMC K ON K.Id = FN.VidSMC
		WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
		GROUP BY FN.VidSMC
    END
    IF YEAR(@currMonthStart) = 2012
    BEGIN
        INSERT INTO #sgSalesHistory
        SELECT FN.VidSMC AS SMCKod,SUM(FN.Kol) AS Kol,@currMonth AS Month
        FROM T2012.dbo.Fakt F
        INNER JOIN T2012.dbo.FaktN FN ON F.ID = FN.FaktId AND F.Data >= @currMonthStart AND F.Data < DATEADD(month,1,@currMonthStart)
		INNER JOIN T2014.dbo.Klas_SMC K ON K.Id = FN.VidSMC
		WHERE F.Podelenie1 <> 21 AND F.Podelenie1 <> 4
		GROUP BY FN.VidSMC
    END
    /*
     * Decrement the two loop counters for next month
     */
    SET @currMonth = @currMonth - 1;
    SET @currMonthStart = DATEADD(month,-1,@currMonthStart)
END;
/*
 * 3. Now compute all of the stock data.
 */
SET @currMonth = @startMonth;
/* 
 *   3a.  #sgAllSalda is a big union of all the Salda tables for the group we are making a report
 *       this is how we span across multiple years.
 */
INSERT INTO #sgAllSalda
SELECT *
FROM
(SELECT 12*(2013-2005)+SD.Period AS Month,SD.Iv AS SMCKod,SD.QTY AS QTY,SD.Period AS Period,2014 AS Year 
FROM T2014.dbo.[ViewN Salda] SD
INNER JOIN T2014.dbo.[Klas_SMC] K ON SD.Iv = K.ID 
INNER JOIN T2014.dbo.[MOL_Nashi] M ON M.ID = SD.Store
WHERE SD.Acc = 98 
AND SD.Store IN (
	SELECT  Id = 8 --Sofia
    UNION
    SELECT  Id = 279  --Varna 2
    UNION
    SELECT  Id = 278  --Veliko Turnovo
    UNION
    SELECT  Id = 245  --Ruse
    UNION
    SELECT  Id = 239 --Byala
    UNION
	SELECT  Id = 240  --Obrabotka
    UNION
    SELECT  Id = 242  --Mezhdinen
    UNION
	SELECT  Id 
	FROM    T2014.dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
)
AND SD.Period <>0) AS S2014
UNION ALL
SELECT * FROM
(SELECT 12*(2012-2005)+SD.Period AS Month,SD.Iv AS SMCKod,SD.QTY AS QTY,SD.Period AS Period,2013 AS Year 
FROM T2013.dbo.[ViewN Salda] SD
INNER JOIN T2013.dbo.[Klas_SMC] K ON SD.Iv = K.ID 
INNER JOIN T2013.dbo.[MOL_Nashi] M ON M.ID = SD.Store
WHERE SD.Acc = 98 
AND SD.Store IN (
	SELECT  Id = 8 --Sofia
    UNION
    SELECT  Id = 279  --Varna 2
    UNION
    SELECT  Id = 278  --Veliko Turnovo
    UNION
    SELECT  Id = 245  --Ruse
    UNION
    SELECT  Id = 239 --Byala
    UNION
	SELECT  Id = 240  --Obrabotka
    UNION
    SELECT  Id = 242  --Mezhdinen
    UNION
	SELECT  Id 
	FROM    T2013.dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
)
AND SD.Period <>0) AS S2013 --Bring forward balance from 2012
UNION ALL
SELECT * FROM (
SELECT 12*(2011-2005)+SD.Period AS Month,SD.Iv AS SMCKod,SD.QTY AS QTY,SD.Period AS Period,2012 AS Year 
FROM T2012.dbo.[ViewN Salda] SD
INNER JOIN T2012.dbo.[Klas_SMC] K ON SD.Iv = K.ID 
INNER JOIN T2012.dbo.[MOL_Nashi] M ON M.ID = SD.Store
WHERE SD.Acc = 98 
AND SD.Store IN (
	SELECT  Id = 8 --Sofia
    UNION
    SELECT  Id = 279  --Varna 2
    UNION
    SELECT  Id = 278  --Veliko Turnovo
    UNION
    SELECT  Id = 245  --Ruse
    UNION
    SELECT  Id = 239 --Byala
    UNION
	SELECT  Id = 240  --Obrabotka
    UNION
    SELECT  Id = 242  --Mezhdinen
    UNION
	SELECT  Id 
	FROM    T2012.dbo.MOL_Nashi 
	WHERE   ID_Podchinenie = 8
)) AS S2012; --The last year we take in must include the sum of all priors which is in period 0 carryover
/* 
 *   3b.  #sgCurrentStock is really the sum of all the salda data.  
 */
INSERT INTO #sgCurrentStock
SELECT SUM(SD.QTY) AS Stock,SD.SMCKod AS SMCKod,@startMonth+1 AS Month
FROM #sgAllSalda SD 
GROUP BY SD.SMCKod;
/* 
 *   3c.  We build the inventory history month by month.  The first month
 *        is current stock right now and this is the first to go on
 */
INSERT INTO #sgInventoryHistory
SELECT CS.Stock AS Stock,CS.SMCKod AS SMCKod,CS.Month AS Month
FROM #sgCurrentStock CS;
/* 
 *   3d.  Then we compute the delta for the next month. The delta is how much the stock changed by
 */
INSERT INTO #sgMonthDelta
SELECT SUM(SD.QTY) AS Delta,SD.SMCKod AS SMCKod,@startMonth AS Month
FROM #sgAllSalda SD 
WHERE SD.Month > @currMonth-1 AND SD.Month <= @startMonth
GROUP BY SD.SMCKod;
/* 
 *   3e.  We loop for each month, going back further in further in time.  Each loop
 *        is rolling back from today to the month in question.
 */
SET @currMonth = @startMonth;
WHILE @currMonth > @startMonth - 26
BEGIN
    /*
     * Add the delta from the current month
     */
    INSERT INTO #sgInventoryHistory
    SELECT ISNULL(CS.Stock,0) - ISNULL(Delta.Delta,0) AS Stock,COALESCE(CS.SMCKod,Delta.SMCKod) AS SMCKod,
    Month = @currMonth
    FROM #sgCurrentStock CS
    FULL OUTER JOIN #sgMonthDelta Delta ON CS.SMCKod = Delta.SMCKod;
     /*
      * Decrement for next month
      */
    SET @currMonth = @currMonth - 1;
    /*
     * Truncate and compute new month delta
     */
    TRUNCATE TABLE #sgMonthDelta;
    INSERT INTO #sgMonthDelta
    SELECT SUM(SD.QTY) AS Delta,SD.SMCKod AS SMCKod,@currMonth-1 AS Month
    FROM #sgAllSalda SD 
    WHERE SD.Month > @currMonth-1 AND SD.Month <= @startMonth
    GROUP BY SD.SMCKod;
END;
IF NOT OBJECT_ID('tempdb..#sgQualityStep0')       IS NULL DROP TABLE #sgQualityStep0;
IF NOT OBJECT_ID('tempdb..#sgQualityStep1')       IS NULL DROP TABLE #sgQualityStep1;
IF NOT OBJECT_ID('tempdb..#sgQualityRankedGp')       IS NULL DROP TABLE #sgQualityRankedGp;
IF NOT OBJECT_ID('tempdb..#sgQualityRankedKol')       IS NULL DROP TABLE #sgQualityRankedKol;
IF NOT OBJECT_ID('tempdb..#sgQualityScores')       IS NULL DROP TABLE #sgQualityScores;
CREATE TABLE #sgQualityStep0
(
	SMCId INT NULL,
	Revenue Real NULL,
	GP Real NULL,
	Kol Real NULL,
	COGS Real NULL,
	StDevKol Real NULL,
	AvgKol Real NULL,
	TransCount Real NULL,
	SofiaKol Real NULL,
	VarnaKol Real NULL,
	ByalaKol Real NULL,
	RuseKol  Real NULL,
	VTKol Real NULL
);
CREATE TABLE #sgQualityScores
(
	SMCId INT NULL,
	COGS Real NULL,
	Revenue Real NULL,
	GP Real NULL,
	Kol Real NULL,
	GPRank Int NULL,
	KolRank Int NULL,
	Quality Real NULL,
	MaxFaktKol Real NULL,
	SofiaKol Real NULL,
	VarnaKol Real NULL,
	ByalaKol Real NULL,
	RuseKol  Real NULL,
	VTKol Real NULL
);
CREATE CLUSTERED INDEX sgIxQualityScoresTemp ON #sgQualityScores(SMCId);
/*
 *  Before we compute how much we need of each thing, we need to know its quality.
 *
 * Faktura revenue includes DDS whereas accounting price does not so we reduce by 20%
 * We need to also calculate how much is the average faktura.  We do this in two parts and weigh
 * the average across this year and last, giving the most weight to the year which has the most months.
 *
 * But here also calculate breakdown by obekt.  This requires two different grouping levels, which is the monstrosity
 * below.  
 * In part 1, we compute all the sums (3 layers of select)
 */
INSERT INTO #sgQualityStep0
SELECT LTM.SMCId AS SMCId,SUM(LTM.Revenue) AS Revenue, SUM(LTM.GP) AS GP, SUM(LTM.Kol) AS Kol, SUM(LTM.COGS) AS COGS,SUM(LTM.StdevKol) AS StDevKol,SUM(LTM.AvgKol) AS AvgKol,SUM(LTM.TransCount) AS TransCount,
       SUM(LTM.SofiaKol) AS SofiaKol,SUM(LTM.VarnaKol) AS VarnaKol, SUM(LTM.ByalaKol) AS ByalaKol, SUM(LTM.RuseKol) AS RuseKol, SUM(LTM.VTKol) AS VTKol
FROM
	(SELECT Almost.SMCID AS SMCId, SUM(Almost.Revenue) AS Revenue,
       SUM(Almost.GP) AS GP, SUM(Almost.Kol) AS Kol,SUM(Almost.COGS) AS COGS, 
       0 AS StDevKol, 0 AS AvgKol, SUM(Almost.TransCount) AS TransCount,
       SUM(Almost.SofiaKol) AS SofiaKol,SUM(Almost.VarnaKol) AS VarnaKol, SUM(Almost.ByalaKol) AS ByalaKol, SUM(Almost.RuseKol) AS RuseKol, SUM(Almost.VTKol) AS VTKol
	FROM
	(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP,
        ISNULL(STDEV(DtKt.Kol)*MONTH(GETDATE())/12,0) AS StdevKol, AVG(DtKt.Kol)*MONTH(GETDATE())/12 AS AvgKol,COUNT(*) AS TransCount,
        CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN SUM(DtKt.Kol) END AS SofiaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 278 THEN SUM(DtKt.Kol) END AS VTKol,
        CASE WHEN DtKt.Kt_MOLNashID = 239 THEN SUM(DtKt.Kol) END AS ByalaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 245 THEN SUM(DtKt.Kol) END AS RuseKol,
        CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN SUM(DtKt.Kol) END AS VarnaKol
	FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2014.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data < GETDATE()
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost
	GROUP BY Almost.SMCID,Almost.Ime1
UNION ALL
	SELECT Almost1.SMCID AS SMCId, SUM(Almost1.Revenue) AS Revenue,
       SUM(Almost1.GP) AS GP, SUM(Almost1.Kol) AS Kol,SUM(Almost1.COGS) AS COGS, 
       0 AS StDevKol, 0 AS AvgKol, SUM(Almost1.TransCount) AS TransCount,
       SUM(Almost1.SofiaKol) AS SofiaKol,SUM(Almost1.VarnaKol) AS VarnaKol, SUM(Almost1.ByalaKol) AS ByalaKol, SUM(Almost1.RuseKol) AS RuseKol, SUM(Almost1.VTKol) AS VTKol
	FROM
	(SELECT K.ID AS SMCId,K.Ime1,SUM(DtKt.Kol) AS Kol, 
        SUM(DtKt.ProdSt_K) AS Revenue, SUM(DtKt.Suma) AS COGS, SUM(DtKt.ProdSt_K) - SUM(DtKt.Suma) AS GP,COUNT(*) AS TransCount,
        CASE WHEN DtKt.Kt_MOLNashID = 8 OR MOL.ID_Podchinenie = 8 THEN SUM(DtKt.Kol) END AS SofiaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 278 THEN SUM(DtKt.Kol) END AS VTKol,
        CASE WHEN DtKt.Kt_MOLNashID = 239 THEN SUM(DtKt.Kol) END AS ByalaKol,
        CASE WHEN DtKt.Kt_MOLNashID = 245 THEN SUM(DtKt.Kol) END AS RuseKol,
        CASE WHEN (DtKt.Kt_MOLNashID = 279 OR DtKt.Kt_MOLNashID = 215) THEN SUM(DtKt.Kol) END AS VarnaKol
	FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
	INNER JOIN T2013.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID	
	INNER JOIN T2013.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
	INNER JOIN T2013.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
	INNER JOIN T2013.dbo.MOL_Nashi MOL ON MOL.ID = DtKt.Kt_MOLNashID
	WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   		AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= DATEADD(year,-1,GETDATE()) AND DtKt.Data < '20140101'
   		AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21 --AND DtKt.Kt_MOLNashID = 278 --AND K.ID = 2681496
	GROUP BY K.ID,K.Ime1,DtKt.Kt_MOLNashID,MOL.ID_Podchinenie
	) Almost1
	GROUP BY Almost1.SMCID) LTM
GROUP BY LTM.SMCId;
/*
 * In part 2 we compute the StDevKol and AvgKol	for factura - we cannot do this above
 * because it requires a grouping by SMC rather than by obekt
 */
SELECT LTM.SMCId AS SMCId,SUM(LTM.StdevKol) AS StDevKol,SUM(LTM.AvgKol) AS AvgKol
INTO #sgQualityStep1
FROM
(SELECT K.ID AS SMCId,
        ISNULL(STDEV(DtKt.Kol)*MONTH(GETDATE())/12,0) AS StdevKol, AVG(DtKt.Kol)*MONTH(GETDATE())/12 AS AvgKol
FROM T2014.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
INNER JOIN T2014.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID
INNER JOIN T2014.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
INNER JOIN T2014.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= '20140101' AND DtKt.Data < GETDATE()
   AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
GROUP BY K.ID,K.Ime1
UNION ALL
SELECT K.ID AS SMCId,
        ISNULL(STDEV(DtKt.Kol)*(12-MONTH(GETDATE()))/12,0) AS StdevKol, AVG(DtKt.Kol)*(12-MONTH(GETDATE()))/12 AS AvgKol
FROM T2013.dbo.[View ReportGenerator Dvig SourceDtKt] DtKt
INNER JOIN T2013.dbo.Klas_SMC K ON DtKt.Dt_SMCId = K.ID
INNER JOIN T2013.dbo.SmetkoPlan KtSP ON KtSP.ID = DtKt.Kt_SP_SmetkaId
INNER JOIN T2013.dbo.SmetkoPlan DtSp ON DtSP.ID = DtKt.Dt_SP_SmetkaId
WHERE  ((DtSP.Smetka >= 700 AND DtSP.Smetka < 710) OR (DtSP.Smetka >= 7000 AND DtSP.Smetka < 7100)) AND K.Kod1 NOT LIKE '99000000%'
   AND ((KtSP.Smetka >= 300 AND KtSP.Smetka < 310) OR (KtSP.Smetka >= 3000 AND KtSP.Smetka < 3100)) AND DtKt.Data >= DATEADD(year,-1,GETDATE()) AND DtKt.Data < '20140101'
   AND DtKt.Podelenie1 <> 4 AND DtKt.Podelenie1 <> 21
GROUP BY K.ID,K.Ime1) LTM
GROUP BY LTM.SMCId
ORDER BY LTM.SMCId DESC;
/*
 * Now we copy back to the main table
 */	
UPDATE #sgQualityStep0 
SET AvgKol = q1.AvgKol, StDevKol = q1.StDevKol
FROM #sgQualityStep0 q0
LEFT JOIN #sgQualityStep1 q1 ON q0.SMCId = q1.SMCId
/*
 * The things which have been returned can have net sales of zero.
 * This causes problems later on, so we set them to NULL
 */
UPDATE #sgQualityStep0 
SET Kol = NULL
WHERE Kol = 0 OR Kol < 0;
UPDATE #sgQualityStep0 
SET SofiaKol = NULL
WHERE SofiaKol < 0;
UPDATE #sgQualityStep0 
SET VarnaKol = NULL
WHERE VarnaKol < 0;
UPDATE #sgQualityStep0 
SET RuseKol = NULL
WHERE RuseKol < 0;
UPDATE #sgQualityStep0 
SET ByalaKol = NULL
WHERE ByalaKol < 0;
UPDATE #sgQualityStep0 
SET VTKol = NULL
WHERE VTKol < 0;
/*
 * Create two tables one with GP rank and one with Kol rank
 */
SELECT QS0.*,IDENTITY(int, 1,1) AS GPRank INTO #sgQualityRankedGp FROM #sgQualityStep0 QS0 ORDER BY QS0.GP DESC;
SELECT QS0.*,IDENTITY(int, 1,1) AS KolRank INTO #sgQualityRankedKol FROM #sgQualityStep0 QS0 ORDER BY QS0.Kol DESC;
/*
 * Combine all three tables into the QualityScore table
 * We do not allow MaxFaktKol to go more than 1.3x AvgKol because there are some large returns orders
 * which impact the variance and can give a false signal which ends up over ordering
 * We also filter for when less than 5 faktura - actually a bit less as returns count as 1 faktura
 * and we turn down the SD signal.
 */
INSERT INTO #sgQualityScores
SELECT QS0.SMCId AS SMCId, QS0.COGS AS COGS, QS0.Revenue AS Revenue, 
       QS0.GP AS GP, QS0.Kol AS Kol,GPRANK.GpRank AS GPRank, KOLRANK.KolRank AS KolRank, 0 AS Quality, 
       MaxFaktKol = CASE
						WHEN QS0.TransCount < 5 THEN 1
						WHEN QS0.TransCount > 5 THEN ROUND(dbo.sgMin(QS0.AvgKol + 0.5*QS0.StdevKol,QS0.AvgKol*1.3,999999),0)
					END,
	   QS0.SofiaKol AS SofiaKol,
	   QS0.VarnaKol AS VarnaKol,
	   QS0.ByalaKol AS ByalaKol,
	   QS0.RuseKol AS RuseKol,
	   QS0.VTKol AS VTKol
FROM #sgQualityStep0 QS0
INNER JOIN #sgQualityRankedGp GPRANK ON GPRANK.SMCId = QS0.SMCId
INNER JOIN #sgQualityRankedKol KOLRANK ON KOLRANK.SMCId = QS0.SMCId
ORDER BY GpRank;
/*
 * Finally compute the quality
 */
UPDATE #sgQualityScores
SET Quality = sqrt(square(KolRank) + square(GpRank));
/*
 * Clean Up all of the big tables we dont need
 */
DROP TABLE #sgQualityRankedGp;
DROP TABLE #sgQualityRankedKol;
DROP TABLE #sgQualityStep0;
DROP TABLE #sgQualityStep1;
/*
 * Clear the old quality scores data and insert the latest
 * We keep our data in 2012 to avoid prying eyes from Alma.
 * This code is really flaky for some reason.  Use the snipper
 * from Scrap Repository to delete the table and rebuild it
 * if columns are added to sgQualityScores
 */
IF OBJECT_ID('T2012.dbo.sgQualityScores') IS NOT NULL 
	BEGIN
		TRUNCATE TABLE T2012.dbo.sgQualityScores;
		INSERT INTO T2012.dbo.sgQualityScores
		SELECT * FROM #sgQualityScores;
	END
ELSE
	SELECT * INTO T2012.dbo.sgQualityScores FROM #sgQualityScores;
/* 
 *   Now compute how much of each SMC we need to order.
 */
CREATE TABLE #sgOrdersReport
(
    SMCId INT NULL,
	OrderQ Real NULL,
	ChistaZaiavka Real NULL,
	OrderQs9 Real NULL,
	Stock Real NULL,
	DnevnaZagubaOtZakusnenieBGN Real NULL,
	DnevnaZagubaOtDupkaBGN Real NULL
);
INSERT INTO #sgOrdersReport
SELECT Active.SMCRaw AS SMCId,
 		OrderQ = dbo.sgCalcOrder(1,1,@initialOrderBuffer,ISNULL(ObrabotkaM.ObrabotkaMin,0),Q.Quality,
											ISNULL(Active.LeadTimeInMonths,1),ISNULL(M0.Kol,0),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              	  						+ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)),
											dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											ISNULL(I0.Stock,0),
	                						ISNULL(SofiaM.SofiaMax,0),Q.SofiaPC,DAY(GETDATE()),ISNULL(Q.MaxFaktKol,0)),
	   	ChistaZaiavka = dbo.sgCalcOrder(0,0,@initialOrderBuffer,ISNULL(ObrabotkaM.ObrabotkaMin,0),Q.Quality,
											ISNULL(Active.LeadTimeInMonths,1),ISNULL(M0.Kol,0),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              	  						+ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)),
											dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											ISNULL(I0.Stock,0),
	                						ISNULL(SofiaM.SofiaMax,0),Q.SofiaPC,DAY(GETDATE()),ISNULL(Q.MaxFaktKol,0)),
	   	 OrderQs9 = dbo.sgCalcOrder(0,1,@initialOrderBuffer,ISNULL(ObrabotkaM.ObrabotkaMin,0),Q.Quality,
											ISNULL(Active.LeadTimeInMonths,1),ISNULL(M0.Kol,0),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)),
											(ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0)+ISNULL(M4.Kol,0)+ISNULL(M5.Kol,0)+ISNULL(M6.Kol,0)+ISNULL(M7.Kol,0)+ISNULL(M8.Kol,0)+ISNULL(M9.Kol,0)+ISNULL(M10.Kol,0)+ISNULL(M11.Kol,0)+ISNULL(M12.Kol,0)
	              	  						+ISNULL(M13.Kol,0)+ISNULL(M14.Kol,0)+ISNULL(M15.Kol,0)+ISNULL(M16.Kol,0)+ISNULL(M17.Kol,0)+ISNULL(M18.Kol,0)+ISNULL(M19.Kol,0)+ISNULL(M20.Kol,0)+ISNULL(M21.Kol,0)+ISNULL(M22.Kol,0)+ISNULL(M23.Kol,0)),
											dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(6,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(12,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											dbo.sgNumActiveMonths(24,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
											ISNULL(I0.Stock,0),
	                						ISNULL(SofiaM.SofiaMax,0),Q.SofiaPC,DAY(GETDATE()),ISNULL(Q.MaxFaktKol,0)),
	  ISNULL(I0.Stock,0) AS Stock,
	  DnevnaZagubaOtZakusnenieBGN = dbo.sgDailyOrderDelayCost((ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0))/dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
													ISNULL(Q.MaxFaktKol,0),Active.LeadTimeInMonths,ISNULL(I0.Stock,0),ISNULL(Q.ltmRevenue,0),ISNULL(Q.ltmGP,0),ISNULL(Q.ltmKol,0),ISNULL(Q.ltmCOGS,0),Active.PurchasePriceBGN),
	  DnevnaZagubaOtDupkaBGN = dbo.sgDailyHoleCost((ISNULL(M1.Kol,0)+ISNULL(M2.Kol,0)+ISNULL(M3.Kol,0))/dbo.sgNumActiveMonths(3,I1.Stock,I2.Stock,I3.Stock,I4.Stock,I5.Stock,I6.Stock,I7.Stock,I8.Stock,I9.Stock,I10.Stock,I11.Stock,I12.Stock,I13.Stock,I14.Stock,I15.Stock,I16.Stock,I17.Stock,I18.Stock,I19.Stock,I20.Stock,I21.Stock,I22.Stock,I23.Stock,I24.Stock,I25.Stock),
												ISNULL(Q.MaxFaktKol,0),ISNULL(I0.Stock,0),ISNULL(Q.ltmRevenue,0),ISNULL(Q.ltmGP,0),ISNULL(Q.ltmKol,0),ISNULL(Q.ltmCOGS,0),Active.PurchasePriceBGN)
FROM
(SELECT K.Kod1 AS GroupSMCKod, K.Ime1 AS GroupSMCIme, K.ID AS SMCRaw,K.CenaO1 AS PurchasePriceBGN,ISNULL(LT.LeadTime,1) AS LeadTimeInMonths
    FROM T2014.dbo.[Klas_SMC] K
    LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
    WHERE K.Aktivno = 1) Active
LEFT JOIN
(SELECT QS.SMCId AS SMCId,ROUND(QS.Quality,0) AS Quality, QS.Revenue AS ltmRevenue, QS.GP AS ltmGP, QS.Kol AS ltmKol, QS.COGS AS ltmCOGS,QS.MaxFaktKol AS MaxFaktKol,  
	ISNULL(QS.SofiaKol,0) / ISNULL(QS.Kol,1) AS SofiaPC
	FROM T2012.dbo.sgQualityScores QS) Q ON Q.SMCId = Active.SMCRaw
LEFT JOIN
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+0) M0 ON M0.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-1) M1 ON M1.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-2) M2 ON M2.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-3) M3 ON M3.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-4) M4 ON M4.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-5) M5 ON M5.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-6) M6 ON M6.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-7) M7 ON M7.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-8) M8 ON M8.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-9) M9 ON M9.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-10) M10 ON M10.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-11) M11 ON M11.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-12) M12 ON M12.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-13) M13 ON M13.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-14) M14 ON M14.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-15) M15 ON M15.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-16) M16 ON M16.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-17) M17 ON M17.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-18) M18 ON M18.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-19) M19 ON M19.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-20) M20 ON M20.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-21) M21 ON M21.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-22) M22 ON M22.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-23) M23 ON M23.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-24) M24 ON M24.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod AS SMCKod, IH.Kol AS Kol
FROM #sgSalesHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-25) M25 ON M25.SMCKod = Active.SMCRaw
LEFT JOIN
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+1) Latest ON Latest.SMCKod = Active.SMCRaw
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+1) I0 ON Active.SMCRaw = I0.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())+0) I1 ON Active.SMCRaw = I1.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-1) I2 ON Active.SMCRaw = I2.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-2) I3 ON Active.SMCRaw = I3.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-3) I4 ON Active.SMCRaw = I4.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-4) I5 ON Active.SMCRaw = I5.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-5) I6 ON Active.SMCRaw = I6.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-6) I7 ON Active.SMCRaw = I7.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-7) I8 ON Active.SMCRaw = I8.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-8) I9 ON Active.SMCRaw = I9.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-9) I10 ON Active.SMCRaw = I10.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-10) I11 ON Active.SMCRaw = I11.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-11) I12 ON Active.SMCRaw = I12.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-12) I13 ON Active.SMCRaw = I13.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-13) I14 ON Active.SMCRaw = I14.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-14) I15 ON Active.SMCRaw = I15.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-15) I16 ON Active.SMCRaw = I16.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-16) I17 ON Active.SMCRaw = I17.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-17) I18 ON Active.SMCRaw = I18.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-18) I19 ON Active.SMCRaw = I19.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-19) I20 ON Active.SMCRaw = I20.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-20) I21 ON Active.SMCRaw = I21.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-21) I22 ON Active.SMCRaw = I22.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-22) I23 ON Active.SMCRaw = I23.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-23) I24 ON Active.SMCRaw = I24.SMCKod
LEFT JOIN 
(SELECT IH.SMCKod, IH.Stock
FROM #sgInventoryHistory IH
WHERE IH.Month = (YEAR(GETDATE())-1 - 2005)*12 + MONTH(GETDATE())-24) I25 ON Active.SMCRaw = I25.SMCKod		
LEFT JOIN
(SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS SofiaMin
 ,MaxZ AS SofiaMax
 --,99999 AS SofiaMax
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 8 AND
      K.Kod1  LIKE @SMCKod AND
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) SofiaM ON Active.SMCRaw = SofiaM.SMCKod
LEFT JOIN
(
SELECT  K.ID AS SMCKod
 ,K.Ime1 AS SMCIme
 ,M.Ime AS Mol
 ,MinZ AS ObrabotkaMin
 FROM dbo.Klas_SMC_Zapasi Z
 INNER JOIN dbo.MOL_Nashi M ON Z.MOL = M.ID
 INNER JOIN  dbo.Klas_SMC K ON Z.SMCID = K.ID
WHERE Z.Podelenie1 = 6 AND 
      Z.MOL  = 240 AND --Obrabotka
      K.Kod1  LIKE @SMCKod AND
      K.Grupi = ISNULL(NULLIF(0, 0), K.Grupi)
) ObrabotkaM ON Active.SMCRaw = ObrabotkaM.SMCKod
ORDER BY Active.GroupSMCKod;
/*
 * We only want to know about the hole cost for things the computer would order
 * So if CHISTA ZAIAVKA s 9 has zeros in it, we set the hole cost to zero
 */
UPDATE #sgOrdersReport
SET [DnevnaZagubaOtZakusnenieBGN] = CASE [ChistaZaiavka]
                     					WHEN 0 THEN 0
                     					ELSE [DnevnaZagubaOtZakusnenieBGN]
                  						END;
UPDATE #sgOrdersReport
SET [DnevnaZagubaOtDupkaBGN] = CASE [ChistaZaiavka]
                     					WHEN 0 THEN 0
                     					ELSE [DnevnaZagubaOtDupkaBGN]
                  						END;
/*
 * This bit is very flaky.  Use code in Scrap repository to recreate the table on changes
 */
IF OBJECT_ID('T2012.dbo.sgOrderNeed') IS NOT NULL 
	BEGIN
		TRUNCATE TABLE T2012.dbo.sgOrderNeed;
		INSERT INTO T2012.dbo.sgOrderNeed
		SELECT * FROM #sgOrdersReport;
	END
ELSE
    BEGIN
		SELECT * INTO T2012.dbo.sgOrderNeed FROM #sgOrdersReport;	
	END
/*
 * More clean-up
 */
IF NOT OBJECT_ID('tempdb..#sgSalesHistory')     IS NULL DROP TABLE #sgSalesHistory;
IF NOT OBJECT_ID('tempdb..#sgAllSalda')         IS NULL DROP TABLE #sgAllSalda;
IF NOT OBJECT_ID('tempdb..#sgInventoryHistory') IS NULL DROP TABLE #sgInventoryHistory;
IF NOT OBJECT_ID('tempdb..#sgCurrentStock')     IS NULL DROP TABLE #sgCurrentStock;
IF NOT OBJECT_ID('tempdb..#sgMonthDelta')       IS NULL DROP TABLE #sgMonthDelta;
IF @bLog = 1
BEGIN
	INSERT INTO T2012.dbo.sgScriptLog
	SELECT GetDate() AS Time, 'SMCQuality' AS ScriptName, @versionNum AS Version,USER_NAME() AS UserName,DATEDIFF(s,@startTime,getdate()),NULL,@initialOrderBuffer,NULL,NULL,NULL
END
/*
 * Display the prioritised orders report
 */
SELECT OrderList.Grupa,OrderList.Dostavchik,
       [Sredno Kachestvo na SMC s Nuzhda za poruchvane] = ROUND(OrderList.[Sredno Kachestvo na SMC s Nuzhda za poruchvane],0),
       [Stoinost na cialata poruchka] = ROUND(OrderList.[Stoinost na cialata poruchka],0), 
       [Broi SMCta za poruchvane] = OrderList.[Broi SMCta za poruchvane],OrderList.DnevnaZagubaOtZakusnenieBGN,
       OrderList.DnevnaZagubaOtDupkaBGN,
       ROUND(SUM(Obrabotka.Fish * Obrabotka.Cena),0) AS StoinostVObrabotka,OrderList.LeadTime
       --,MarginPC = ROUND(100*OrderList.LTMGP / OrderList.LTMRev,2)
FROM
(
SELECT G.Code AS Grupa,G.Ime AS Dostavchik,LT.LeadTime AS LeadTime, AVG(QS.Quality) AS 'Sredno Kachestvo na SMC s Nuzhda za poruchvane',
	   SUM(Orders.ChistaZaiavka * K.CenaO1) AS 'Stoinost na cialata poruchka', COUNT(*) AS 'Broi SMCta za poruchvane',
	   SUM(Orders.DnevnaZagubaOtZakusnenieBGN) AS DnevnaZagubaOtZakusnenieBGN,
	   SUM(Orders.DnevnaZagubaOtDupkaBGN) AS DnevnaZagubaOtDupkaBGN,
	   SUM(QS.Revenue) AS LTMRev, SUM(QS.GP) AS LTMGP
FROM T2012.dbo.sgQualityScores QS 
LEFT JOIN T2012.dbo.sgOrderNeed Orders ON QS.SMCId = Orders.SMCId
LEFT JOIN T2014.dbo.Klas_SMC K ON K.ID = QS.SMCID
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
LEFT JOIN T2012.dbo.sgLeadTimes LT ON LT.Grupa = K.Grupi
WHERE Orders.SMCId IS NOT NULL AND Orders.ChistaZaiavka > 0
GROUP BY G.Ime,G.Code,LT.LeadTime) OrderList
LEFT JOIN
(SELECT G.Ime AS VObrabotkaLiE,SUM(SD.QTY) AS Fish,K.CenaO1 AS Cena--,SD.Iv AS Fish1--*K.CenaO1 AS Suma
FROM dbo.[ViewN Salda] SD
INNER JOIN dbo.Klas_SMC K ON K.ID = SD.Iv AND SD.Acc = K.MatSmetka1
LEFT JOIN T2014.dbo.Grupi_SMC G ON G.Code = K.Grupi
WHERE SD.Store = 240 --Obrabotka
GROUP BY SD.Iv,G.Ime,K.CenaO1 HAVING SUM(SD.QTY)>0) Obrabotka ON Obrabotka.VObrabotkaLiE = OrderList.Dostavchik
GROUP BY OrderList.Grupa,OrderList.LeadTime,OrderList.Dostavchik,OrderList.[Sredno Kachestvo na SMC s Nuzhda za poruchvane],OrderList.[Stoinost na cialata poruchka],
         OrderList.[Broi SMCta za poruchvane],OrderList.DnevnaZagubaOtZakusnenieBGN,OrderList.LTMGP,OrderList.LTMRev,OrderList.DnevnaZagubaOtDupkaBGN
ORDER BY OrderList.[Stoinost na cialata poruchka] DESC;

